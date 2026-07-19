# TESTING_COVERAGE.md
_Updated by Claude after running the coverage command and reviewing results_
_Do not update without running the coverage command first — never estimate from memory_
_A `[none]`/`[partial]` row here is a coverage gap, not a confirmed bug — see docs/BUGS.md for the bug-vs-coverage-gap distinction and for actual known bugs (BUG-N)_

Legend: `[covered]` = dedicated test file, `[partial]` = some paths tested, `[none]` = no test.

---

## Coverage snapshot
_All suites at a glance — update after every coverage run_

| Suite | Tool | Overall | Threshold | Status | Last run |
|---|---|---|---|---|---|
| Backend | [PHPUnit / Pest] | 0% | [N]% | ○ no data | — |
| Frontend | [Vitest / Jest] | 0% | [N]% | ○ no data | — |

_Remove rows that don't apply. Add rows for additional suites (e2e, contract, etc.)._

---

# Backend ([PHPUnit / Pest])

**Suite:** [N] tests passing, 0 failing ([duration with coverage]).
**Overall coverage:** 0% ([PCOV / Xdebug], measured [YYYY-MM-DD]).

> Re-run `[coverage command]` and update the % column whenever a tracked file's coverage moves ≥2 points or crosses a 100% boundary.

## How to run

```bash
[run command]           # run the suite
[coverage command]      # per-file coverage report
```

---

## Area 1 — [e.g. Critical / destructive / security-load-bearing]

_Files where a bug causes data loss, credential exposure, or irreversible side-effects._

| File | % | Status | Notes |
|---|---|---|---|
| `[path/to/file.php]` | 0% | `[none]` | [brief note — what's missing and why] |

## Area 2 — [e.g. Core business logic / domain]

| File | % | Status | Notes |
|---|---|---|---|
| `[path/to/file.php]` | 0% | `[none]` | [brief note] |

## Area 3 — [e.g. HTTP layer / controllers / requests]

| File | % | Status | Notes |
|---|---|---|---|
| `[path/to/file.php]` | 0% | `[none]` | [brief note] |

_Add or remove area sections to match the project's actual code structure._

---

## What's left to tackle (backend)

1. [Highest-priority gap — file, why it matters, what's blocking]
2. [Next gap]
3. [Integration-level files deferred pending a binary harness or external service]

---

# Frontend ([Vitest / Jest])

**Suite:** [N] tests passing, 0 failing ([duration with coverage]).
**Overall coverage ([YYYY-MM-DD]):**

| Metric | % | Hits / Total |
|---|---|---|
| Statements | 0% | 0 / 0 |
| Branches | 0% | 0 / 0 |
| Functions | 0% | 0 / 0 |
| Lines | 0% | 0 / 0 |

## How to run

```bash
[run command]           # run the suite
[coverage command]      # full coverage report
```

## Coverage scope

_List what is explicitly included in `[vitest/jest].config.js → coverage.include` — only measured files appear in the % above._

- **Always in scope:** [e.g. composables, stores, utils] — target 100%
- **Selectively in scope:** [e.g. components with non-trivial logic] — target load-bearing behaviours
- **Out of scope:** [e.g. pages, layouts, app entry] — [reason]

---

## Area 1 — [e.g. Composables / pure logic]

| File | % Stmts | Status | Notes |
|---|---|---|---|
| `[path/to/file.js]` | 0% | `[none]` | [brief note] |

## Area 2 — [e.g. Stores]

| File | % Stmts | Status | Notes |
|---|---|---|---|
| `[path/to/file.js]` | 0% | `[none]` | [brief note] |

## Area 3 — [e.g. Components (selective)]

| File | % Stmts | Status | Notes |
|---|---|---|---|
| `[path/to/file.vue]` | 0% | `[none]` | [brief note] |

---

## What's left to tackle (frontend)

1. [Highest-priority gap]
2. [Next gap]
3. [Out of scope today — revisit when X]

---

## Run history

| Date | Suite | Overall | Tests | Duration |
|---|---|---|---|---|
| — | — | — | — | — |
