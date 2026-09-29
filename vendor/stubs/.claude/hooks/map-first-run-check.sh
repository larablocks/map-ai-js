#!/usr/bin/env bash
# map-first-run-check.sh — Claude Code SessionStart hook.
# Detects a MAP scaffold that's been mechanically installed (map:install /
# install.sh) but never actually initialized by an AI agent, and injects a
# directive so Claude completes AGENTS.md's first-run check (Session start
# ritual, item 0) before anything else. Once real content replaces the
# placeholders below, this goes quiet on its own — there is no separate
# "initialized" flag to maintain. Mirrors the same check AGENTS.md itself
# describes, so every other AI tool gets the same behaviour from the prompt
# alone; this hook only makes it deterministic for Claude Code specifically.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$ROOT"

# This repo is the MAP template source itself, not a consuming project — its
# docs intentionally keep placeholders forever. See .claude/rules/meta.md.
if [[ -f .claude/rules/meta.md ]]; then
  exit 0
fi

# Register MAP's markdown merge driver for this clone. .gitattributes (committed)
# routes MAP docs to merge=map-ai, but the driver itself lives in .git/config,
# which never travels with a clone — so a teammate's fresh clone gets it here on
# their first Claude Code session. Silent and idempotent; mirrors lib.sh's
# MERGE_DRIVER_COMMAND.
MERGE_DRIVER_COMMAND='bash "$(git rev-parse --show-toplevel)/.map/merge.sh" %O %A %B %P'
if [[ -f .map/merge.sh ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
  [[ "$(git config --get merge.map-ai.driver 2>/dev/null)" != "$MERGE_DRIVER_COMMAND" ]]; then
  git config merge.map-ai.name "MAP structured markdown merge" 2>/dev/null || true
  git config merge.map-ai.driver "$MERGE_DRIVER_COMMAND" 2>/dev/null || true
fi

context=()

# A BUG-N used twice across docs/BUGS.md and docs/BUGS_ARCHIVE.md — left by a
# merge where one branch's new bug went into BUGS.md and the other's into the
# archive; git never runs the merge driver on a file only one side changed.
if [[ -f .map/merge.sh ]]; then
  dupes="$({ bash .map/merge.sh --check-bugs 2>/dev/null || true; } | sed -n 's/^map-merge: \(BUG-[0-9]*\) is used twice.*/\1/p' | sort -u | tr '\n' ' ')"
  if [[ -n "$dupes" ]]; then
    context+=("MAP duplicate bug numbers: ${dupes% } — each is used twice in docs/BUGS.md / docs/BUGS_ARCHIVE.md, from a merge where both branches picked the same number. Before other work: if the two entries are different bugs, run \`bash .map/merge.sh --fix-bugs\` (renumbers the copy in docs/BUGS.md) and update references to the old number in docs/qa/*.md; if they are the same bug, remove the stale entry. Tell the developer what you changed.")
  fi
fi

markers=()

if [[ -f docs/STATUS.md ]] && grep -q '\[Current milestone or phase\]' docs/STATUS.md; then
  markers+=("docs/STATUS.md")
fi
if [[ -f docs/ARCHITECTURE.md ]] && grep -q '\[Plain English description' docs/ARCHITECTURE.md; then
  markers+=("docs/ARCHITECTURE.md")
fi
if [[ -f AGENTS.md ]] && grep -q '\[PROJECT NAME\]' AGENTS.md; then
  markers+=("AGENTS.md")
fi

if [[ ${#markers[@]} -gt 0 ]]; then
  IFS=', '
  joined="${markers[*]}"
  unset IFS
  context+=("MAP first-run check: ${joined} still contain template placeholders — this project has never been initialized by an AI agent. Before doing anything else, including responding to the developer's first message, complete AGENTS.md's Session start ritual item 0 (first-run check) now.")
fi

if [[ ${#context[@]} -eq 0 ]]; then
  exit 0
fi

joined=""
for c in "${context[@]}"; do joined="${joined:+$joined\n\n}$c"; done

cat <<JSON
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${joined}"}}
JSON
