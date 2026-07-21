# AGENTS.md
_Project: [PROJECT NAME] | Stack: [e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]_
_MAP v1.0 | Last updated: [DATE]_

## Personal rules
Load @CLAUDE.local.md if it exists or equivalent local rules file for your tool — overrides AGENTS.md

## Session start ritual
0. First-run check: if this file's header above still shows an unfilled name/stack/date placeholder, or docs/STATUS.md / docs/ARCHITECTURE.md still show their bracket placeholders (e.g. a milestone or system-overview placeholder), this project has never been initialized by an AI agent — before doing anything else, including responding to the developer's first message: read the codebase (composer.json/package.json, README, directory structure) to understand what it is, fill in this file's header/Commands section if still unfilled, then replace docs/STATUS.md's and docs/ARCHITECTURE.md's placeholders with real content based on what you found
1. Read @docs/STATUS.md — if it contains only placeholder text, tell developer to fill it in
2. Read @docs/MEMORY.md — if missing, create it from docs/MEMORY.example.md (and docs/memory/gotchas.md, docs/memory/shared.md from their examples if also missing), then load it and note topic files — any other docs/memory/*.md a Load rule below names self-creates from its same-named .example.md the first time that rule fires
3. Read @docs/BUGS.md — note any blocking or high severity bugs before starting work
4. Ask the developer what they want to work on before acting

## Commands — fill these in for this project
- Run tests: `[TEST COMMAND]`
- Static analysis: `[STATIC ANALYSIS COMMAND]`
- Start services: `[START COMMAND]`
- Build: `[BUILD COMMAND]`

_If any command above still shows a `[...]` placeholder, detect it by reading composer.json, package.json, and Makefile, then replace the placeholder in this file._

## Load when relevant
Read @docs/ARCHITECTURE.md when working on structure or new features
Read @docs/ARCHITECTURE_HISTORY.md when revisiting an architectural choice
Read @docs/CODE_PATTERNS.md when writing application code, migrations, config or scripts
Read @docs/SCHEMA.md when touching the database or internal service contracts
Read @docs/COMPLIANCE.md when touching data classified as sensitive, exports, deletions, or third-party data integrations
Read @docs/BUGS.md when writing tests or modifying areas with known issues
Read @docs/TESTING_COVERAGE.md when writing or reviewing tests
Read @docs/DOCKER.md when running commands or diagnosing environment issues (skip if project has no Docker)
Read @docs/SETUP.md when helping with local dev or onboarding questions
Read @docs/GLOSSARY.md when domain-specific terms or abbreviations are unfamiliar
Read @docs/COMMANDS.md when running or referencing a custom project command
Read @docs/DESIGN.md when writing frontend code or UI components (skip if no UI layer) — it wins over conflicting code by default; once per session, run `npx @google/design.md lint` first if available, skip silently if not
Read the project's stack-specific memory file (see docs/MEMORY.md's summary table for its filename) when writing application code, migrations, config or scripts — past surprises; if the table still shows the `[stack].md` placeholder row, self-create the file by copying docs/memory/framework.example.md to a name matching the project's stack (e.g. laravel.md) and update that row
Read @docs/memory/agents.md when working on agent pipeline (skip if no agents)
Read @docs/memory/database.md when touching the database or schema
Read @docs/memory/testing.md when writing or debugging tests
Read @docs/memory/environment.md when diagnosing environment issues
Read @docs/memory/performance.md when investigating slow behaviour or optimising code
Read @docs/FEATURE_FLAGS.md when starting a new feature or working on flagged code
Working on an agent, API, integration, or component → scan the frontmatter (name + description) across docs/agents/, docs/api/, docs/integrations/, docs/architecture/ for the matching file, then load only that file's full body
Read @docs/qa/[ticket-or-slug].md when reviewing or testing a recently completed feature

## Write rules — do these immediately, without being asked
_Priority order: BUGS.md first, then ARCHITECTURE_HISTORY.md, then others_
- Bug found (any source) → append to docs/BUGS.md; Bug fixed and verified → move to docs/BUGS_ARCHIVE.md
- Branch merged → check docs/BUGS.md and docs/BUGS_ARCHIVE.md for duplicate BUG-N IDs; if found, follow the renumbering procedure documented in docs/BUGS.md
- Architectural decision made → append to docs/ARCHITECTURE_HISTORY.md (hard to reverse or multi-component only)
- New pattern established → check docs/CODE_PATTERNS.md first, only append if not already covered
- Project-specific term, abbreviation, or concept a newcomer wouldn't know → add to docs/GLOSSARY.md so new developers can gain context quickly
- Surprising behaviour → route by topic (all in docs/memory/): the stack-specific file (see docs/MEMORY.md's table) | database.md | testing.md | environment.md | performance.md | agents.md
- Learning applies to the whole team, not just one machine → also append to docs/memory/shared.md (max 50 entries — remove least-actionable when full)
- Memory file updated → update entry count in docs/MEMORY.md summary table
- Time wasted on a mistake → append to docs/memory/gotchas.md (max 10 entries — remove least-actionable when full)
- Schema changed → update docs/SCHEMA.md immediately
- Architecture changed → update docs/ARCHITECTURE.md to reflect current state
- Tests added or coverage run → update docs/TESTING_COVERAGE.md from command output
- Performance issue discovered → append to docs/memory/performance.md
- New feature started → suggest adding a feature flag before implementing; flag created → append row to docs/FEATURE_FLAGS.md active section; flag removed → move row to removed section
- Custom command added, changed, or removed → update docs/COMMANDS.md in the relevant category (add, edit, or delete the entry and its Quick index row), note if destructive
- Agent/API/integration/component changes materially → update its docs/agents|api|integrations|architecture/[name].md file (including its frontmatter description); new docs/architecture/[name].md → also add its row to ARCHITECTURE.md's Component docs table
- A design token changes, Docker/environment config changes, a setup step changes, or a compliance obligation changes → do NOT edit docs/DESIGN.md, docs/DOCKER.md, docs/SETUP.md, or docs/COMPLIANCE.md directly; draft the proposed change inline in your response and ask the developer to confirm before writing it — for docs/COMPLIANCE.md, check its own Constraints on AI-assisted changes section first: some changes require a specific artifact in place (e.g. a documented agreement), not just a verbal yes
- Task complete → ask the developer if they want a QA file generated; if yes, check branch name for ticket number (e.g. ABC-123) and create docs/qa/[TICKET].md or docs/qa/[feature-slug].md from the example

## Session end — do this before closing
1. Update docs/STATUS.md — milestone/feature progress, health indicators, project-level next priorities
2. Append a dated entry to docs/METRICS_HISTORY.md — current metrics vs. the previous entry
3. Ask "what did I learn?" — route each learning to docs/memory/ and update MEMORY.md entry counts

## File routing — when in doubt
_Most routing is already covered by the Write rules above — this is only what isn't_
New agent/API/integration/component docs → scan the target folder's frontmatter for an existing match first, then copy the relevant .example.md and fill in its name/description

## Ask before acting
- Change touches classified/sensitive data handling → confirm against docs/COMPLIANCE.md before proceeding (distinct from the compliance write rule — that one gates edits to the file itself)
- Destructive or cross-system action → confirm scope before executing
- Ambiguous requirement → state interpretation and confirm
- Uncertain about framework-specific approach → read relevant docs/ file first, then act
- Otherwise → act then explain

## Hard rules
- IMPORTANT: Never delete files, database records, or data without explicit developer confirmation
- IMPORTANT: Never modify AGENTS.md, CLAUDE.md, GEMINI.md, or .claude/rules/*.md without explicit developer instruction — these are MAP configuration files, not AI-maintained docs. Running `doctor.sh`/`Doctor::fix()` counts as that instruction — it only ever applies pure additions or safe note/comment swaps, never rewrites real content
- Use YYYY-MM-DD for all dates in all files
- IMPORTANT: Only update docs/TESTING_COVERAGE.md after running coverage — never estimate without fresh output
- IMPORTANT: Never skip the session start ritual

## Project hard rules
[Project-specific hard rules that don't fit the generic list above — e.g. "never call the production billing API from a dev session." Delete this line once real rules are added; leave the section empty if there are none yet.]
