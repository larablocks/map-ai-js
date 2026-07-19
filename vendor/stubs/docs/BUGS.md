# BUGS.md
_Known bugs — updated by Claude on discovery or after test failures_
_Claude writes immediately on discovery — do not wait for session end_
_Fixed and verified bugs move to docs/BUGS_ARCHIVE.md immediately — one at a time, never batched_
_Each open bug is locked in as a skipped test citing its BUG-N; the test flips from skipped to passing when the fix lands (see the Test/Covered by fields below)_
_Distinct from a coverage gap (docs/TESTING_COVERAGE.md `[none]`/`[partial]` rows): a BUG-N is a confirmed defect with known-wrong behaviour, a coverage gap is just untested code that may or may not be correct_

<!-- Severity: blocking=no further work | high=no workaround | medium=workaround exists | low=minor -->
<!-- Verification tag: append (Verified.) if a human or a passing test confirmed the bug and its fix, or (Agent-reported.) if only Claude observed it — carry the tag forward into docs/BUGS_ARCHIVE.md -->
<!-- Merge conflicts: this file has merge=union in .gitattributes, so concurrent additions from
     different branches combine automatically instead of producing conflict markers. That does
     NOT catch two branches independently assigning the same BUG-N. After merging, scan the
     combined file (and docs/BUGS_ARCHIVE.md) for duplicate BUG-N headers — keep whichever entry
     comes first, renumber the other to the next free number, and fix any references to the old
     number in this file, docs/BUGS_ARCHIVE.md, and docs/qa/*.md. If numbering ever needs a clean
     reset instead of a per-entry rename, append a dated "### Numbering note — YYYY-MM-DD" entry
     under Open bugs stating the next unused number explicitly, so future scans don't have to
     recount from history. -->

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
