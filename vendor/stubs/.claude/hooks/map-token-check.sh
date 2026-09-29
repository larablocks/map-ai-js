#!/usr/bin/env bash
# map-token-check.sh — Claude Code SessionStart + PostToolUse hook.
# Enforces MAP's token caps on the files that cost context: AGENTS.md and
# docs/memory/*.md. Caps are in tokens, not lines or entries, since one long
# line or entry can cost as much as many short ones. Tokens are estimated as
# bytes ÷ 4 (rounded up), the same estimate doctor.sh and Doctor.php use.
#
# SessionStart: report every capped file already over its cap, before any
# other work. PostToolUse (Edit/Write/MultiEdit): if the edit just made pushed
# a capped file over, feed that straight back to Claude in the same turn.
# AGENTS.md's Hard rules still apply to AGENTS.md itself — Claude proposes the
# cuts, the developer approves them. Memory files are Claude-maintained, so
# Claude trims those directly per each file's own header rule.
set -euo pipefail

AGENTS_MD_MAX_TOKENS=3000
GOTCHAS_MAX_TOKENS=750
SHARED_MAX_TOKENS=1500
MEMORY_TOPIC_MAX_TOKENS=2500

ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$ROOT"

# This repo is the MAP template source itself, not a consuming project.
# See .claude/rules/meta.md.
if [[ -f .claude/rules/meta.md ]]; then
  exit 0
fi

# Prints the cap for a project-relative path, or nothing if it isn't capped.
# *.example.md files are templates, not loaded context; the append-only logs
# and everything else under docs/ are deliberately uncapped.
cap_for() {
  case "$1" in
    AGENTS.md) echo "$AGENTS_MD_MAX_TOKENS" ;;
    docs/memory/*.example.md) ;;
    docs/memory/gotchas.md) echo "$GOTCHAS_MAX_TOKENS" ;;
    docs/memory/shared.md) echo "$SHARED_MAX_TOKENS" ;;
    docs/memory/*/*) ;;
    docs/memory/*.md) echo "$MEMORY_TOPIC_MAX_TOKENS" ;;
  esac
}

# Prints "path|tokens|cap" if $1 exists and is over its cap.
over_cap() {
  local path="$1" cap bytes tokens
  cap="$(cap_for "$path")"
  [[ -n "$cap" && -f "$path" ]] || return 1
  bytes="$(wc -c < "$path" | tr -d ' ')"
  tokens=$(( (bytes + 3) / 4 ))
  (( tokens > cap )) || return 1
  echo "${path}|${tokens}|${cap}"
}

INPUT="$(cat 2>/dev/null || true)"

over=()
if grep -q '"hook_event_name"[[:space:]]*:[[:space:]]*"PostToolUse"' <<< "$INPUT"; then
  EVENT="PostToolUse"
  FILE_PATH="$(sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<< "$INPUT" | head -n 1)"
  [[ -n "$FILE_PATH" ]] || exit 0
  # JSON may escape "/" as "\/" — valid, if unusual. sed, not ${//}: bash 3.2
  # (stock macOS) parses the escaped pattern differently.
  FILE_PATH="$(printf '%s' "$FILE_PATH" | sed 's#\\/#/#g')"
  # Normalise to project-relative — Claude Code passes absolute paths.
  PROJECT_ABS="$(pwd -P)"
  FILE_PATH="${FILE_PATH#"$PROJECT_ABS"/}"
  FILE_PATH="${FILE_PATH#"$ROOT"/}"
  FILE_PATH="${FILE_PATH#./}"
  if line="$(over_cap "$FILE_PATH")"; then
    over+=("$line")
  fi
else
  EVENT="SessionStart"
  shopt -s nullglob
  for path in AGENTS.md docs/memory/*.md; do
    if line="$(over_cap "$path")"; then
      over+=("$line")
    fi
  done
fi

if [[ ${#over[@]} -eq 0 ]]; then
  exit 0
fi

details=()
agents_over=0
memory_over=0
for line in "${over[@]}"; do
  IFS='|' read -r path tokens cap <<< "$line"
  details+=("${path} is ~${tokens} tokens (cap ${cap})")
  if [[ "$path" == "AGENTS.md" ]]; then agents_over=1; else memory_over=1; fi
done

joined="${details[0]}"
for detail in "${details[@]:1}"; do
  joined+="; ${detail}"
done

MESSAGE="MAP token cap (bytes ÷ 4): ${joined}. These files cost context whenever they load, so every token over the cap is paid every time."
if (( agents_over )); then
  MESSAGE+=" AGENTS.md: propose specific cuts to the developer now (move detail into the docs/ file it belongs in, tighten wording, drop rules the project no longer needs) and add nothing further until it is back under the cap."
fi
if (( memory_over )); then
  MESSAGE+=" Memory files: trim them back under the cap now, following each file's own header rule (summarise or remove resolved / least-actionable entries), and update the docs/MEMORY.md summary table."
fi

if [[ "$EVENT" == "PostToolUse" ]]; then
  cat <<JSON
{"decision":"block","reason":"${MESSAGE}"}
JSON
else
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${MESSAGE}"}}
JSON
fi
