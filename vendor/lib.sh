#!/usr/bin/env bash
# lib.sh — shared file lists and helpers for install.sh and doctor.sh.
# Sourced, not executed directly. The caller sets SCRIPT_DIR before sourcing
# this file; nothing in here depends on the caller's other state.

# ---------------------------------------------------------------------------
# Framework-owned files — always kept in sync with the package stubs, never
# backed up. meta.md is intentionally excluded — it only applies to this
# template repo itself.
# ---------------------------------------------------------------------------
MANAGED_FILES=(
  .claude/hooks/map-token-check.sh
  .claude/hooks/map-first-run-check.sh
  .cursor/rules/agents.mdc
  .map/merge.sh
  docs/MEMORY.example.md
  docs/agents/agent.example.md
  docs/api/api.example.md
  docs/architecture/architecture.example.md
  docs/integrations/integration.example.md
  docs/qa/qa.example.md
  docs/memory/agents.example.md
  docs/memory/database.example.md
  docs/memory/environment.example.md
  docs/memory/framework.example.md
  docs/memory/gotchas.example.md
  docs/memory/performance.example.md
  docs/memory/shared.example.md
  docs/memory/testing.example.md
)

# ---------------------------------------------------------------------------
# Gitignored personal files, bootstrapped from their tracked *.example.md
# counterpart on first install — never overwritten if the personal file
# already exists. Each entry is "example:personal". framework.example.md is
# deliberately excluded — it needs a project-specific rename (e.g. laravel.md)
# this generic example->personal mapping can't determine; docs/SETUP.md
# documents the manual rename command, and AGENTS.md's session-start ritual
# self-creates it correctly on first need. Mirrors Installer::PERSONAL_FILES.
# ---------------------------------------------------------------------------
PERSONAL_FILES=(
  "docs/MEMORY.example.md:docs/MEMORY.md"
  "docs/memory/gotchas.example.md:docs/memory/gotchas.md"
  "docs/memory/database.example.md:docs/memory/database.md"
  "docs/memory/testing.example.md:docs/memory/testing.md"
  "docs/memory/environment.example.md:docs/memory/environment.md"
  "docs/memory/performance.example.md:docs/memory/performance.md"
  "docs/memory/agents.example.md:docs/memory/agents.md"
)

# ---------------------------------------------------------------------------
# User-owned scaffold files — copied once, never overwritten without --force,
# and backed up to <file>.bak before any forced overwrite.
#
# .claude/settings.json is deliberately excluded from this list — install.sh
# copies it ad hoc (same copy-if-absent semantics, see copy_scaffold calls at
# the bottom of this file's callers) instead of enumerating it here, because
# this repo's own root .claude/settings.json is Eric's real Claude Code config
# for developing this package, not a template mirror, and the "root template
# files match stubs" test (Installer.php's PHP equivalent) asserts byte-parity
# for every file in SCAFFOLD_FILES/MANAGED_FILES. Mirrors Installer::SCAFFOLD_FILES.
# ---------------------------------------------------------------------------
SCAFFOLD_FILES=(
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  .claude/rules/security.md
  .claude/rules/testing.md
  .claude/skills/example-skill/SKILL.md
  .github/copilot-instructions.md
  docs/ARCHITECTURE.md
  docs/ARCHITECTURE_HISTORY.md
  docs/BUGS.md
  docs/BUGS_ARCHIVE.md
  docs/CODE_PATTERNS.md
  docs/COMMANDS.md
  docs/COMPLIANCE.md
  docs/DESIGN.md
  docs/DOCKER.md
  docs/FEATURE_FLAGS.md
  docs/GLOSSARY.md
  docs/METRICS_HISTORY.md
  docs/SCHEMA.md
  docs/SETUP.md
  docs/STATUS.md
  docs/TESTING_COVERAGE.md
)

# .gitignore lines to merge into a target, grouped — each group's header
# comment is only re-emitted if the whole group is missing; a partially
# present group gets only its missing lines appended, so re-running the
# installer never duplicates a line that's already there.
GITIGNORE_GROUP_1_HEADER="# MAP — developer-specific files (do not commit)"
GITIGNORE_GROUP_1=(".claude/settings.local.json")

GITIGNORE_GROUP_2_HEADER="# Claude personal local rules — developer specific, not shared"
GITIGNORE_GROUP_2=("CLAUDE.local.md")

