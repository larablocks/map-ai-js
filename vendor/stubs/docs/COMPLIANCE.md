# COMPLIANCE.md
_Project-specific regulatory and compliance obligations — human-authored; Claude may propose edits, but never writes them without developer approval_
_Distinct from .claude/rules/security.md — that file covers generic secret hygiene; this file covers this project's actual regulatory obligations_
_Last updated: YYYY-MM-DD_

## Applicable frameworks
[e.g. GDPR, HIPAA, SOC2, PCI-DSS — list only what actually applies to this project. Delete the rest.]

## Data classification
| Data type | Classification | Handling requirement |
|---|---|---|
| [e.g. customer email] | [e.g. PII] | [e.g. encrypted at rest, access logged, never in plaintext logs] |

## Retention and deletion
[How long each data type is kept, what must be deleted on user request, and how deletion is verified.]

## Audit requirements
[What must be logged, for how long, and who can access those logs.]

## Access control requirements
[Who or what can touch classified data — roles, service boundaries, approval requirements.]

## Constraints on AI-assisted changes
[Anything the AI must never do without explicit human sign-off — e.g. never add a new export
destination for classified data without a documented data-processing agreement in place.]

---
