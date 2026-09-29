# BUGS.md
_Known bugs — updated by Claude on discovery or after test failures_
_Claude writes immediately on discovery — do not wait for session end_
_Fixed and verified bugs move to docs/BUGS_ARCHIVE.md immediately — one at a time, never batched_
_Each open bug is locked in as a skipped test citing its BUG-N; the test flips from skipped to passing when the fix lands (see the Test/Covered by fields below)_
_Distinct from a coverage gap (docs/TESTING_COVERAGE.md `[none]`/`[partial]` rows): a BUG-N is a confirmed defect with known-wrong behaviour, a coverage gap is just untested code that may or may not be correct_

<!-- Severity: blocking=no further work | high=no workaround | medium=workaround exists | low=minor -->
<!-- Verification tag: append (Verified.) if a human or a passing test confirmed the bug and its fix, or (Agent-reported.) if only Claude observed it — carry the tag forward into docs/BUGS_ARCHIVE.md -->
<!-- Merge conflicts: this file has merge=map-ai in .gitattributes, so .map/merge.sh resolves
     the usual conflicts on merge — entries added on both branches are both kept, a bug one branch
     moved to docs/BUGS_ARCHIVE.md stays moved, and when both branches picked the same BUG-N the
     one that was already on your side keeps it and the other is renumbered to the next free
     number (the merge prints which). After such a renumber, fix any references to the old number
     in docs/qa/*.md. Anything it can't resolve safely — the same bug edited differently on both
     branches, or archived on both — is left for review. Git only runs the driver on a file both
     branches changed, so a clash between one branch's BUGS.md and the other's BUGS_ARCHIVE.md
     is caught afterwards instead: `bash .map/merge.sh --check-bugs` (run by the SessionStart hook
     and doctor) lists it, `bash .map/merge.sh --fix-bugs` renumbers the copy in this file.
     If numbering ever needs a clean reset instead of a per-entry rename, append a dated
     "### Numbering note — YYYY-MM-DD" entry under Open bugs stating the next unused number
     explicitly, so future scans don't have to recount from history. -->

## Open bugs
<!-- BUG-N: if a dated "### Numbering note" entry exists below, use the number it states as the next available and skip the recount; otherwise scan BOTH this file and docs/BUGS_ARCHIVE.md for the highest existing number and increment by 1 — numbers are permanent, never reused -->
<!-- Format:
### BUG-[N] — [Short title] (Verified. / Agent-reported.)
- **Discovered:** YYYY-MM-DD via [test failure / code review / runtime]
- **Affects:** [file or module]
- **Severity:** [blocking / high / medium / low]
- **Description:** [What is wrong]
- **Blocking:** [What this prevents, or NONE]
- **Status:** open / investigating
- **Test:** [name of the skipped test locking this in, or NONE if not yet written]
-->

## Fixed bugs
<!-- Move here when resolved, then to docs/BUGS_ARCHIVE.md as soon as the fix is verified — do not let this section accumulate -->
<!-- Format:
### BUG-[N] — [Short title] ✓ (Verified. / Agent-reported.)
- **Fixed:** YYYY-MM-DD
- **Fix:** [What was done]
- **Covered by:** [test name or file — the skipped test that now passes]
-->
