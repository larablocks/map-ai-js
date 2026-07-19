# ARCHITECTURE_HISTORY.md
_Append-only — never edit or delete. Claude writes immediately on decision._
_Current state: docs/ARCHITECTURE.md | Summarise superseded entries when approaching 200 lines_
_Reversals: add new entry "YYYY-MM-DD — Reversal of [original title]"_

## Decision format
### YYYY-MM-DD — [Decision title]
**Decision:** [What was decided, specific and unambiguous]
**Alternatives considered:** [What else was evaluated]
**Reasoning:** [Why this option was chosen]
**Consequences:** [What this constrains going forward]

---

<!-- Example entry (delete this when adding your first real entry):
### 2026-01-15 — Use PostgreSQL over MySQL
**Decision:** PostgreSQL with pgvector extension for all data storage
**Alternatives considered:** MySQL, SQLite for development
**Reasoning:** pgvector support for embeddings, superior JSON handling, better full-text search
**Consequences:** All queries must use PostgreSQL syntax. No MySQL-compatible abstractions.
-->
