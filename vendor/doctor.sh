#!/usr/bin/env bash
# doctor.sh — report on and repair drift between an installed MAP project and
# the current template stubs, without needing a PHP/Composer runtime at all.
# Mirrors src/Doctor.php's check()/fix() split and the same hard rule: --fix
# only ever adds content (missing files, missing gitignore/gitattributes
# entries, a safe copilot-instructions.md regeneration) — it never removes or
# rewrites a line a developer could have written. Anything else is reported
# only, for a human to merge by hand.
# Usage: ./doctor.sh <target-project-path> [--fix]
# Run from the map-ai repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TARGET=""
FIX=0
INTERACTIVE=0

for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    --interactive) INTERACTIVE=1 ;;
    -*) echo "Unknown option: $arg"; exit 1 ;;
    *) TARGET="$arg" ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target-project-path> [--fix | --interactive]"
  echo ""
  echo "  --fix          Apply only the additive, zero-judgment repairs: missing"
  echo "                 files, missing .gitignore/.gitattributes entries, and a"
  echo "                 .github/copilot-instructions.md regeneration — but only"
  echo "                 when regenerating it would strictly add content, never"
  echo "                 drop a line that's already there. Applied unattended,"
  echo "                 no prompts. Everything else is reported only."
  echo "  --interactive  Same fixable set as --fix, but reviewed one file at a"
  echo "                 time: missing files/gitignore/gitattributes entries are"
  echo "                 still added unattended (nothing to review — there's no"
  echo "                 existing content they could touch), then each scaffold"
  echo "                 file with new template content, and the"
  echo "                 copilot-instructions.md regeneration, are shown and"
  echo "                 confirmed individually before being written."
  exit 1
fi

if [[ "$FIX" -eq 1 && "$INTERACTIVE" -eq 1 ]]; then
  echo "Error: --fix and --interactive are mutually exclusive — pick one."
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: '$TARGET' is not a directory"
  exit 1
fi

AGENTS_MD_MAX_LINES=100
FIXABLE_FOUND=0
REVIEW_FOUND=0

COPILOT_HEADER='# copilot-instructions.md
_GitHub Copilot entry point — MAP v1.0 convention_
_Copilot does not support @file imports — AGENTS.md content is inlined below._
_When AGENTS.md, .claude/rules/security.md, or .claude/rules/testing.md changes, update this file to match — the Security/Testing rules sections below are inlined copies of those two files._'

# ---------------------------------------------------------------------------
# .github/copilot-instructions.md regeneration — mirrors Doctor.php exactly:
# AGENTS.md verbatim (minus @-prefixes, which Copilot doesn't resolve) plus
# security.md's and testing.md's bullet lines with their headers stripped.
# ---------------------------------------------------------------------------

# Strips the @ from @docs/... and @CLAUDE.local.md references — Copilot
# doesn't support @file imports, so those refs would just be dead text to it.
strip_at_refs() {
  sed -E 's/@(docs\/|CLAUDE\.local\.md)/\1/g' "$1"
}

# Extracts top-level "- " bullets and their indented continuation lines from
# a rules file, dropping its H1 title and ## subheadings. Once a bullet has
# been seen, any later indented non-blank line is treated as a continuation
# of it — this deliberately mirrors Doctor.php's extractBullets() line for
# line, including its looseness (an indented line anywhere after the first
# bullet counts), so both implementations produce identical output on the
# same input.
extract_bullets() {
  awk '
    /^-[ \t]/ { print; bullets=1; next }
    bullets && /^[ \t]+[^ \t]/ { print; next }
  ' "$1"
}

