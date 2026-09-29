---
name: map-resolve
description: Resolve git merge, rebase, or cherry-pick conflicts in MAP docs (docs/*.md, AGENTS.md, CLAUDE.md, copilot-instructions.md, .claude/rules/) — and review resolutions the MAP merge driver already wrote — then hand back for the developer to approve before anything is staged. Use when a merge stops on conflicts in these files, or when asked to resolve or review them.
---

# map-resolve
_MAP-managed — kept in sync by install/doctor; don't edit in place_
_Pairs with .map/merge.sh, the git merge driver .gitattributes routes these files to_

## When to use
- A `git merge` / `rebase` / `cherry-pick` / `pull` stopped with conflicts in MAP docs
- The merge output said "map-merge: Claude resolved N conflict(s) … review" or "… left as conflict markers"
- The developer asks to resolve or review conflicts in docs

## Steps
1. List what is unmerged: `git diff --name-only --diff-filter=U`. Only handle the MAP files (the ones `.gitattributes` marks `merge=map-ai`); tell the developer about any others and leave them alone.
2. Sort each MAP file into one of two groups by whether it still contains conflict markers (`grep -c '^<<<<<<< ' <file>`):
   - **Has markers** → go to step 3.
   - **No markers, still unmerged** → the merge driver paused it for review: either it resolved the conflicts with Claude, or (in `docs/BUGS.md` / `docs/BUGS_ARCHIVE.md`) the same BUG-N now has two entries because both branches handled that bug. The merge output says which. For a duplicate bug, keep one entry or combine them. Go to step 5.
3. If `merge.map-ai` wasn't registered when the merge ran (`git config --get merge.map-ai.driver` is empty), apply MAP's deterministic rules first: `MAP_MERGE_LLM=0 bash .map/merge.sh --resolve <file>`. It re-merges from git's index stages and leaves markers only around what the rules can't settle. It never runs `git add`.
4. Resolve each remaining conflict hunk yourself:
   - Read the file's header lines (the italic `_..._` rules at the top) and follow them — append-only logs never lose entries, "Last updated" takes the newest date, BUG-N numbers are never reused.
   - Compare OURS and THEIRS against BASE (the `|||||||` section): a line present in BASE but missing from one side was removed on purpose — keep it removed.
   - Keep every piece of information from both sides otherwise; combine edits to the same fact when they don't contradict, and when they do, ask the developer rather than pick.
   - Don't invent content, headings, or entries. Keep tables and lists in the surrounding style.
   - For `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/rules/*.md`, `docs/DESIGN.md`, `docs/DOCKER.md`, `docs/SETUP.md`, `docs/COMPLIANCE.md`: propose the resolution and wait for explicit approval before writing — these follow AGENTS.md's approval rules even mid-merge.
   - Recent intent helps: `git log --oneline -5 MERGE_HEAD -- <file>` (or `REBASE_HEAD` / `CHERRY_PICK_HEAD`) and `git log --oneline -5 HEAD -- <file>`.
5. Review every resolved file with the developer: show `git diff <file>` (the combined diff against both sides) and summarise, per conflict, what was kept from each side and why. To start a file over from the raw conflict: `git checkout --conflict=diff3 -- <file>`.
6. Only after the developer confirms, `git add <file>`. Never run `git commit`, `git merge --continue`, or `git rebase --continue` yourself unless the developer explicitly asks.
7. If the merge renumbered a duplicate BUG-N (the output says "renumbered … to BUG-…"), update references to the old number in `docs/qa/*.md` and mention it. After the merge, `bash .map/merge.sh --check-bugs` catches a BUG-N clash git never ran the driver on (one branch changed only `docs/BUGS.md`, the other only `docs/BUGS_ARCHIVE.md`).

## Supporting files
- `.map/merge.sh` — the merge driver; `--resolve <file>` re-runs it on an already-conflicted file (see its header for the rules and the `MAP_MERGE_*` settings)
