---
name: "[Project Name] Design System"
---

# DESIGN.md
_UI/frontend design conventions — human-authored; Claude may propose edits, but never writes them without developer approval_
_Optional — delete this file if the project has no UI layer_
_Last updated: YYYY-MM-DD_

_YAML frontmatter follows the `@google/design.md` DESIGN.md spec (alpha) — keep it lintable with `npx @google/design.md lint`. Only `name` is required to keep the file valid; every other top-level key (`colors`, `typography`, `rounded`, `spacing`, `components`) is optional and should stay absent until the project actually defines it — a placeholder color/font value fails the linter's CSS validation and an unfilled placeholder Claude can't distinguish from an intentional one is worse than a missing key. Once `colors` is added, include a `primary` role and at least one `typography` entry — the linter warns on those specifically._

_If tokens already live in code (e.g. tailwind.config, design-tokens.json), don't duplicate the full set here — note that pointer in the relevant section below (Colors/Typography/Shapes) instead, and only mirror into frontmatter the handful of tokens worth surfacing for quick agent reference._

## Conflict resolution
If a component in code visibly contradicts this file (wrong color, wrong spacing, wrong font), this file wins by default — flag the discrepancy to the developer rather than silently matching the code. Exception: if the developer explicitly requests something that contradicts this file, follow the request and note the deviation as a proposed addition (see AGENTS.md's write rule for docs/DESIGN.md) rather than silently overriding the file.

## Overview
[Plain-language description of the design system's personality and goals.]

## Accessibility baseline
[Minimum a11y requirements — e.g. WCAG level, required aria patterns, keyboard navigation expectations.]

## Colors
[Describe the palette's intent. Expand the `colors` map in the frontmatter above as roles are added — primary, secondary, tertiary, neutral, surface, on-surface, and error are the spec's common roles.]

## Typography
[Describe the type voice and pairing. Expand the `typography` map in the frontmatter above with named text styles (e.g. h1, body-md, label-sm), each carrying fontFamily/fontSize/fontWeight/lineHeight/letterSpacing as needed.]

## Layout
[Spacing scale, grid, and responsive breakpoints. Add a `spacing` map to the frontmatter (e.g. sm/md/lg) as the project defines one.]

## Elevation & Depth
[Shadow and z-index conventions, if any.]

## Shapes
[Border-radius scale. Add a `rounded` map to the frontmatter (e.g. sm/md/lg/full) as the project defines one.]

## Components
[Where components live, naming, and composition patterns specific to this project. Expand the `components` map in the frontmatter for reusable token bundles as they're established.]

## Do's and Don'ts
**Do:** [Patterns to follow — name the specific file/component that demonstrates it well.]
**Don't:** [UI patterns in the codebase that should not be copied. Name the specific file/component.]

---
