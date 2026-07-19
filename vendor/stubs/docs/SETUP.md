# SETUP.md
_Local development setup — human-authored; Claude may propose edits, but never writes them without developer approval_
_Last updated: YYYY-MM-DD_

## Prerequisites
| Tool | Version | Notes |
|---|---|---|
| Git | 2.x+ | https://git-scm.com |
| [AI coding tool] | latest | [install docs for your chosen tool] |
| [Tool] | [version] | [where to get it] |

## Initial setup
```bash
# 1. Clone
git clone [repo-url] && cd [project-name]

# 2. Fill in AGENTS.md — line 2: project name and stack; line 3: today's date

# 3. Initialize personal files (gitignored)
# All of these are optional to run by hand — running install.sh/doctor.sh --fix (or
# map-ai-laravel's map:install) already bootstraps every one of these except the
# stack-specific rename below, and AGENTS.md's session start ritual self-creates
# MEMORY.md, gotchas.md, and shared.md on first session if still missing, and
# self-creates each other topic file the first time its own Load rule needs it.
# Run these cp commands by hand only if you want to review/edit a file before your
# first install/AI session, or want the stack-specific file renamed up front.
cp docs/MEMORY.example.md docs/MEMORY.md
cp docs/memory/gotchas.example.md docs/memory/gotchas.md
cp docs/memory/framework.example.md docs/memory/[stack].md    # e.g. laravel.md; then update [stack].md ref in docs/MEMORY.md — not auto-bootstrapped, needs this rename
cp docs/memory/database.example.md docs/memory/database.md
cp docs/memory/testing.example.md docs/memory/testing.md
cp docs/memory/environment.example.md docs/memory/environment.md
cp docs/memory/performance.example.md docs/memory/performance.md
cp docs/memory/agents.example.md docs/memory/agents.md  # skip if no agent pipeline

# 3b. Initialize shared team files (committed to repo — not gitignored)
cp docs/memory/shared.example.md docs/memory/shared.md

# 4. Install dependencies
[install command]

# 5. Configure environment
# First: create .env.example in your project with all required key names (not in this template)
cp .env.example .env

# 6. Start services, migrate, seed
docker compose up -d
[migration command]
[seed command]  # if required
```

## Environment configuration
| Variable | Required | Default | Notes |
|---|---|---|---|
| [VAR] | yes/no | [default] | [what needs a real value] |

## Verify setup
[Specific URLs or commands to confirm everything is working.
Expected output included.]

## Verify tooling
Run all commands from the Commands section in AGENTS.md — each should complete without errors.
If any fail, fix before starting development.

## Common setup failures
| Symptom | Cause | Fix |
|---|---|---|
| [Error] | [Why it happens] | [How to fix it] |

## Development tools
[PhpStorm config, Xdebug setup, any project-specific tooling.]

## Ready to start
Setup is complete when:
- All services start without errors
- All tooling commands pass
- AI agent reads AGENTS.md on first prompt (start a session and type anything to verify)
