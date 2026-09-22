#!/usr/bin/env bash
# merge.sh — MAP's git merge driver for Claude-maintained markdown docs.
#
# Registered per clone as:
#   git config merge.map-ai.driver 'bash "$(git rev-parse --show-toplevel)/.map/merge.sh" %O %A %B %P'
# and wired to files by .gitattributes ("docs/BUGS.md merge=map-ai" etc.).
# install.sh / Installer / doctor --fix register it; so does the SessionStart
# hook. git config is never committed, so every clone needs registering once —
# an unregistered clone just falls back to git's normal text merge.
#
# Contract: git passes base (%O), ours (%A), theirs (%B) and the path (%P).
# The result must be written to %A; exit 0 = resolved, non-zero = conflict.
#
# Strategy — deterministic only, no LLM, never worse than plain git:
# 1. Run git's own 3-way merge. Clean → that's the result, exactly as git
#    would have produced it (plus BUG-N de-duplication for the bug files).
#    That result, conflict markers and all, is written to %A immediately, so
#    any failure below still leaves git's normal conflict output behind.
# 2. On conflict, retry as a structured merge: split each side into blocks at
#    markdown headings (ignoring headings inside code fences and HTML
#    comments), 3-way merge block by block, and inside a still-conflicting
#    block resolve only these hunk shapes:
#      - table rows only       → 3-way merge rows keyed by their first cell
#      - nothing in the base   → both sides only inserted: keep ours, then theirs
#      - "Last updated" lines  → keep the newest date
#    Anything else (both sides rewrote the same prose, a block edited on one
#    side and deleted on the other) is a real conflict: exit 1 and leave
#    git's markers for a human — or a later LLM pass — to resolve.
# 3. For docs/BUGS.md and docs/BUGS_ARCHIVE.md, renumber any BUG-N heading
#    that now appears twice (two branches picked the same next number): the
#    entry that already existed on our side keeps it, the other gets the next
#    free number across both bug files on both branches.
#
# Written for bash 3.2 + POSIX awk — git runs this on every merge, including
# on stock macOS.

BASE="$1"
OURS="$2"
THEIRS="$3"
TARGET_PATH="${4:-$2}"

MARKER_SIZE=7

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t map-merge)"
trap 'rm -rf "$TMP"' EXIT

cp "$OURS" "$TMP/ours"
cp "$BASE" "$TMP/base"
cp "$THEIRS" "$TMP/theirs"

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

