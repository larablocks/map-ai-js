# QA — [TICKET-123 / feature-slug]
_Feature: [one-line description of what was built]_
_Branch: [branch-name] | Date: YYYY-MM-DD_
_Audience: QA/non-engineers — default to UI-only language (what to click, what to see). Exception: security-relevant behavior (redirect guards, permission boundaries, injection points) may name the specific mechanism if necessary for the tester to construct a meaningful adversarial test case — state why inline._

## Acceptance criteria
- [ ] [What must be true for this ticket to pass]
- [ ] [Another criterion]

## Test cases

### TC-1 — [Happy path description]
**Preconditions:** [What must be set up or true before starting]
**Steps:**
1. [Action]
2. [Action]
**Expected:** [What should happen]

### TC-2 — [Alternate flow or failure case]
**Preconditions:** [Setup]
**Steps:**
1. [Action]
**Expected:** [Result]

## Edge cases & risk areas
_Flagged during implementation — give these extra attention_
- **[Area]:** [What to test and why it was flagged]

## Exploratory testing
_Open-ended — not scripted, guided by what changed_
- [Area or question to investigate]
