---
name: [component-name]
description: [One sentence: what this component owns and when to load this file — scanned cheaply across docs/architecture/ before the full body is loaded]
---

# [Component Name]
_Copy this file to docs/architecture/[component-name].md when documenting a subsystem_
_Load this file when working on this component or subsystem_
_Can also hold a forward spec for a planned-but-unbuilt component (see Status below)_

## Status
[Built / Planned — if Planned, say so explicitly and note what's blocking implementation]

## Responsibility
[What this component owns and is solely responsible for. One sentence.]

## Boundaries
[What this component must NOT do. What it delegates to other components.]

## How it fits in the system
[Where it sits in the data flow — what triggers it, what it calls, what calls it.]

## Key design decisions
[Decisions specific to this component that are not obvious from the code.
Link to docs/ARCHITECTURE_HISTORY.md entries where relevant.]

## Data owned
[Tables, queues, caches, or files this component exclusively writes to.]

## Dependencies
| Dependency | Why |
|---|---|
| [Component/service] | [What it needs from it] |

## Known constraints
[Performance limits, scaling limits, or hard technical constraints on this component.]
