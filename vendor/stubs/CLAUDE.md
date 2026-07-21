# CLAUDE.md
_Claude Code entry point — imports AGENTS.md (MAP v1.0) and adds Claude-specific config_

@AGENTS.md

## Claude Code additions
- `.claude/rules/*.md` files load automatically every session — no @import needed
- `.claude/skills/*/SKILL.md` are auto-discovered and invoked when relevant — no @import or AGENTS.md wiring needed
- `.claude/hooks/map-first-run-check.sh` runs automatically every session start via `.claude/settings.json`'s SessionStart hook — makes the Session start ritual's first-run check (item 0) deterministic; it self-silences once real content replaces the placeholders it looks for
- Keep AGENTS.md at 100 lines maximum
- When AGENTS.md, `.claude/rules/security.md`, or `.claude/rules/testing.md` changes, update `.github/copilot-instructions.md` to match
