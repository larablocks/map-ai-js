#!/usr/bin/env bash
# merge.sh — MAP's git merge driver for the markdown files AI agents maintain.
#
# Registered per clone as:
#   git config merge.map-ai.driver 'bash "$(git rev-parse --show-toplevel)/.map/merge.sh" %O %A %B %P'
# and wired to files by .gitattributes ("docs/BUGS.md merge=map-ai" etc.).
# install.sh / Installer / doctor --fix register it; so does the SessionStart
# hook. git config is never committed, so every clone needs registering once —
# an unregistered clone just falls back to git's normal text merge.
#
# Driver contract: git passes base (%O), ours (%A), theirs (%B) and the path
# (%P). The result goes in %A; exit 0 = resolved, non-zero = conflict.
#
# Also: merge.sh --resolve <path> re-runs the same merge for a file git has
# already left conflicted (base/ours/theirs rebuilt from the index stages) and
# writes the result to the working tree. Used by the map-resolve skill. Never
# runs `git add`.
#
# How a file is resolved — never worse than plain git:
# 1. git's own 3-way merge. Clean → that exact result (plus BUG-N
#    de-duplication for the bug files), provided every entry (block, below)
#    that neither side changed is unchanged and every entry one side changed
#    matches that side — git matches identical lines, and MAP entries repeat
#    the same field lines, so a "clean" merge can land an edit in the wrong
#    entry. Otherwise it falls through to 2. It's also written to %A up front,
#    so any failure below still leaves git's normal conflict output behind.
# 2. Rules, no LLM. Split each side into blocks at markdown headings (not
#    inside code fences or HTML comments) and 3-way merge block by block.
#    Inside a block changed on both sides, only these hunk shapes resolve:
#      - table rows only       → 3-way merge keyed by first cell
#      - list items only       → 3-way merge keyed by item text (one-line
#                                dated entries count as items): removals on
#                                either side stay removed, additions kept
#                                (ours, then theirs), numbered lists renumbered;
#                                items both kept must keep their order
#      - nothing in the base   → both sides only inserted: ours, then theirs
#      - "Last updated" lines  → newest date
#    Snapshot blocks (marked "<!-- map-merge: snapshot -->"; above the first
#    ## heading it marks the whole file) hold values re-measured every session, so
#    whatever's still conflicting there — a hunk, or a table row both sides
#    changed — is taken from the side with the newer date (block, then file;
#    ours on a tie) and reported, instead of stopping the merge.
#    Everything the rules resolve is kept; conflict markers remain only around
#    what they couldn't. All resolved → exit 0.
# 3. Claude, for what's left. Each remaining conflict is sent to Claude with
#    base/ours/theirs, surrounding lines, the file's own header rules, and the
#    commit subjects from both branches. A resolution is accepted only if it
#    has no conflict markers, keeps every heading / table key / dated entry
#    from both sides (unless one side deleted it relative to base), and adds
#    no heading neither side had. Rejected or unresolved → markers stay.
#    Stop-for-review: even when Claude resolves everything, this exits
#    non-zero so the merge pauses before committing — review `git diff`,
#    then `git add`. Nothing an LLM wrote is committed unseen.
#    Skipped when disabled (MAP_MERGE_LLM=0, or git config map-ai.llm false)
#    or when no `claude` CLI is on PATH. Command override:
#    MAP_MERGE_LLM_COMMAND / git config map-ai.llmCommand (prompt on stdin,
#    reply on stdout). Model: MAP_MERGE_MODEL / git config map-ai.model.
#    Timeout: MAP_MERGE_LLM_TIMEOUT seconds (default 180).
# 4. docs/BUGS.md and docs/BUGS_ARCHIVE.md: a BUG-N heading that now appears
#    twice (both branches picked the same next number) keeps its number on
#    the entry that was already on our side; the other gets the next free
#    number across both bug files on both branches. Same for a new BUG-N of
#    theirs that our side already used in the other bug file. A number that
#    already existed at the merge base is one bug both branches handled — not
#    renumbered; the merge stops for review instead.
#
# Also: merge.sh --check-bugs lists BUG-N headings used twice across
# docs/BUGS.md and docs/BUGS_ARCHIVE.md (exit 1 if any) — git only runs a
# merge driver on a file both sides changed, so a clash between one branch's
# BUGS.md and the other's BUGS_ARCHIVE.md never reaches the driver; the
# SessionStart hook and doctor run this after the fact. merge.sh --fix-bugs
# renumbers the later copy (BUGS.md before the archive, which is never
# edited) to the next free number.
#
# Written for bash 3.2 + POSIX awk — git runs this on every merge, including
# on stock macOS.

MARKER_SIZE=7

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t map-merge)"
trap 'rm -rf "$TMP"' EXIT

