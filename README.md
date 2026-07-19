# map-ai-js

MAP (Markdown for AI Processing) documentation scaffold — install and drift-check CLI for React, Vue, Next.js, Nuxt, Angular, and plain Node/TypeScript projects.

This package doesn't reimplement MAP's install/patch logic — it vendors and shells out to [`larablocks/map-ai`](https://github.com/larablocks/map-ai)'s `install.sh`/`doctor.sh`, the same zero-runtime-dependency scripts that back non-PHP installs of MAP. The only JS-native part is auto-detecting your project's name, stack, and commands from `package.json` to fill in `AGENTS.md`, the same role [`map-ai-laravel`](https://github.com/larablocks/map-ai-laravel)'s `ProcessesStubContent` plays for Composer/Laravel projects.

## Install

```bash
npx map-ai-js install
```

Copies the MAP scaffold (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/`, `docs/`, etc.) into the current directory, merges the required `.gitignore`/`.gitattributes` entries, bootstraps your gitignored personal files (`docs/MEMORY.md`, `docs/memory/gotchas.md`, etc.), and fills in what it can detect from `package.json`:

- **Project name** — from `package.json`'s `name` (scope stripped, title-cased)
- **Stack** — the first framework it recognizes (Next.js, Nuxt, SvelteKit, Remix, Astro, Angular, NestJS, React, Vue, Svelte, Fastify, Express) plus TypeScript/JavaScript and any data-layer dependency (Drizzle, Prisma, MongoDB, PostgreSQL, MySQL, SQLite, Redis)
- **Test / static analysis / start / build commands** — from `package.json`'s `scripts`, using whichever package manager's lockfile is present (npm, pnpm, yarn, bun)

Anything it can't detect is left as a `[...]` placeholder for you to fill in by hand — same fallback behavior as `map-ai-laravel`.

Files that already exist are left alone unless you pass `--force`, which overwrites `SCAFFOLD_FILES` after backing each one up to `<file>.bak`:

```bash
npx map-ai-js install --force
```

Pass a path to install somewhere other than the current directory:

```bash
npx map-ai-js install ./apps/web
```

## Checking for drift

```bash
npx map-ai-js doctor              # report only — exits 1 if anything needs attention
npx map-ai-js doctor --fix        # applies fixable findings unattended, then reports what's left
npx map-ai-js doctor --interactive # same fixable set as --fix, confirmed one file at a time
```

`doctor` never touches real project content — it only ever adds missing files/lines, or replaces a stub's own instructional text (a stale italic note, HTML comment, or fenced-code trailing comment) with its current wording. Anything else — a real difference in `AGENTS.md`, `docs/ARCHITECTURE.md`, etc. — is reported for you to merge by hand, never auto-applied. See [`larablocks/map-ai`'s README](https://github.com/larablocks/map-ai#doctor--checking-and-repairing-drift-automatically) for the exact safety rules; this package's `doctor`/`install` commands are the same `doctor.sh`/`install.sh` scripts, unmodified.

## Why a separate package per ecosystem?

The install/doctor mechanics don't care what frontend framework you're using — only the placeholder auto-detection does, and that has to be written in the target ecosystem's own language to read its own manifest format (`package.json` here, `composer.json` for `map-ai-laravel`). One `map-ai-js` package covers the whole JS/TS ecosystem generically rather than shipping a separate package per framework.

## Keeping this package in sync with map-ai

This package vendors a copy of `install.sh`/`doctor.sh`/`lib.sh`/`stubs/` rather than depending on `larablocks/map-ai` at install time (there's no npm-native way to depend on a Composer package). `scripts/sync-from-map-ai.sh` re-vendors those files from a local `larablocks/map-ai` checkout — run it, review the diff, bump this package's version, and publish whenever map-ai core releases something this package should pick up.

## License

MIT
