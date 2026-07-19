# ARCHITECTURE.md
_Claude-maintained, human reviews for accuracy_
_Decision history: docs/ARCHITECTURE_HISTORY.md | Last updated: YYYY-MM-DD_

## System overview
[Plain English description of what this application does and how it
is decomposed. 3-5 sentences maximum.]

## Component inventory
| Component | Responsibility | Owns | Does not own |
|---|---|---|---|
| [Name] | [What it does] | [What it controls] | [Explicit boundaries] |

## Data flow
[How a request or job moves through the system end to end.
Describe the happy path in plain language.]

## Integration points
| Service | Purpose | Direction |
|---|---|---|
| [Service] | [Why it exists] | [inbound/outbound/both] |

## Architectural boundaries
[Rules that must not be crossed. E.g. "Component X has no direct
database access — all persistence goes through Component Y."]

## What is intentionally excluded
[Things that were considered and explicitly left out of scope.]

## Component docs
_Detailed subsystem docs — one file per component in docs/architecture/_
_Copy docs/architecture/architecture.example.md to get started_
| Component | File |
|---|---|
| [Name] | [docs/architecture/name.md] |