# Prints the canonical copilot-instructions.md content for $1 (a project
# root) to stdout, or returns 1 if any of the three source files is missing —
# there is nothing to regenerate from.
regenerate_copilot() {
  local project="$1"
  local agents="$project/AGENTS.md"
  local security="$project/.claude/rules/security.md"
  local testing="$project/.claude/rules/testing.md"

  if [[ ! -f "$agents" || ! -f "$security" || ! -f "$testing" ]]; then
    return 1
  fi

  local agents_body security_bullets testing_bullets
  agents_body="$(strip_at_refs "$agents")"
  security_bullets="$(extract_bullets "$security")"
  testing_bullets="$(extract_bullets "$testing")"

  printf '%s\n\n---\n\n%s\n\n## Security rules\n_Copilot does not auto-load .claude/rules/security.md — rules are inlined here_\n%s\n\n## Testing rules\n_Copilot does not auto-load .claude/rules/testing.md — rules are inlined here_\n%s\n' \
    "$COPILOT_HEADER" "$agents_body" "$security_bullets" "$testing_bullets"
}

# True only if every non-blank line of $1 (rtrimmed) appears verbatim
# somewhere in $2 (also rtrimmed) — the safety net that decides whether
# regenerating copilot-instructions.md can only add/reorder content, or
# would drop something (a hand edit, or content since removed upstream).
copilot_is_superset() {
  local current_trimmed regenerated_trimmed line
  current_trimmed="$(printf '%s\n' "$1" | sed -E 's/[[:space:]]+$//')"
  regenerated_trimmed="$(printf '%s\n' "$2" | sed -E 's/[[:space:]]+$//')"

  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    grep -qxF -- "$line" <<< "$regenerated_trimmed" || return 1
  done <<< "$current_trimmed"

  return 0
}

# Regenerates .github/copilot-instructions.md in $TARGET only when doing so
# is superset-safe. Prints nothing; returns 1 if there was nothing to do
# (in sync, unsafe, or source files missing) so callers can branch on it.
fix_copilot_sync() {
  local copilot_path="$TARGET/.github/copilot-instructions.md"
  local regenerated current

  regenerated="$(regenerate_copilot "$TARGET")" || return 1

  current=""
  [[ -f "$copilot_path" ]] && current="$(cat "$copilot_path")"

  if [[ "$(printf '%s' "$current" | tr -d '\r')" == "$(printf '%s' "$regenerated" | tr -d '\r')" ]]; then
    return 1
  fi

  copilot_is_superset "$current" "$regenerated" || return 1

  mkdir -p "$(dirname "$copilot_path")"
  printf '%s\n' "$regenerated" > "$copilot_path"
  return 0
}

# ---------------------------------------------------------------------------
# SCAFFOLD_FILES patching — mirrors Doctor.php's diffAgainstStub()/patchScaffoldFile()
# exactly: `diff --unified=0 target stub`, and a hunk with oldCount=0 is a pure
# addition (stub has new lines with nothing removed from target — safe to splice
# in); a hunk with oldCount>0 and newCount>0 is a modification (needs a human).
# Content the target has that the stub doesn't produces neither and is left alone.
# ---------------------------------------------------------------------------

# True if every non-blank line in $1 is a full-line italic note (`_like this_`).
is_all_italic_notes() {
  local block="$1" line
  [[ -z "$block" ]] && return 1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^_.*_$ ]] || return 1
  done <<< "$block"
  return 0
}

# True if $1 (a multi-line block) is a complete HTML comment: first line starts
# with <!-- and the last non-blank line ends with -->.
is_html_comment_block() {
  local block="$1"
  [[ -z "$block" ]] && return 1
  local first last
  first="$(head -n1 <<< "$block")"
  last="$(printf '%s' "$block" | awk 'NF{l=$0} END{print l}')"
  [[ "$first" == '<!--'* && "$last" == *'-->' ]]
}

# Every stub file uses full-line italic notes and HTML comments for its own
# instructional/governance text, never for real content (bug entries, schema
# tables, decision records). A modification hunk is safe to auto-apply only
# when both sides are entirely one of those two conventions.
is_safe_note_modification() {
  local removed="$1" added="$2"
  [[ -z "$removed" || -z "$added" ]] && return 1

  if is_all_italic_notes "$removed" && is_all_italic_notes "$added"; then
    return 0
  fi

  is_html_comment_block "$removed" && is_html_comment_block "$added"
}