GITIGNORE_GROUP_3_HEADER="# Claude auto-memory — session/machine specific
# Copy *.example.md files to their non-example versions on first clone"
GITIGNORE_GROUP_3=("docs/MEMORY.md" "docs/memory/*.md" "!docs/memory/*.example.md" "!docs/memory/shared.md")

# .gitattributes lines to merge into a target (in order). merge=map-ai routes
# the Claude-maintained docs through .map/merge.sh, which resolves the
# conflicts markdown docs typically hit (both branches appending entries or
# table rows, bumping "Last updated", picking the same next BUG-N) and leaves
# real conflicts to a human. Human-authored docs (DESIGN/DOCKER/SETUP/
# COMPLIANCE) are deliberately left on git's normal merge. Mirrors
# Installer::GITATTRIBUTES_ENTRIES.
GITATTRIBUTES_HEADER="# MAP — structured markdown merge driver (.map/merge.sh, registered per clone)"
GITATTRIBUTES_BLOCK=(
  "docs/BUGS.md merge=map-ai"
  "docs/BUGS_ARCHIVE.md merge=map-ai"
  "docs/ARCHITECTURE_HISTORY.md merge=map-ai"
  "docs/METRICS_HISTORY.md merge=map-ai"
  "docs/STATUS.md merge=map-ai"
  "docs/ARCHITECTURE.md merge=map-ai"
  "docs/CODE_PATTERNS.md merge=map-ai"
  "docs/COMMANDS.md merge=map-ai"
  "docs/FEATURE_FLAGS.md merge=map-ai"
  "docs/GLOSSARY.md merge=map-ai"
  "docs/SCHEMA.md merge=map-ai"
  "docs/TESTING_COVERAGE.md merge=map-ai"
  "docs/memory/shared.md merge=map-ai"
  "docs/agents/*.md merge=map-ai"
  "docs/api/*.md merge=map-ai"
  "docs/architecture/*.md merge=map-ai"
  "docs/integrations/*.md merge=map-ai"
  "docs/qa/*.md merge=map-ai"
)

# Lines earlier MAP versions wrote. merge=union kept every line from both
# sides, which resurrected bugs one branch had moved to BUGS_ARCHIVE.md —
# removed on install now that merge=map-ai replaces them. Mirrors
# Installer::LEGACY_GITATTRIBUTES_ENTRIES.
LEGACY_GITATTRIBUTES_BLOCK=(
  "docs/BUGS.md merge=union"
  "docs/BUGS_ARCHIVE.md merge=union"
  "docs/ARCHITECTURE_HISTORY.md merge=union"
  "docs/METRICS_HISTORY.md merge=union"
)

# The per-clone git config that makes merge=map-ai mean something. git config
# is never committed, so every clone registers it once — install.sh, doctor
# --fix and the SessionStart hook all do. Unregistered, git silently falls
# back to its normal text merge for these files. Mirrors Installer::MERGE_DRIVER.
MERGE_DRIVER_NAME="MAP structured markdown merge"
MERGE_DRIVER_COMMAND='bash "$(git rev-parse --show-toplevel)/.map/merge.sh" %O %A %B %P'

# True if $1 is inside a git work tree.
is_git_repo() {
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# True if $1's clone already has the MAP merge driver registered exactly.
merge_driver_registered() {
  [[ "$(git -C "$1" config --get merge.map-ai.driver 2>/dev/null)" == "$MERGE_DRIVER_COMMAND" ]]
}

register_merge_driver() {
  git -C "$1" config merge.map-ai.name "$MERGE_DRIVER_NAME" &&
    git -C "$1" config merge.map-ai.driver "$MERGE_DRIVER_COMMAND"
}

# Strips CRLF and surrounding whitespace from each line of $1 so a line
# that's already present but byte-different (e.g. CRLF endings, leading or
# trailing spaces) isn't treated as missing and re-appended as a duplicate —
# matches Installer.php's trim() normalization. Uses `tr -d '\r'` rather than
# sed's `\r` escape for the CR strip — `\r` as a sed regex escape is a GNU
# extension not reliably honored by BSD/macOS sed, while `tr -d` and sed's
# `[[:space:]]` POSIX class both work identically on GNU and BSD.
normalize_lines() {
  tr -d '\r' < "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
