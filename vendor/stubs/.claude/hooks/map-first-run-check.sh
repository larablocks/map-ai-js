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

if [[ ${#markers[@]} -eq 0 ]]; then
  exit 0
fi

IFS=', '
joined="${markers[*]}"
unset IFS

cat <<JSON
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"MAP first-run check: ${joined} still contain template placeholders — this project has never been initialized by an AI agent. Before doing anything else, including responding to the developer's first message, complete AGENTS.md's Session start ritual item 0 (first-run check) now."}}
JSON