# A note/comment can look purely instructional by shape while actually being a
# template with a placeholder a project has since filled in with real data — e.g.
# "_Last updated: YYYY-MM-DD by Claude_" becomes "_Last updated: 2026-07-10 by
# Claude_". Both are still full-line italic notes, but replacing the second with
# the first would silently discard a real date. Final guard, applied regardless
# of which shape check matched: true if $2 (stub/added) names a [bracketed]
# placeholder or the literal YYYY-MM-DD that doesn't appear verbatim in $1
# (target/removed) — meaning the target has already filled it in.
stub_placeholder_was_filled() {
  local removed_text="$1" added_text="$2"
  local placeholder
  while IFS= read -r placeholder; do
    [[ -z "$placeholder" ]] && continue
    [[ "$removed_text" == *"$placeholder"* ]] || return 0
  done < <(grep -oE '\[[^][]*\]|YYYY-MM-DD' <<< "$added_text")
  return 1
}

# Prints everything before a whitespace-preceded # to stdout and returns 0, or
# returns 1 if $1 has no such trailing comment. `#` has no reserved meaning in
# prose, so callers must scope this to fenced code lines themselves.
inline_comment_prefix() {
  local line="$1"
  line="${line%"${line##*[![:space:]]}"}" # rtrim
  if [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# Safe only when both lines have a trailing "  # comment" and the real content
# before it is byte-identical — i.e. only the comment changed.
is_safe_inline_comment_modification() {
  local removed_prefix added_prefix
  removed_prefix="$(inline_comment_prefix "$1")" || return 1
  added_prefix="$(inline_comment_prefix "$2")" || return 1
  [[ "$removed_prefix" == "$added_prefix" ]]
}

# Sets FENCE_LINES to a newline-separated list of 1-indexed line numbers of $1
# that fall inside a ``` fence.
compute_fence_lines() {
  local file="$1"
  FENCE_LINES=$'\n'
  local in_fence=0 lineno=0 line
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    if [[ "$line" == '```'* ]]; then
      in_fence=$((1 - in_fence))
      continue
    fi
    [[ "$in_fence" -eq 1 ]] && FENCE_LINES+="${lineno}"$'\n'
  done < "$file"
}

is_fenced_line() {
  [[ "$FENCE_LINES" == *$'\n'"$1"$'\n'* ]]
}

# Sets SCAFFOLD_HAS_ADDITIONS and SCAFFOLD_HAS_MODIFICATIONS (0/1) for $1 vs $2.
# ADDITIONS covers pure insertions and safe note/comment replacements — all
# auto-appliable; MODIFICATIONS means real content changed and needs a human.
classify_scaffold_diff() {
  local target="$1" stub="$2"
  SCAFFOLD_HAS_ADDITIONS=0
  SCAFFOLD_HAS_MODIFICATIONS=0
  [[ -f "$target" && -f "$stub" ]] || return 1

  compute_fence_lines "$target"

  local diff_output old_start old_count new_count removed added in_hunk=0
  diff_output="$(diff --unified=0 "$target" "$stub" 2>/dev/null || true)"

  eval_hunk() {
    [[ "$in_hunk" -ne 1 ]] && return
    if [[ "$old_count" -eq 0 && "$new_count" -gt 0 ]]; then
      SCAFFOLD_HAS_ADDITIONS=1
    elif [[ "$old_count" -gt 0 && "$new_count" -gt 0 ]]; then
      local is_inline_comment=1
      if [[ "$old_count" -eq 1 && "$new_count" -eq 1 ]] && is_fenced_line "$old_start"; then
        is_safe_inline_comment_modification "$removed" "$added" && is_inline_comment=0
      fi
      local looks_safe=1
      is_safe_note_modification "$removed" "$added" && looks_safe=0
      [[ "$is_inline_comment" -eq 0 ]] && looks_safe=0
      if [[ "$looks_safe" -eq 0 ]] && ! stub_placeholder_was_filled "$removed" "$added"; then
        SCAFFOLD_HAS_ADDITIONS=1
      else
        SCAFFOLD_HAS_MODIFICATIONS=1
      fi
    fi
  }

  local next_old_start next_old_count next_new_count
  while IFS= read -r line; do
    if [[ "$line" =~ ^@@\ -([0-9]+)(,([0-9]+))?\ \+[0-9]+(,([0-9]+))?\ @@ ]]; then
      # Capture this header's groups before eval_hunk runs — it calls
      # is_safe_note_modification, whose own =~ matches overwrite BASH_REMATCH.
      next_old_start="${BASH_REMATCH[1]}"
      next_old_count="${BASH_REMATCH[3]:-1}"
      next_new_count="${BASH_REMATCH[5]:-1}"
      eval_hunk
      old_start="$next_old_start"
      old_count="$next_old_count"
      new_count="$next_new_count"
      removed=""
      added=""
      in_hunk=1
      continue
    fi
    if [[ "$in_hunk" -eq 1 ]]; then
      if [[ "$line" == '+'* ]]; then
        added+="${line:1}"$'\n'
      elif [[ "$line" == '-'* ]]; then
        removed+="${line:1}"$'\n'
      fi
    fi
  done <<< "$diff_output"
  eval_hunk
}

# The same safe-to-apply hunks patch_scaffold_file() would use for $1 (target)
# vs $2 (stub), computed into the FH_STARTS/FH_COUNTS/FH_BODIES globals without
# applying them — for a caller (e.g. --interactive) that wants to preview and
# confirm before writing. Returns 1 (and leaves the FH_* arrays empty) if
# there's nothing fixable.
compute_fixable_hunks() {
  local target="$1" stub="$2"
  FH_STARTS=()
  FH_COUNTS=()
  FH_BODIES=()
  [[ -f "$target" && -f "$stub" ]] || return 1

  compute_fence_lines "$target"

  local diff_output
  diff_output="$(diff --unified=0 "$target" "$stub" 2>/dev/null || true)"
  [[ -z "$diff_output" ]] && return 1

  local old_start="" old_count=1 new_count=1 removed="" added="" in_hunk=0

  save_hunk() {
    [[ "$in_hunk" -ne 1 ]] && return
    if [[ "$old_count" -eq 0 && "$new_count" -gt 0 ]]; then
      FH_STARTS+=("$old_start")
      FH_COUNTS+=(0)
      FH_BODIES+=("$added")
      return
    fi
    [[ "$old_count" -eq 0 || "$new_count" -eq 0 ]] && return

    local safe=1
    is_safe_note_modification "$removed" "$added" && safe=0
    if [[ "$safe" -ne 0 && "$old_count" -eq 1 && "$new_count" -eq 1 ]] && is_fenced_line "$old_start"; then
      is_safe_inline_comment_modification "$removed" "$added" && safe=0
    fi
    if [[ "$safe" -eq 0 ]] && stub_placeholder_was_filled "$removed" "$added"; then
      safe=1
    fi

    if [[ "$safe" -eq 0 ]]; then
      FH_STARTS+=("$((old_start - 1))")
      FH_COUNTS+=("$old_count")
      FH_BODIES+=("$added")
    fi
  }

  local next_old_start next_old_count next_new_count
  while IFS= read -r line; do
    if [[ "$line" =~ ^@@\ -([0-9]+)(,([0-9]+))?\ \+[0-9]+(,([0-9]+))?\ @@ ]]; then
      # Capture this header's groups before save_hunk runs — it calls
      # is_safe_note_modification, whose own =~ matches overwrite BASH_REMATCH.
      next_old_start="${BASH_REMATCH[1]}"
      next_old_count="${BASH_REMATCH[3]:-1}"
      next_new_count="${BASH_REMATCH[5]:-1}"
      save_hunk
      old_start="$next_old_start"
      old_count="$next_old_count"
      new_count="$next_new_count"
      removed=""
      added=""
      in_hunk=1
      continue
    fi
    if [[ "$in_hunk" -eq 1 ]]; then
      if [[ "$line" == '+'* ]]; then
        added+="${line:1}"$'\n'
      elif [[ "$line" == '-'* ]]; then
        removed+="${line:1}"$'\n'
      fi
    fi
  done <<< "$diff_output"
  save_hunk

  [[ ${#FH_STARTS[@]} -eq 0 ]] && return 1
  return 0
}

# Splices the hunks currently held in FH_STARTS/FH_COUNTS/FH_BODIES (as left
# by compute_fixable_hunks(), a subset is fine — see render_fixable_hunks()'s
# sibling filtering pattern) into $1 in place. Does not re-derive or
# re-validate safety.
apply_fixable_hunks() {
  local target="$1"

  # Order hunks by start descending (bottom-to-top) so an earlier splice
  # doesn't shift the line numbers a later one depends on. Insertion sort —
  # the hunk count per file is always small.
  local order=()
  local i j key
  for ((i = 0; i < ${#FH_STARTS[@]}; i++)); do order+=("$i"); done
  for ((i = 1; i < ${#order[@]}; i++)); do
    key=${order[i]}
    j=$((i - 1))
    while ((j >= 0)) && ((FH_STARTS[${order[j]}] < FH_STARTS[key])); do
      order[j + 1]=${order[j]}
      ((j--))
    done
    order[j + 1]=$key
  done

  local file_lines=()
  mapfile -t file_lines < "$target"

  local idx start cnt add_body add_lines
  for idx in "${order[@]}"; do
    start=${FH_STARTS[$idx]}
    cnt=${FH_COUNTS[$idx]}
    add_body=${FH_BODIES[$idx]}
    add_lines=()
    mapfile -t add_lines <<< "$add_body"
    if [[ ${#add_lines[@]} -gt 0 && -z "${add_lines[-1]}" ]]; then
      unset 'add_lines[-1]'
    fi
    file_lines=("${file_lines[@]:0:$start}" "${add_lines[@]}" "${file_lines[@]:$((start + cnt))}")
  done

  printf '%s\n' "${file_lines[@]}" > "$target"
}

# Splices only the appliable hunks from $1 (target) vs $2 (stub) into $1, in
# place. Returns 1 (no-op) if there's nothing to patch.
patch_scaffold_file() {
  local target="$1" stub="$2"
  compute_fixable_hunks "$target" "$stub" || return 1
  apply_fixable_hunks "$target"
  return 0
}

# Prints the hunks currently held in FH_STARTS/FH_COUNTS/FH_BODIES as a
# unified-diff-style preview (added lines only, prefixed with "+") for a
# human to review before confirming --interactive should apply them.
render_fixable_hunks() {
  local order=()
  local i j key
  for ((i = 0; i < ${#FH_STARTS[@]}; i++)); do order+=("$i"); done
  for ((i = 1; i < ${#order[@]}; i++)); do
    key=${order[i]}
    j=$((i - 1))
    while ((j >= 0)) && ((FH_STARTS[${order[j]}] > FH_STARTS[key])); do
      order[j + 1]=${order[j]}
      ((j--))
    done
    order[j + 1]=$key
  done

  local idx add_body add_lines line
  for idx in "${order[@]}"; do
    add_body=${FH_BODIES[$idx]}
    add_lines=()
    mapfile -t add_lines <<< "$add_body"
    if [[ ${#add_lines[@]} -gt 0 && -z "${add_lines[-1]}" ]]; then
      unset 'add_lines[-1]'
    fi
    for line in "${add_lines[@]}"; do
      echo "    + $line"
    done
    echo "    ..."
  done
}

# Prompts "$1 [Y/n] " and returns 0 for anything but an explicit n/no
# (default-yes, matching Illuminate\Console\Command::confirm(..., true)).
confirm_prompt() {
  local reply
  read -r -p "$1 [Y/n] " reply || reply="n"
  case "$reply" in
    [nN] | [nN][oO]) return 1 ;;
    *) return 0 ;;
  esac
}

# ---------------------------------------------------------------------------
# Apply fixes first (if --fix), then always run the check pass below to
# report what's left — including confirmation that the fixable items are
# gone, and anything that still needs a human.
# ---------------------------------------------------------------------------
if [[ "$FIX" -eq 1 ]]; then
  echo "Applying fixes..."
  echo ""
  # Same guarantee as calling this directly without --force: MANAGED_FILES
  # re-sync (pure template, nothing to clobber), missing SCAFFOLD_FILES are
  # added, existing ones are left untouched.
  bash "$SCRIPT_DIR/install.sh" "$TARGET"
  echo ""
  # Patch in new template content before regenerating copilot-instructions.md, so
  # the regeneration reflects whatever AGENTS.md just picked up.
  for file in "${SCAFFOLD_FILES[@]}"; do
    [[ "$file" == ".github/copilot-instructions.md" ]] && continue
    if patch_scaffold_file "$TARGET/$file" "$SCRIPT_DIR/stubs/$file"; then
      echo "  [FIXED]  $file patched with new template content"
    fi
  done
  if fix_copilot_sync; then
    echo "  [FIXED]  .github/copilot-instructions.md regenerated"
  fi
  echo ""
fi

# ---------------------------------------------------------------------------
# --interactive: same fixable set as --fix, but confirmed one file at a time.
# Missing files/gitignore/gitattributes entries have no existing content they
# could touch, so those are still applied unattended via install.sh — only
# modifications to a file that already exists get a confirm gate, one prompt
# per file showing all of that file's hunks together (not one prompt per
# hunk), matching map-ai-laravel's InstallCommand review UX.
# ---------------------------------------------------------------------------
if [[ "$INTERACTIVE" -eq 1 ]]; then
  echo "Applying additive repairs..."
  echo ""
  bash "$SCRIPT_DIR/install.sh" "$TARGET"
  echo ""

  for file in "${SCAFFOLD_FILES[@]}"; do
    [[ "$file" == ".github/copilot-instructions.md" ]] && continue
    compute_fixable_hunks "$TARGET/$file" "$SCRIPT_DIR/stubs/$file" || continue
    echo "$file has new template content:"
    render_fixable_hunks
    if confirm_prompt "Apply these changes to $file?"; then
      apply_fixable_hunks "$TARGET/$file"
      echo "  [FIXED]  $file patched with new template content"
    else
      echo "  [SKIPPED] $file left as-is"
    fi
    echo ""
  done

  COPILOT_REGENERATED_PREVIEW=""
  if COPILOT_REGENERATED_PREVIEW="$(regenerate_copilot "$TARGET")"; then
    COPILOT_PATH_PREVIEW="$TARGET/.github/copilot-instructions.md"
    COPILOT_CURRENT_PREVIEW=""
    [[ -f "$COPILOT_PATH_PREVIEW" ]] && COPILOT_CURRENT_PREVIEW="$(cat "$COPILOT_PATH_PREVIEW")"

    if [[ "$(printf '%s' "$COPILOT_CURRENT_PREVIEW" | tr -d '\r')" != "$(printf '%s' "$COPILOT_REGENERATED_PREVIEW" | tr -d '\r')" ]] \
      && copilot_is_superset "$COPILOT_CURRENT_PREVIEW" "$COPILOT_REGENERATED_PREVIEW"; then
      echo ".github/copilot-instructions.md is out of sync (safe to regenerate — adds only):"
      diff <(printf '%s\n' "$COPILOT_CURRENT_PREVIEW") <(printf '%s\n' "$COPILOT_REGENERATED_PREVIEW") \
        | grep '^>' | sed 's/^> /    + /' || true
      echo ""
      if confirm_prompt "Regenerate .github/copilot-instructions.md?"; then
        fix_copilot_sync
        echo "  [FIXED]  .github/copilot-instructions.md regenerated"
      else
        echo "  [SKIPPED] .github/copilot-instructions.md left as-is"
      fi
      echo ""
    fi
  fi
fi

echo "Checking MAP install at: $TARGET"
echo ""

for file in "${MANAGED_FILES[@]}" "${SCAFFOLD_FILES[@]}"; do
  src="$SCRIPT_DIR/stubs/$file"
  dst="$TARGET/$file"
  [[ -f "$src" ]] || continue
  if [[ ! -f "$dst" ]]; then
    echo "  [FIXABLE]  missing-file             $file"
    ((FIXABLE_FOUND++)) || true
  fi
done

for file in "${SCAFFOLD_FILES[@]}"; do
  [[ "$file" == ".github/copilot-instructions.md" ]] && continue
  src="$SCRIPT_DIR/stubs/$file"
  dst="$TARGET/$file"
  classify_scaffold_diff "$dst" "$src" || continue
  if [[ "$SCAFFOLD_HAS_ADDITIONS" -eq 1 ]]; then
    echo "  [FIXABLE]  missing-template-updates $file  (has new template content — safe to patch in)"
    ((FIXABLE_FOUND++)) || true
  fi
  if [[ "$SCAFFOLD_HAS_MODIFICATIONS" -eq 1 ]]; then
    echo "  [REVIEW]   outdated-scaffold-file  $file  (differs from the current stub — merge by hand)"
    ((REVIEW_FOUND++)) || true
  fi
done

AGENTS_PATH="$TARGET/AGENTS.md"
if [[ -f "$AGENTS_PATH" ]]; then
  AGENTS_LINE_COUNT="$(wc -l < "$AGENTS_PATH" | tr -d ' ')"
  if (( AGENTS_LINE_COUNT > AGENTS_MD_MAX_LINES )); then
    echo "  [REVIEW]   agents-md-too-long      AGENTS.md ($AGENTS_LINE_COUNT lines, over the $AGENTS_MD_MAX_LINES line cap — trim by hand)"
    ((REVIEW_FOUND++)) || true
  fi
fi

if COPILOT_REGENERATED="$(regenerate_copilot "$TARGET")"; then
  COPILOT_PATH="$TARGET/.github/copilot-instructions.md"
  COPILOT_CURRENT=""
  [[ -f "$COPILOT_PATH" ]] && COPILOT_CURRENT="$(cat "$COPILOT_PATH")"

  if [[ "$(printf '%s' "$COPILOT_CURRENT" | tr -d '\r')" != "$(printf '%s' "$COPILOT_REGENERATED" | tr -d '\r')" ]]; then
    if copilot_is_superset "$COPILOT_CURRENT" "$COPILOT_REGENERATED"; then
      echo "  [FIXABLE]  copilot-out-of-sync      .github/copilot-instructions.md  (safe to regenerate)"
      ((FIXABLE_FOUND++)) || true
    else
      echo "  [REVIEW]   copilot-out-of-sync      .github/copilot-instructions.md  (regenerating would drop a line currently in the file — review first)"
      ((REVIEW_FOUND++)) || true
    fi
  fi
fi

echo ""

if [[ "$FIXABLE_FOUND" -eq 0 && "$REVIEW_FOUND" -eq 0 ]]; then
  echo "Clean — nothing to report."
  exit 0
fi

echo "Found $FIXABLE_FOUND fixable and $REVIEW_FOUND needing manual review."

if [[ "$FIX" -eq 0 && "$FIXABLE_FOUND" -gt 0 ]]; then
  echo "Run with --fix to apply the fixable ones."
fi

if [[ "$FIX" -eq 1 ]]; then
  # After fixing, only unresolved review items should fail the run.
  [[ "$REVIEW_FOUND" -gt 0 ]] && exit 1
  exit 0
fi

# Report-only mode: any drift at all should be visible to CI.
exit 1
