# SCHEMA.md
_Claude-maintained — update immediately when schema changes_
_Keep concise — summaries only, not a migration dump. Human reviews for accuracy._

## Tables
<!-- Multi-DB: use ## Tables — [DB Name] headings. Format per table:
### table_name
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
Indexes: [list]
Relationships: [list]
Business rules: [any rules baked into the schema]
-->

## Relationships
[Which models relate to which, type of relationship, foreign key.
Focus on non-obvious relationships or those deviating from conventions.]

## Key business rules
[Rules enforced at the schema level — soft deletes, audit fields,
computed columns, columns that should never be written to directly.]

## Internal contracts
[Internal service-to-service payload shapes only — things that cross
a process boundary within your own system, not external APIs.]
[External API documentation goes in docs/api/ instead.]

---