renumber_bugs() {
  local file="$1" extra="$TMP/bug-numbers" ref f
  : > "$extra"
  for f in docs/BUGS.md docs/BUGS_ARCHIVE.md; do
    [[ -f "$f" ]] && cat "$f" >> "$extra"
    for ref in HEAD MERGE_HEAD; do
      git show "$ref:$f" >> "$extra" 2>/dev/null || true
    done
  done
  cat "$TMP/ours" "$TMP/theirs" "$TMP/base" >> "$extra"
  cp "$file" "$TMP/to-count" # distinct name, so awk can tell the counting pass from the rewrite pass

  awk -v path="$TARGET_PATH" '
    function in_code(line) {
      if (line ~ /^[[:space:]]*(```|~~~)/) { fence = !fence; return 1 }
      if (fence) return 1
      if (comment) { if (line ~ /-->/) comment = 0; return 1 }
      if (line ~ /<!--/ && line !~ /-->/) { comment = 1; return 1 }
      return 0
    }
    function bug_number(line) {
      if (match(line, /^#+[[:space:]]+BUG-[0-9]+/)) {
        s = substr(line, 1, RLENGTH); sub(/^#+[[:space:]]+BUG-/, "", s); return s + 0
      }
      return -1
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
        if (b >= 0 && count[b] > 1) {
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
}

# ---------------------------------------------------------------------------
# Step 1 — git's own merge: the fast path and the fallback.
# ---------------------------------------------------------------------------
git merge-file -p --diff3 --marker-size="$MARKER_SIZE" \
  -L ours -L base -L theirs \
  "$TMP/ours" "$TMP/base" "$TMP/theirs" > "$TMP/standard"
STATUS=$?

if (( STATUS < 0 || STATUS > 127 )); then
  exit 1 # git merge-file itself failed — leave %A untouched, git reports a conflict
fi

cp "$TMP/standard" "$OURS"

if (( STATUS == 0 )); then
  is_bug_file && renumber_bugs "$OURS"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 2 — structured merge.
# ---------------------------------------------------------------------------

# Splits $1 into blocks under $2/: one file per block (0001, 0002, ...) and an
# index of "id<TAB>key". A block is a heading line plus everything up to the
# next heading; the key is the heading path ("## Open bugs > ### BUG-3 — x"),
# with "#n" appended to repeated paths. Text before the first heading is the
# "(preamble)" block.
split_blocks() {
  mkdir -p "$2"
  awk -v dir="$2" '
    function start_block(key) {
      if (out != "") close(out)
      seen[key]++
      if (seen[key] > 1) key = key "#" seen[key]
      id++
      out = sprintf("%s/%04d", dir, id)
      printf "" > out
      printf "%04d\t%s\n", id, key > (dir "/index")
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
    }
    END { if (out != "") close(out); close(dir "/index") }
  ' "$1"
}

block_id() { # $1 = side dir, $2 = key → prints the block id or nothing
  K="$2" awk -F'\t' '$2 == ENVIRON["K"] { print $1; exit }' "$1/index"
}

# Resolves the conflict hunks of a --diff3 merge-file output on stdin, or
# exits 1 if any hunk isn't one of the safe shapes.
resolve_hunks() {
  awk -v size="$MARKER_SIZE" '
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
      # Deleted on one side is only safe if the other side left the row unchanged.
      for (k in rb) {
        if ((k in ro) && !(k in rt) && ro[k] != rb[k]) return 0
        if ((k in rt) && !(k in ro) && rt[k] != rb[k]) return 0
      }
      out_n = 0
      for (i = 1; i <= n; i++) {
        k = order[i]; ino = (k in ro); inb = (k in rb); int_ = (k in rt)
        if (ino && int_) {
          if (ro[k] == rt[k]) out[++out_n] = ro[k]
          else if (inb && ro[k] == rb[k]) out[++out_n] = rt[k]
          else if (inb && rt[k] == rb[k]) out[++out_n] = ro[k]
          else return 0 # both changed (or both added) this row differently
        } else if (ino) {
          if (!inb) out[++out_n] = ro[k] # added on our side; else deleted by them, unchanged here
        } else if (int_) {
          if (!inb) out[++out_n] = rt[k]
        }
      }
      for (i = 1; i <= out_n; i++) print out[i]
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
      if (all_rows(o, no) && all_rows(b, nb) && all_rows(t, nt)) return merge_rows()
      return 0
    }

    BEGIN { start = marker("<") " "; mid = marker("|") " "; sep = marker("="); stop = marker(">") " "; state = 0 }
    state == 0 && index($0, start) == 1 { state = 1; no = nb = nt = 0; next }
    state == 1 && index($0, mid) == 1 { state = 2; next }
    state == 2 && $0 == sep { state = 3; next }
    state == 3 && index($0, stop) == 1 { if (!resolve()) { failed = 1; exit 1 }; state = 0; next }
    state == 1 { o[++no] = $0; next }
    state == 2 { b[++nb] = $0; next }
    state == 3 { t[++nt] = $0; next }
    { print }
    END { if (failed || state != 0) exit 1 }
  '
}

split_blocks "$TMP/ours" "$TMP/A"
split_blocks "$TMP/base" "$TMP/O"
split_blocks "$TMP/theirs" "$TMP/B"
mkdir -p "$TMP/R"
: > "$TMP/R/index"
: > "$TMP/empty"

conflict=0
n=0
key_n=0
while IFS= read -r key; do
  key_n=$((key_n + 1))
  a="$(block_id "$TMP/A" "$key")"
  o="$(block_id "$TMP/O" "$key")"
  b="$(block_id "$TMP/B" "$key")"
  fa="$TMP/A/$a"; fo="$TMP/O/$o"; fb="$TMP/B/$b"
  [[ -n "$a" ]] || fa="$TMP/empty"
  [[ -n "$o" ]] || fo="$TMP/empty"
  [[ -n "$b" ]] || fb="$TMP/empty"

  result=""
  if [[ -z "$a" && -z "$b" ]]; then
    continue # deleted on both sides
  elif [[ -n "$a" && -n "$b" ]] && cmp -s "$fa" "$fb"; then
    result="$fa"
  elif [[ -n "$o" ]]; then
    if [[ -z "$a" ]]; then
      cmp -s "$fb" "$fo" && continue # we deleted it, they didn't touch it
      conflict=1; break                # we deleted it, they edited it
    elif [[ -z "$b" ]]; then
      cmp -s "$fa" "$fo" && continue
      conflict=1; break
    elif cmp -s "$fa" "$fo"; then
      result="$fb"
    elif cmp -s "$fb" "$fo"; then
      result="$fa"
    fi
  elif [[ -z "$b" ]]; then
    result="$fa" # new on our side only
  elif [[ -z "$a" ]]; then
    result="$fb" # new on their side only
  else
    # Both sides added a block with the same heading (e.g. two sessions logging
    # the same date) — keep both entries whole rather than interleave them.
    cat "$fa" "$fb" > "$TMP/both-added"
    result="$TMP/both-added.$key_n"
    mv "$TMP/both-added" "$result"
  fi

  n=$((n + 1))
  id="$(printf '%04d' "$n")"
  if [[ -n "$result" ]]; then
    cp "$result" "$TMP/R/$id"
  else
    # Changed on both sides (or added on both sides with the same heading).
    git merge-file -p --diff3 --marker-size="$MARKER_SIZE" -L ours -L base -L theirs \
      "$fa" "$fo" "$fb" > "$TMP/R/$id.merged"
    st=$?
    if (( st == 0 )); then
      mv "$TMP/R/$id.merged" "$TMP/R/$id"
    elif (( st > 0 && st < 128 )) && resolve_hunks < "$TMP/R/$id.merged" > "$TMP/R/$id"; then
      rm -f "$TMP/R/$id.merged"
    else
      conflict=1; break
    fi
  fi
  printf '%s\t%s\n' "$id" "$key" >> "$TMP/R/index"
done < <(cut -f2 "$TMP/A/index" "$TMP/O/index" "$TMP/B/index" | awk '!seen[$0]++')

if (( conflict )); then
  exit 1 # git's own conflict output is already in %A
fi

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
  END { for (i = 1; i <= n; i++) print res[out[i]] }
' "$TMP/R/index" "$TMP/order-a" "$TMP/theirs-keys" "$TMP/order-b" > "$TMP/order"

: > "$TMP/result"
while IFS= read -r id; do
  cat "$TMP/R/$id" >> "$TMP/result"
done < "$TMP/order"

# Belt and braces: never hand back anything that still has conflict markers.
if grep -q "^<<<<<<< \|^>>>>>>> " "$TMP/result"; then
  exit 1
fi

cp "$TMP/result" "$OURS"
is_bug_file && renumber_bugs "$OURS"
exit 0