if [[ "${1:-}" == "--check-bugs" || "${1:-}" == "--fix-bugs" ]]; then
  cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2
  FIX=0; [[ "$1" == "--fix-bugs" ]] && FIX=1
  files=()
  for f in docs/BUGS_ARCHIVE.md docs/BUGS.md; do [[ -f "$f" ]] && files+=("$f"); done
  (( ${#files[@]} )) || exit 0
  # Archive first: its entries are permanent, so the copy in BUGS.md (or the
  # later one within a file) is the one that moves.
  awk -v fix="$FIX" -v tmp="$TMP" '
    function in_code(line) {
      if (line ~ /^[[:space:]]*(```|~~~)/) { fence = !fence; return 1 }
      if (fence) return 1
      if (comment) { if (line ~ /-->/) comment = 0; return 1 }
      if (line ~ /<!--/ && line !~ /-->/) { comment = 1; return 1 }
      return 0
    }
    FNR == 1 { fence = 0; comment = 0; file[++nf] = FILENAME }
    {
      lines[FILENAME, FNR] = $0; count[FILENAME] = FNR
      n = split($0, parts, /BUG-/)
      for (i = 2; i <= n; i++) if (match(parts[i], /^[0-9]+/)) { v = substr(parts[i], 1, RLENGTH) + 0; if (v > max) max = v }
      if (!in_code($0) && match($0, /^#+[[:space:]]+BUG-[0-9]+/)) {
        b = substr($0, 1, RLENGTH); sub(/^#+[[:space:]]+BUG-/, "", b); b += 0
        if (b in first) {
          dup = 1
          printf "map-merge: BUG-%d is used twice — %s and %s: \"%s\"\n", b, first[b], FILENAME, $0
          if (fix) {
            max++; line = $0; sub("BUG-" b, "BUG-" max, line); lines[FILENAME, FNR] = line; changed[FILENAME] = 1
            printf "map-merge: renumbered it to BUG-%d in %s — update any references to it (e.g. docs/qa/*.md)\n", max, FILENAME
          }
        } else first[b] = FILENAME
      }
    }
    END {
      for (k = 1; k <= nf; k++) if (file[k] in changed) {
        out = tmp "/fixed-" k
        for (i = 1; i <= count[file[k]]; i++) print lines[file[k], i] > out
        close(out); system("cp \"" out "\" \"" file[k] "\"")
      }
      exit (dup && !fix) ? 1 : 0
    }
  ' "${files[@]}"
  exit $?
fi

RESOLVE_MODE=0
if [[ "${1:-}" == "--resolve" ]]; then
  RESOLVE_MODE=1
  TARGET_PATH="${2:?usage: merge.sh --resolve <path>}"
  cd "$(git rev-parse --show-toplevel)" || exit 2
  TARGET_PATH="${TARGET_PATH#./}"
  if ! git ls-files -u -- "$TARGET_PATH" | grep -q .; then
    echo "map-merge: $TARGET_PATH is not in a conflicted state — nothing to resolve" >&2
    exit 2
  fi
  git show ":1:$TARGET_PATH" > "$TMP/stage-base" 2>/dev/null || : > "$TMP/stage-base"
  git show ":2:$TARGET_PATH" > "$TMP/stage-ours" 2>/dev/null || : > "$TMP/stage-ours"
  git show ":3:$TARGET_PATH" > "$TMP/stage-theirs" 2>/dev/null || : > "$TMP/stage-theirs"
  BASE="$TMP/stage-base"
  OURS="$TMP/stage-result"
  THEIRS="$TMP/stage-theirs"
  cp "$TMP/stage-ours" "$OURS"
else
  BASE="$1"
  OURS="$2"
  THEIRS="$3"
  TARGET_PATH="${4:-$2}"
fi

cp "$OURS" "$TMP/ours"
cp "$BASE" "$TMP/base"
cp "$THEIRS" "$TMP/theirs"

# Called on every exit path from here on: in --resolve mode the result lives
# in a temp file and has to be copied back to the working tree.
finish() {
  if (( RESOLVE_MODE )); then
    cp "$OURS" "$TARGET_PATH"
  fi
  exit "$1"
}

# ---------------------------------------------------------------------------
# BUG-N de-duplication (docs/BUGS.md, docs/BUGS_ARCHIVE.md only).
# $1 = file to fix in place. Numbers already used on either branch, in either
# bug file, are never handed out again.
# ---------------------------------------------------------------------------
is_bug_file() {
  case "$TARGET_PATH" in
    docs/BUGS.md|*/docs/BUGS.md|docs/BUGS_ARCHIVE.md|*/docs/BUGS_ARCHIVE.md) return 0 ;;
  esac
  return 1
}

# The commit being merged in and the 3-way base, as "<theirs> <base>".
# MERGE_HEAD/REBASE_HEAD don't exist yet while git runs a merge driver, so:
# a merge exports GITHEAD_<sha>; a rebase has just logged "pick <sha>" in
# rebase-merge/done (base = its parent). Anything else (a single
# cherry-pick) prints nothing.
incoming_commit() {
  local sha done_file
  sha="$(env | sed -n 's/^GITHEAD_\([0-9a-f]\{7,\}\)=.*/\1/p' | head -n 1)"
  if [[ -n "$sha" ]]; then
    echo "$sha $(git merge-base HEAD "$sha" 2>/dev/null | head -n 1)"
    return
  fi
  done_file="$(git rev-parse --git-path rebase-merge/done 2>/dev/null)"
  if [[ -s "$done_file" ]]; then
    sha="$(tail -n 1 "$done_file" | awk '{ print $2 }')"
    git rev-parse -q --verify "$sha^{commit}" >/dev/null 2>&1 && echo "$sha $(git rev-parse -q --verify "$sha^" 2>/dev/null)"
  fi
}

renumber_bugs() {
  local file="$1" extra="$TMP/bug-numbers" ref f incoming theirs_ref="" base_ref=""
  incoming="$(incoming_commit)"
  if [[ -n "$incoming" ]]; then theirs_ref="${incoming%% *}"; base_ref="${incoming#* }"; fi
  : > "$extra"
  for f in docs/BUGS.md docs/BUGS_ARCHIVE.md; do
    [[ -f "$f" ]] && cat "$f" >> "$extra"
    for ref in HEAD $theirs_ref; do
      git show "$ref:$f" >> "$extra" 2>/dev/null || true
    done
  done
  cat "$TMP/ours" "$TMP/theirs" "$TMP/base" >> "$extra"
  cp "$file" "$TMP/to-count" # distinct name, so awk can tell the counting pass from the rewrite pass

  # Numbers our side already uses in the other bug file that weren't there at
  # the merge base — e.g. we found BUG-3 and archived it straight away while
  # they opened a different BUG-3. Their heading with that number is renumbered.
  local other cross=""
  case "$TARGET_PATH" in
    *BUGS_ARCHIVE.md) other="${TARGET_PATH%BUGS_ARCHIVE.md}BUGS.md" ;;
    *) other="${TARGET_PATH%BUGS.md}BUGS_ARCHIVE.md" ;;
  esac
  heading_numbers() { grep -oE '^#+[[:space:]]+BUG-[0-9]+' | grep -oE '[0-9]+$' | sort -u; }
  { [[ -n "$base_ref" ]] && git show "$base_ref:$other" 2>/dev/null; cat "$TMP/base"; } | heading_numbers > "$TMP/base-numbers"
  if [[ -n "$base_ref" ]]; then
    cross="$(git show "HEAD:$other" 2>/dev/null | heading_numbers | grep -vxF -f "$TMP/base-numbers" | tr '\n' ' ')"
  fi
  : > "$TMP/same-bug"

  # A number that existed at the merge base and now has two entries is one bug
  # both branches handled (e.g. both fixed and archived it) — renumbering would
  # invent a bug, so that's left for review: returns 1.
  awk -v path="$TARGET_PATH" -v other="$other" -v cross="$cross" -v basenums="$(tr '\n' ' ' < "$TMP/base-numbers")" -v same="$TMP/same-bug" '
    function in_code(line) {
      if (line ~ /^[[:space:]]*(```|~~~)/) { fence = !fence; return 1 }
      if (fence) return 1
      if (comment) { if (line ~ /-->/) comment = 0; return 1 }
      if (line ~ /<!--/ && line !~ /-->/) { comment = 1; return 1 }
      return 0
    }
    function bug_number(line,    s) {
      if (match(line, /^#+[[:space:]]+BUG-[0-9]+/)) {
        s = substr(line, 1, RLENGTH); sub(/^#+[[:space:]]+BUG-/, "", s); return s + 0
      }
      return -1
    }
    BEGIN {
      n = split(cross, c, " "); for (i = 1; i <= n; i++) taken[c[i] + 0] = 1
      n = split(basenums, c, " "); for (i = 1; i <= n; i++) at_base[c[i] + 0] = 1
    }
    FNR == 1 { fence = 0; comment = 0 }
    # Pass 1: every number ever used, anywhere, for "next free".
    FILENAME == ARGV[1] {
      n = split($0, parts, /BUG-/)
      for (i = 2; i <= n; i++) if (match(parts[i], /^[0-9]+/)) {
        v = substr(parts[i], 1, RLENGTH) + 0; if (v > max) max = v
      }
      next
    }
    # Pass 2: headings that already existed on our side keep their number.
    FILENAME == ARGV[2] { if (!in_code($0)) { b = bug_number($0); if (b >= 0) ours_heading[$0] = 1 }; next }
    # Pass 3: count headings per number in the merged file.
    FILENAME == ARGV[3] { if (!in_code($0)) { b = bug_number($0); if (b >= 0) { count[b]++; if ($0 in ours_heading) keeper[b] = $0 } }; next }
    # Pass 4: rewrite.
    {
      line = $0
      if (!in_code(line)) {
        b = bug_number(line)
        if (b >= 0 && (b in taken) && !(line in ours_heading)) {
          max++
          sub("BUG-" b, "BUG-" max, line)
          printf "map-merge: %s got BUG-%d from the other branch, but your side already uses BUG-%d in %s — renumbered theirs to BUG-%d; update any references to it (e.g. docs/qa/*.md)\n", path, b, b, other, max > "/dev/stderr"
        } else if (b >= 0 && count[b] > 1 && (b in at_base)) {
          if (!(b in reported)) {
            reported[b] = 1; print b >> same
            printf "map-merge: %s has BUG-%d twice — it existed before the branches split, so both handled the same bug. Keep one entry (or combine them), then git add.\n", path, b > "/dev/stderr"
          }
        } else if (b >= 0 && count[b] > 1) {
          if (!(b in keeper)) keeper[b] = line
          if (line != keeper[b] || (b in kept)) {
            max++
            sub("BUG-" b, "BUG-" max, line)
            printf "map-merge: %s had BUG-%d twice after merging — renumbered one to BUG-%d; update any references to it (e.g. docs/qa/*.md)\n", path, b, max > "/dev/stderr"
          } else {
            kept[b] = 1
          }
        }
      }
      print line
    }
  ' "$extra" "$TMP/ours" "$TMP/to-count" "$file" > "$TMP/renumbered" && cp "$TMP/renumbered" "$file"
  [[ ! -s "$TMP/same-bug" ]]
}

# ---------------------------------------------------------------------------
# Step 1 — git's own merge: the fast path and the fallback.
# ---------------------------------------------------------------------------
git merge-file -p --diff3 --marker-size="$MARKER_SIZE" \
  -L ours -L base -L theirs \
  "$TMP/ours" "$TMP/base" "$TMP/theirs" > "$TMP/standard"
STATUS=$?

if (( STATUS < 0 || STATUS > 127 )); then
  finish 1 # git merge-file itself failed — leave %A untouched, git reports a conflict
fi

cp "$TMP/standard" "$OURS"
# A clean result is only used once it passes the entry check below (after the
# block helpers are defined).

# ---------------------------------------------------------------------------
# Step 2 — rules.
# ---------------------------------------------------------------------------

# Splits $1 into blocks under $2/: one file per block (0001, 0002, ...) and an
# index of "id<TAB>key". A block is a heading line plus everything up to the
# next heading; the key is the heading path ("## Open bugs > ### BUG-3 — x"),
# with "#n" appended to repeated paths. Text before the first heading is the
# "(preamble)" block.
split_blocks() {
  mkdir -p "$2"
  awk -v dir="$2" '
    # Index columns: id, key, and whether a blank line preceded this block on
    # this side — used to keep entry spacing when blocks from both sides meet.
    function start_block(key) {
      if (out != "") close(out)
      seen[key]++
      if (seen[key] > 1) key = key "#" seen[key]
      id++
      out = sprintf("%s/%04d", dir, id)
      printf "" > out
      printf "%04d\t%s\t%d\n", id, key, (last ~ /^[[:space:]]*$/ && id > 1) > (dir "/index")
    }
    BEGIN { start_block("(preamble)"); fence = 0; comment = 0 }
    {
      heading = 0
      if ($0 ~ /^[[:space:]]*(```|~~~)/) fence = !fence
      else if (fence) { }
      else if (comment) { if ($0 ~ /-->/) comment = 0 }
      else if ($0 ~ /<!--/ && $0 !~ /-->/) comment = 1
      else if (match($0, /^#+[[:space:]]/)) heading = 1

      if (heading) {
        level = RLENGTH - 1
        path[level] = $0
        for (l in path) if (l + 0 > level) delete path[l]
        key = ""
        for (l = 1; l <= level; l++) if (l in path) key = (key == "" ? path[l] : key " > " path[l])
        start_block(key)
      }
      print > out
      last = $0
    }
    END { if (out != "") close(out); close(dir "/index") }
  ' "$1"
}

# Resolves the safe-shaped conflict hunks of a --diff3 merge-file output on
# stdin and re-emits the rest verbatim, markers and all. Exits 1 if any hunk
# was left unresolved. $1 = "ours"/"theirs" for a snapshot block: whatever the
# other rules can't settle is taken from that (newer) side, and a line is
# appended to $TMP/snapshot-used for each hunk or row that needed it.
resolve_hunks() {
  awk -v size="$MARKER_SIZE" -v prefer="${1:-}" -v used="$TMP/snapshot-used" '
    function marker(ch,    m, i) { m = ""; for (i = 0; i < size; i++) m = m ch; return m }
    function is_row(line) { return line ~ /^[[:space:]]*\|/ }
    function all_rows(arr, n,    i) { for (i = 1; i <= n; i++) if (!is_row(arr[i])) return 0; return 1 }
    function date_of(line) { if (match(line, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) return substr(line, RSTART, RLENGTH); return "" }
    function row_key(line,    k) {
      k = line; sub(/^[[:space:]]*\|/, "", k); sub(/\|.*/, "", k)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k); return k
    }

    # Table rows only: 3-way merge keyed by first cell (repeats keyed by occurrence).
    function merge_rows(    i, k, occ, order, n, ino, inb, int_) {
      split("", ro); split("", rb); split("", rt); split("", order)
      n = 0
      split("", occ); for (i = 1; i <= nb; i++) { k = row_key(b[i]); k = k SUBSEP (++occ[k]); rb[k] = b[i] }
      split("", occ); for (i = 1; i <= no; i++) { k = row_key(o[i]); k = k SUBSEP (++occ[k]); ro[k] = o[i]; order[++n] = k }
      split("", occ); for (i = 1; i <= nt; i++) { k = row_key(t[i]); k = k SUBSEP (++occ[k]); rt[k] = t[i]; if (!(k in ro)) order[++n] = k }
      # Deleted on one side is only safe if the other side left the row
      # unchanged — unless this is a snapshot block, where the newer side decides.
      if (prefer == "") for (k in rb) {
        if ((k in ro) && !(k in rt) && ro[k] != rb[k]) return 0
        if ((k in rt) && !(k in ro) && rt[k] != rb[k]) return 0
      }
      out_n = 0; picked = 0
      for (i = 1; i <= n; i++) {
        k = order[i]; ino = (k in ro); inb = (k in rb); int_ = (k in rt)
        if (ino && int_) {
          if (ro[k] == rt[k]) out[++out_n] = ro[k]
          else if (inb && ro[k] == rb[k]) out[++out_n] = rt[k]
          else if (inb && rt[k] == rb[k]) out[++out_n] = ro[k]
          else if (prefer != "") { out[++out_n] = (prefer == "theirs" ? rt[k] : ro[k]); picked++ }
          else return 0 # both changed (or both added) this row differently
        } else if (ino) {
          if (!inb) out[++out_n] = ro[k] # added on our side; else deleted by them, unchanged here
          else if (ro[k] != rb[k]) { picked++; if (prefer == "ours") out[++out_n] = ro[k] } # changed here, deleted there
        } else if (int_) {
          if (!inb) out[++out_n] = rt[k]
          else if (rt[k] != rb[k]) { picked++; if (prefer == "theirs") out[++out_n] = rt[k] }
        }
      }
      for (i = 1; i <= out_n; i++) print out[i]
      for (i = 1; i <= picked; i++) print "row" >> used
      return 1
    }

    # List items only (one list, one indent): 3-way merge keyed by item text.
    # One-line dated entries ("2026-09-10 — ...", as in memory/shared.md)
    # count as items too. An item removed on either side stays removed; items
    # added on either side are kept, ours then theirs; numbered items are
    # renumbered. Items kept by both sides must keep their relative order — a
    # reprioritised list is a real conflict.
    function item_prefix(line) { return match(line, /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+/) ? substr(line, 1, RLENGTH) : "" }
    function is_item(line) { return item_prefix(line) != "" || line ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]/ }
    function indent_of(line) { match(line, /^[[:space:]]*/); return RLENGTH }
    function all_items(arr, n, ind,    i) {
      for (i = 1; i <= n; i++) if (!is_item(arr[i]) || indent_of(arr[i]) != ind) return 0
      return 1
    }
    function item_keys(arr, n, keys, set,    i, k, occ) {
      split("", occ)
      for (i = 1; i <= n; i++) { k = substr(arr[i], length(item_prefix(arr[i])) + 1); k = k SUBSEP (++occ[k]); keys[i] = k; set[k] = i }
    }
    function merge_list(    ind, ko, kb, kt, so, sb, st, i, k, s1, s2, c1, c2, num, line, p) {
      ind = indent_of(b[1])
      if (!all_items(o, no, ind) || !all_items(b, nb, ind) || !all_items(t, nt, ind)) return 0
      split("", ko); split("", kb); split("", kt); split("", so); split("", sb); split("", st)
      item_keys(o, no, ko, so); item_keys(b, nb, kb, sb); item_keys(t, nt, kt, st)
      c1 = c2 = 0
      for (i = 1; i <= no; i++) if ((ko[i] in sb) && (ko[i] in st)) s1[++c1] = ko[i]
      for (i = 1; i <= nt; i++) if ((kt[i] in sb) && (kt[i] in so)) s2[++c2] = kt[i]
      for (i = 1; i <= c1; i++) if (s1[i] != s2[i]) return 0
      out_n = 0
      for (i = 1; i <= no; i++) if (!((ko[i] in sb) && !(ko[i] in st))) out[++out_n] = o[i]
      for (i = 1; i <= nt; i++) if (!(kt[i] in sb) && !(kt[i] in so)) out[++out_n] = t[i]
      num = -1
      if (match(b[1], /^[[:space:]]*[0-9]+/)) num = substr(b[1], ind + 1, RLENGTH - ind) + 0
      for (i = 1; i <= out_n; i++) {
        line = out[i]
        if (num >= 0 && match(line, /^[[:space:]]*[0-9]+/)) { p = substr(line, 1, ind); line = p num substr(line, RLENGTH + 1); num++ }
        print line
      }
      return 1
    }

    function resolve(    i, have) {
      # Nothing in the base: both sides only inserted here — ours, then theirs
      # (minus non-blank lines ours already has).
      if (nb == 0) {
        split("", have)
        for (i = 1; i <= no; i++) { print o[i]; have[o[i]] = 1 }
        for (i = 1; i <= nt; i++) if (t[i] ~ /^[[:space:]]*$/ || !(t[i] in have)) print t[i]
        return 1
      }
      # One "Last updated" line changed on both sides — keep the newest.
      if (no == 1 && nb == 1 && nt == 1 && o[1] ~ /Last updated/ && t[1] ~ /Last updated/ && date_of(o[1]) != "" && date_of(t[1]) != "") {
        print (date_of(t[1]) > date_of(o[1]) ? t[1] : o[1])
        return 1
      }
      if (all_rows(o, no) && all_rows(b, nb) && all_rows(t, nt)) { if (merge_rows()) return 1 }
      else if (merge_list()) return 1
      # Snapshot block: re-measured every session, so the newer side wins.
      # The older side still keeps any snapshot marker it added, e.g. one
      # added by a MAP upgrade while a branch updated the values beneath it.
      if (prefer == "ours") { keep_markers(t, nt, o, no); for (i = 1; i <= no; i++) print o[i]; print "hunk" >> used; return 1 }
      if (prefer == "theirs") { keep_markers(o, no, t, nt); for (i = 1; i <= nt; i++) print t[i]; print "hunk" >> used; return 1 }
      return 0
    }
    function keep_markers(from, nf, into, ni,    i, j, has) {
      for (i = 1; i <= nf; i++) if (from[i] ~ /<!--[[:space:]]*map-merge:[[:space:]]*snapshot/) {
        has = 0; for (j = 1; j <= ni; j++) if (into[j] == from[i]) has = 1
        if (!has) print from[i]
      }
    }

    function emit_verbatim(    i) {
      print start_line
      for (i = 1; i <= no; i++) print o[i]
      print mid_line
      for (i = 1; i <= nb; i++) print b[i]
      print sep
      for (i = 1; i <= nt; i++) print t[i]
      print stop_line
    }

    BEGIN { start = marker("<") " "; mid = marker("|") " "; sep = marker("="); stop = marker(">") " "; state = 0 }
    state == 0 && index($0, start) == 1 { state = 1; no = nb = nt = 0; start_line = $0; next }
    state == 1 && index($0, mid) == 1 { state = 2; mid_line = $0; next }
    state == 2 && $0 == sep { state = 3; next }
    state == 3 && index($0, stop) == 1 {
      stop_line = $0
      # merge_rows prints nothing until it knows it succeeds, so a failed
      # resolve() never leaves partial output behind.
      if (!resolve()) { emit_verbatim(); unresolved = 1 }
      state = 0; next
    }
    state == 1 { o[++no] = $0; next }
    state == 2 { b[++nb] = $0; next }
    state == 3 { t[++nt] = $0; next }
    { print }
    END { if (state != 0) exit 2; exit unresolved ? 1 : 0 }
  '
}

# Writes a synthetic conflict hunk for a block edited on one side and deleted
# on the other. $1 = ours file, $2 = base file, $3 = theirs file.
conflict_hunk() {
  printf '%s ours\n' "$(printf '%*s' "$MARKER_SIZE" '' | tr ' ' '<')"
  cat "$1"
  printf '%s base\n' "$(printf '%*s' "$MARKER_SIZE" '' | tr ' ' '|')"
  cat "$2"
  printf '%s\n' "$(printf '%*s' "$MARKER_SIZE" '' | tr ' ' '=')"
  cat "$3"
  printf '%s theirs\n' "$(printf '%*s' "$MARKER_SIZE" '' | tr ' ' '>')"
}

# Snapshot blocks hold values re-measured every session (test counts,
# coverage, health) — both branches' numbers are stale after a merge anyway,
# so conflicts there go to the newer side instead of stopping the merge.
# A "<!-- map-merge: snapshot -->" comment marks its own block; one above the
# first ## heading (under the # title) marks the whole file.
SNAPSHOT_RE='<!--[[:space:]]*map-merge:[[:space:]]*snapshot'
is_snapshot() { grep -q "$SNAPSHOT_RE" "$@" 2>/dev/null; }
newest_date() { grep -o '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "$1" 2>/dev/null | sort | tail -n 1; }
newer_side() { # $1 = ours block, $2 = theirs block → "ours" or "theirs" (ours on a tie)
  local a b
  a="$(newest_date "$1")"; b="$(newest_date "$2")"
  if [[ "$a" == "$b" ]]; then a="$(newest_date "$TMP/ours")"; b="$(newest_date "$TMP/theirs")"; fi
  if [[ "$b" > "$a" ]]; then echo theirs; else echo ours; fi
}
: > "$TMP/snapshot-used"

split_blocks "$TMP/ours" "$TMP/A"
split_blocks "$TMP/base" "$TMP/O"
split_blocks "$TMP/theirs" "$TMP/B"

# Joins the block indexes of the side dirs given (after $1) by heading key, in
# first-seen order across them, as one line per key:
#   key <TAB> id per side <TAB> content class per side
# "-" marks a side without that block. Blocks with equal content get equal
# class numbers, so callers compare sides without reading files. $1 = 1 to
# ignore trailing blank lines when comparing. One awk pass instead of a
# lookup, cmp and cp per block — archives run to hundreds of entries.
join_blocks() {
  local strip="$1" d; shift
  local indexes=()
  for d in "$@"; do indexes+=("$d/index"); done
  awk -F'\t' -v strip="$strip" -v sides="$#" '
    FNR == 1 { side++; dir[side] = FILENAME; sub(/\/index$/, "", dir[side]) }
    { if (!($2 in known)) { known[$2] = 1; keys[++count] = $2 }; id[side, $2] = $1 }
    function content(path,    s, pending, line) {
      s = ""; pending = ""
      while ((getline line < path) > 0) {
        if (line ~ /^[[:space:]]*$/) { pending = pending line "\n"; continue }
        s = s pending line "\n"; pending = ""
      }
      close(path)
      return strip ? s : s pending
    }
    END {
      for (i = 1; i <= count; i++) {
        k = keys[i]; ids = ""; classes = ""; split("", class); n = 0
        for (sd = 1; sd <= sides; sd++) {
          if ((sd, k) in id) {
            c = content(dir[sd] "/" id[sd, k])
            if (!(c in class)) class[c] = ++n
            ids = ids "\t" id[sd, k]; classes = classes "\t" class[c]
          } else { ids = ids "\t-"; classes = classes "\t-" }
        }
        print k ids classes
      }
    }
  ' "${indexes[@]}"
}

# git's line merge matches identical lines, and MAP entries repeat the same
# field lines ("- **Status:** open"), so a "clean" merge can land one side's
# edit in a neighbouring entry nobody touched. Trust it only if every entry
# neither side changed comes out unchanged, and every entry one side changed
# comes out as that side's version; otherwise fall through to the rules.
git_merge_is_trustworthy() {
  local key a o b r ca co cb cr
  split_blocks "$TMP/standard" "$TMP/S"
  while IFS=$'\t' read -r key a o b r ca co cb cr; do
    [[ "$a" != - && "$b" != - && "$o" != - ]] || continue
    if [[ "$ca" == "$co" ]]; then [[ "$cr" == "$cb" ]] || return 1   # only they changed it (or nobody)
    elif [[ "$cb" == "$co" ]]; then [[ "$cr" == "$ca" ]] || return 1 # only we changed it
    fi # both changed it — git's merge of the two is as good as any
  done < <(join_blocks 1 "$TMP/A" "$TMP/O" "$TMP/B" "$TMP/S")
  return 0
}

if (( STATUS == 0 )); then
  if git_merge_is_trustworthy; then
    if is_bug_file && ! renumber_bugs "$OURS"; then finish 1; fi
    finish 0
  fi
  echo "map-merge: $TARGET_PATH — git's line merge moved an edit into an entry neither branch changed; merging entry by entry instead." >&2
fi
FILE_SNAPSHOT=0
for f in "$TMP/ours" "$TMP/theirs"; do
  awk '/^##+[[:space:]]/ { exit } { print }' "$f" > "$TMP/file-head"
  if is_snapshot "$TMP/file-head"; then FILE_SNAPSHOT=1; fi
done
mkdir -p "$TMP/R"
: > "$TMP/R/index" # "<path of the block's result><TAB>key" per kept block
: > "$TMP/empty"

conflict=0
n=0
while IFS=$'\t' read -r key a o b ca co cb; do
  fa="$TMP/A/$a"; fo="$TMP/O/$o"; fb="$TMP/B/$b"
  if [[ "$a" == - ]]; then a=""; fa="$TMP/empty"; fi
  if [[ "$o" == - ]]; then o=""; fo="$TMP/empty"; fi
  if [[ "$b" == - ]]; then b=""; fb="$TMP/empty"; fi

  n=$((n + 1))
  printf -v out '%s/R/%04d' "$TMP" "$n"
  keep=""

  if [[ -z "$a" && -z "$b" ]]; then
    : # deleted on both sides
  elif [[ -n "$a" && -n "$b" && "$ca" == "$cb" ]]; then
    keep="$fa"
  elif [[ -n "$o" && -z "$a" ]]; then
    if [[ "$cb" != "$co" ]]; then
      conflict_hunk "$fa" "$fo" "$fb" > "$out"; conflict=1; keep="$out" # we deleted it, they edited it
    fi # else: we deleted it, they didn't touch it
  elif [[ -n "$o" && -z "$b" ]]; then
    if [[ "$ca" != "$co" ]]; then
      conflict_hunk "$fa" "$fo" "$fb" > "$out"; conflict=1; keep="$out"
    fi
  elif [[ -n "$o" && "$ca" == "$co" ]]; then
    keep="$fb"
  elif [[ -n "$o" && "$cb" == "$co" ]]; then
    keep="$fa"
  elif [[ -z "$o" && -z "$b" ]]; then
    keep="$fa" # new on our side only
  elif [[ -z "$o" && -z "$a" ]]; then
    keep="$fb" # new on their side only
  elif [[ -z "$o" ]]; then
    # Both sides added a block with the same heading (e.g. two sessions logging
    # the same date) — keep both entries whole rather than interleave them.
    cat "$fa" "$fb" > "$out"; keep="$out"
  else
    # Changed on both sides.
    keep="$out"
    git merge-file -p --diff3 --marker-size="$MARKER_SIZE" -L ours -L base -L theirs \
      "$fa" "$fo" "$fb" > "$out.merged"
    st=$?
    if (( st == 0 )); then
      mv "$out.merged" "$out"
    elif (( st > 0 && st < 128 )); then
      prefer=""
      if [[ "$FILE_SNAPSHOT" == 1 ]] || is_snapshot "$fa" "$fb"; then prefer="$(newer_side "$fa" "$fb")"; fi
      resolve_hunks "$prefer" < "$out.merged" > "$out"
      rst=$?
      if (( rst == 1 )); then
        conflict=1
      elif (( rst != 0 )); then
        cp "$out.merged" "$out"; conflict=1
      fi
      rm -f "$out.merged"
    else
      conflict_hunk "$fa" "$fo" "$fb" > "$out"; conflict=1
    fi
  fi

  if [[ -n "$keep" ]]; then
    printf '%s\t%s\n' "$keep" "$key" >> "$TMP/R/index"
  fi
done < <(join_blocks 0 "$TMP/A" "$TMP/O" "$TMP/B")

# Order: our blocks in our order; each block only they have goes right after
# the nearest block preceding it on their side — and after any new blocks of
# ours already sitting there, so appends read ours-then-theirs.
cut -f2 "$TMP/A/index" > "$TMP/order-a"
cut -f2 "$TMP/B/index" > "$TMP/order-b"
cp "$TMP/order-b" "$TMP/theirs-keys"
awk -F'\t' '
  function index_of(key,    i) { for (i = 1; i <= n; i++) if (out[i] == key) return i; return 0 }
  FILENAME == ARGV[1] { res[$2] = $1; next }
  FILENAME == ARGV[2] { if ($0 in res) { out[++n] = $0; ours[$0] = 1 }; next }
  FILENAME == ARGV[3] { theirs[$0] = 1; next }
  {
    if ($0 in ours || $0 in placed) { anchor = $0; next }
    if (!($0 in res)) next
    pos = (anchor == "") ? 0 : index_of(anchor)
    while (pos < n && !(out[pos + 1] in theirs)) pos++ # skip past our own new blocks
    for (i = n; i > pos; i--) out[i + 1] = out[i]
    out[pos + 1] = $0; n++
    placed[$0] = 1; anchor = $0
  }
  END { for (i = 1; i <= n; i++) print res[out[i]] "\t" out[i] }
' "$TMP/R/index" "$TMP/order-a" "$TMP/theirs-keys" "$TMP/order-b" > "$TMP/order"

# Assemble. A blank line goes between blocks when one preceded the block on
# its own side (ours, else theirs) and the result doesn't already end blank.
awk -F'\t' '
  FILENAME == ARGV[1] { blank[$2] = $3; next }
  FILENAME == ARGV[2] { if (!($2 in blank)) blank[$2] = $3; next }
  {
    path = $1; key = substr($0, length(path) + 2)
    if (started && last != "" && blank[key] == 1) print ""
    while ((getline line < path) > 0) { print line; last = line; started = 1 }
    close(path)
  }
' "$TMP/A/index" "$TMP/B/index" "$TMP/order" > "$TMP/result"

if [[ -s "$TMP/snapshot-used" ]]; then
  echo "map-merge: $TARGET_PATH — $(wc -l < "$TMP/snapshot-used" | tr -d ' ') snapshot value(s) changed on both branches; kept the newer side's. Neither branch measured the merged code, so re-verify them next session." >&2
fi

if (( ! conflict )); then
  cp "$TMP/result" "$OURS"
  if is_bug_file && ! renumber_bugs "$OURS"; then finish 1; fi
  finish 0
fi

# Rules resolved what they could; markers remain only around real conflicts.
cp "$TMP/result" "$OURS"

# ---------------------------------------------------------------------------
# Step 3 — Claude, for what the rules left. Stop-for-review either way.
# ---------------------------------------------------------------------------
count_hunks() {
  grep -c "^$(printf '%*s' "$MARKER_SIZE" '' | tr ' ' '<') " "$1"
}

llm_command() {
  [[ "${MAP_MERGE_LLM:-1}" != "0" ]] || return 1
  [[ "$(git config --get map-ai.llm 2>/dev/null)" != "false" ]] || return 1
  local cmd model
  cmd="${MAP_MERGE_LLM_COMMAND:-$(git config --get map-ai.llmCommand 2>/dev/null)}"
  if [[ -z "$cmd" ]]; then
    command -v claude >/dev/null 2>&1 || return 1
    # No tools, no MCP servers, no saved session; run from a temp dir so the
    # project's own CLAUDE.md / hooks don't load into a one-shot merge call.
    cmd="claude -p --tools '' --strict-mcp-config --no-session-persistence"
    model="${MAP_MERGE_MODEL:-$(git config --get map-ai.model 2>/dev/null)}"
    [[ -n "$model" ]] && cmd="$cmd --model '$model'"
  fi
  printf '%s' "$cmd"
}

# Runs `sh -c $1` with stdin $2, stdout $3, killed after $4 seconds. Portable
# (no coreutils timeout on stock macOS).
run_with_timeout() {
  local pid watcher st
  # exec all the way down so the pid killed on timeout is the command itself.
  # CLAUDECODE / CLAUDE_PROJECT_DIR are cleared so a merge run from inside a
  # Claude Code session doesn't hand its session to the one-shot call.
  (cd "$TMP" && unset CLAUDECODE CLAUDE_PROJECT_DIR && exec sh -c "exec $1") < "$2" > "$3" 2> "$TMP/llm-stderr" &
  pid=$!
  # The watcher kills its own sleep when stopped, and holds no inherited fds —
  # a stray sleep would otherwise keep git's stderr pipe open after we exit.
  (
    sleep "$4" &
    sleeper=$!
    trap 'kill "$sleeper" 2>/dev/null; exit 0' TERM
    wait "$sleeper" && kill "$pid" 2>/dev/null
  ) </dev/null >/dev/null 2>&1 &
  watcher=$!
  wait "$pid"; st=$?
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  return "$st"
}

commit_subjects() { # $1 = ref → subjects on $1 since the merge base, touching the file
  local mb
  mb="$(git merge-base HEAD "$1" 2>/dev/null)" || return 0
  git log --format='- %s' -8 "$mb..$1" -- "$TARGET_PATH" 2>/dev/null
}

# Splits the conflicted file into hunks under $TMP/H/ (n.ours, n.base,
# n.theirs) and writes the conflict section of the prompt to $TMP/H/prompt.
extract_hunks() {
  mkdir -p "$TMP/H"
  awk -v size="$MARKER_SIZE" -v dir="$TMP/H" -v ctx=8 '
    function marker(ch,    m, i) { m = ""; for (i = 0; i < size; i++) m = m ch; return m }
    BEGIN { start = marker("<") " "; mid = marker("|") " "; sep = marker("="); stop = marker(">") " " }
    { line[NR] = $0 }
    END {
      state = 0; h = 0
      for (i = 1; i <= NR; i++) {
        l = line[i]
        if (state == 0 && index(l, start) == 1) { h++; state = 1; first[h] = i; continue }
        if (state == 1 && index(l, mid) == 1) { state = 2; continue }
        if (state == 2 && l == sep) { state = 3; continue }
        if (state == 3 && index(l, stop) == 1) { state = 0; last[h] = i; continue }
        if (state == 1) print l > (dir "/" h ".ours")
        else if (state == 2) print l > (dir "/" h ".base")
        else if (state == 3) print l > (dir "/" h ".theirs")
      }
      p = dir "/prompt"
      for (k = 1; k <= h; k++) {
        printf "\n--- CONFLICT %d ---\nLines just before it:\n", k > p
        for (i = first[k] - ctx; i < first[k]; i++) if (i >= 1 && !is_marker_region(i)) print line[i] > p
        printf "OURS (this branch):\n" > p;   dump(dir "/" k ".ours", p)
        printf "BASE (common ancestor):\n" > p; dump(dir "/" k ".base", p)
        printf "THEIRS (incoming branch):\n" > p; dump(dir "/" k ".theirs", p)
        printf "Lines just after it:\n" > p
        for (i = last[k] + 1; i <= last[k] + ctx && i <= NR; i++) if (!is_marker_region(i)) print line[i] > p
      }
      print h > (dir "/count")
    }
    function is_marker_region(i,    k) { for (k = 1; k <= h; k++) if (i >= first[k] && i <= last[k]) return 1; return 0 }
    # close() first: the hunk files were written by print above and may still be buffered.
    function dump(f, p,    l) { close(f); while ((getline l < f) > 0) print l > p; close(f) }
  ' "$1"
  local k
  for ((k = 1; k <= $(cat "$TMP/H/count"); k++)); do
    touch "$TMP/H/$k.ours" "$TMP/H/$k.base" "$TMP/H/$k.theirs"
  done
}

build_prompt() {
  local header ours_log theirs_log ref
  header="$(awk '/^## / { exit } NR <= 15 { print }' "$TMP/ours")"
  ours_log="$(commit_subjects HEAD)"
  for ref in MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD; do
    if git rev-parse -q --verify "$ref" >/dev/null 2>&1; then
      theirs_log="$(commit_subjects "$ref")"
      [[ -n "$theirs_log" ]] || theirs_log="$(git log -1 --format='- %s' "$ref" 2>/dev/null)"
      break
    fi
  done
  cat <<PROMPT
You are resolving git merge conflicts in a Markdown documentation file that AI coding agents maintain for a software project (the MAP convention: docs the agent keeps current as it works — bug lists, decision logs, status, schema notes, and so on).

Each conflict below shows OURS (this branch), BASE (the common ancestor) and THEIRS (the incoming branch), with the lines around it. Write the text that should replace each conflict.

Rules:
1. Keep every piece of information from both sides, unless one side deliberately removed it — a line present in BASE but missing from OURS or THEIRS was removed on purpose.
2. Follow the file's own maintenance rules in its header below (e.g. append-only logs never lose entries; "Last updated" takes the newest date; bug numbers are never reused).
3. When both sides changed the same fact differently, combine them if they don't contradict; if they do, prefer the more recent or more specific one.
4. Do not invent content, headings, or entries. Do not add commentary or explanations.
5. Keep the Markdown valid — tables, lists, and headings in the same style as the surrounding lines.
6. If you cannot resolve a conflict with confidence, mark it UNRESOLVED instead of guessing.

File: $TARGET_PATH

The file's header (its own rules):
$header

Commits on this branch that touched the file:
${ours_log:-(none found)}

Commits on the incoming branch that touched the file:
${theirs_log:-(none found)}
$(cat "$TMP/H/prompt")

Reply in exactly this format and nothing else — one block per conflict, in order:
=== RESOLUTION 1 ===
<the lines that replace conflict 1>
=== RESOLUTION 2 ===
<the lines that replace conflict 2>
=== END ===
For a conflict you cannot resolve, write the single line "=== UNRESOLVED n ===" in place of its RESOLUTION block.
PROMPT
}

# Parses the reply in $1 into $TMP/H/n.res files (unresolved ones get none).
parse_reply() {
  awk -v dir="$TMP/H" '
    /^=== RESOLUTION [0-9]+ ===[[:space:]]*$/ { if (f) close(f); n = $3; f = dir "/" n ".res"; printf "" > f; next }
    /^=== UNRESOLVED [0-9]+ ===[[:space:]]*$/ { if (f) close(f); f = ""; next }
    /^=== END ===[[:space:]]*$/ { if (f) close(f); f = ""; ended = 1; exit }
    f != "" { print > f }
    END { if (f) close(f) }
  ' "$1"
}

# Accepts $TMP/H/$1.res only if it keeps what both sides agree must survive.
validate_resolution() {
  local k="$1"
  [[ -f "$TMP/H/$k.res" ]] || return 1
  awk -v size="$MARKER_SIZE" '
    function marker(ch,    m, i) { m = ""; for (i = 0; i < size; i++) m = m ch; return m }
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    # The things a resolution must not silently lose: headings, table-row keys,
    # and dated one-line entries.
    function token(line,    k) {
      if (line ~ /^#+[[:space:]]/) return "H:" trim(line)
      if (line ~ /^[[:space:]]*\|/) {
        k = line; sub(/^[[:space:]]*\|/, "", k); sub(/\|.*/, "", k); k = trim(k)
        if (k ~ /^:?-+:?$/ || k == "") return ""
        return "R:" k
      }
      if (line ~ /^[[:space:]]*[-*]?[[:space:]]*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) return "D:" trim(line)
      return ""
    }
    FNR == 1 { file++ }
    {
      t = token($0)
      if (file == 1) { if (t != "") ours[t] = 1 }
      else if (file == 2) { if (t != "") base[t] = 1 }
      else if (file == 3) { if (t != "") theirs[t] = 1 }
      else {
        if (index($0, marker("<") " ") == 1 || index($0, marker(">") " ") == 1 || index($0, marker("|") " ") == 1 || $0 == marker("=")) bad = 1
        if (t != "") { res[t] = 1; if (t ~ /^H:/ && !(t in ours) && !(t in theirs) && !(t in base)) bad = 1 }
      }
    }
    END {
      if (bad) exit 1
      for (t in ours) if (!(t in res) && !((t in base) && !(t in theirs))) exit 1
      for (t in theirs) if (!(t in res) && !((t in base) && !(t in ours))) exit 1
    }
  ' "$TMP/H/$k.ours.v" "$TMP/H/$k.base.v" "$TMP/H/$k.theirs.v" "$TMP/H/$k.res.v"
}

# awk skips empty files entirely (FNR never hits 1), so validation reads
# copies with a sentinel line that yields no token.
prepare_validation_inputs() {
  local k="$1" s
  for s in ours base theirs res; do
    { echo ""; cat "$TMP/H/$k.$s" 2>/dev/null; } > "$TMP/H/$k.$s.v"
  done
}

# Replaces each accepted hunk in $1 with its resolution; others stay as-is.
splice() {
  awk -v size="$MARKER_SIZE" -v dir="$TMP/H" '
    function marker(ch,    m, i) { m = ""; for (i = 0; i < size; i++) m = m ch; return m }
    BEGIN { start = marker("<") " "; stop = marker(">") " "; h = 0; inside = 0 }
    inside == 0 && index($0, start) == 1 {
      h++
      if ((getline ok < (dir "/" h ".accepted")) > 0) { close(dir "/" h ".accepted"); inside = 2; f = dir "/" h ".res"; while ((getline l < f) > 0) print l; close(f); next }
      inside = 1; print; next
    }
    inside == 1 { print; if (index($0, stop) == 1) inside = 0; next }
    inside == 2 { if (index($0, stop) == 1) inside = 0; next }
    { print }
  ' "$1"
}

remaining="$(count_hunks "$OURS")"
resolved_by_llm=0

if cmd="$(llm_command)"; then
  extract_hunks "$OURS"
  build_prompt > "$TMP/llm-prompt"
  echo "map-merge: asking Claude to resolve $remaining conflict(s) in $TARGET_PATH…" >&2
  if run_with_timeout "$cmd" "$TMP/llm-prompt" "$TMP/llm-reply" "${MAP_MERGE_LLM_TIMEOUT:-180}"; then
    parse_reply "$TMP/llm-reply"
    for ((k = 1; k <= remaining; k++)); do
      prepare_validation_inputs "$k"
      if validate_resolution "$k"; then
        echo ok > "$TMP/H/$k.accepted"
        resolved_by_llm=$((resolved_by_llm + 1))
      fi
    done
    if (( resolved_by_llm > 0 )); then
      splice "$OURS" > "$TMP/spliced" && cp "$TMP/spliced" "$OURS"
    fi
  else
    echo "map-merge: Claude call failed or timed out — leaving the conflicts for you" >&2
  fi
fi

left=$((remaining - resolved_by_llm))
if (( left == 0 )); then
  is_bug_file && renumber_bugs "$OURS"
  echo "map-merge: Claude resolved $resolved_by_llm conflict(s) in $TARGET_PATH. Nothing is committed — review with \`git diff $TARGET_PATH\`, then \`git add $TARGET_PATH\` (or \`git checkout --conflict=diff3 -- $TARGET_PATH\` to get the markers back)." >&2
elif (( resolved_by_llm > 0 )); then
  echo "map-merge: Claude resolved $resolved_by_llm of $remaining conflict(s) in $TARGET_PATH; $left left as conflict markers — resolve them by hand or ask Claude Code to run the map-resolve skill, then review and \`git add $TARGET_PATH\`." >&2
else
  echo "map-merge: $left conflict(s) left in $TARGET_PATH — resolve by hand or ask Claude Code to run the map-resolve skill." >&2
fi

# Stop-for-review: a merge that needed conflict resolution never auto-commits.
finish 1
