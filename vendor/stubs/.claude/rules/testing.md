# rules/testing.md
_Human-maintained — always loaded by Claude Code every session_

## Coverage requirements
- IMPORTANT: New code requires tests before marking a task complete
  (exception: first task on a new project may establish the test framework itself)
- Minimum coverage threshold: 80% (adjust here if project requires different)
  Run coverage command and update docs/TESTING_COVERAGE.md after adding tests
- Critical paths require explicit test coverage regardless of overall percentage

## Test quality
- Tests must assert behaviour, not implementation details
- Each test has one clear reason to fail
- Test names describe the scenario, not the method being tested

## Static analysis
- Static analysis must pass before any task is considered complete
- Do not suppress errors without a comment explaining why
