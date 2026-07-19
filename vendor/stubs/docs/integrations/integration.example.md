---
name: [service-name]
description: [One sentence: why this project uses this service and when to load this file — scanned cheaply across docs/integrations/ before the full body is loaded]
---

# [Service Name]
_Copy this file to docs/integrations/[service-name].md when documenting a new integration_
_Load this file when working with this service_
_If this integration grows past ~150 lines or covers multiple distinct concerns, split into [service]-[topic].md companion files and make this file the index — link to each companion here and note inline that both must be kept current together_

## Purpose
[Why this project uses this service. One sentence.]

## Credentials
[What credentials are needed, which .env variables hold them, where to get them]

## How we use it
[Specific features or endpoints used — not the full service docs, just our usage]

## Configuration
[Any project-specific config, timeouts, retry settings, client setup]

## Key patterns
[How we call this service — any wrappers, conventions, error handling patterns]

## Rate limits and constraints
[Any limits that affect how we use this service]

## Known quirks
[Anything unexpected discovered while integrating — edge cases, gotchas]

## Still to confirm / wire
_Implemented but not yet verified live — distinct from docs/BUGS.md (confirmed defects) and docs/ARCHITECTURE_HISTORY.md (settled decisions): this is "we believe this works but haven't confirmed it in production/staging"_
[Behaviour and what would confirm it]

## Legacy / dormant surfaces
_Confirmed-dead-but-not-deleted code paths — distinct from docs/COMMANDS.md's breadcrumb (which notes when something was added and when it may be removed); this instead records what's already confirmed dead_
[e.g. "no active callers found as of YYYY-MM-DD" or "0% coverage, deferred" — name the file/function and why it's being kept rather than deleted]
