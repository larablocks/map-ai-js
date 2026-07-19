// detect.js — reads package.json (and a few marker files) to auto-fill
// AGENTS.md's placeholders. The JS/TS equivalent of map-ai-laravel's
// ProcessesStubContent trait (detectProjectInfo()/detectCommands()), applying
// the same "detect what you can, leave the rest as a placeholder for the
// developer" fallback rather than guessing.

import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// Meta-frameworks are listed before the base library they're built on
// (next before react-dom, nuxt before vue, etc.) so the more specific one
// wins when both are present in dependencies, matching how any Next.js app
// also depends on react/react-dom directly.
const FRAMEWORK_DEPS = [
  ['next', 'Next.js'],
  ['nuxt', 'Nuxt'],
  ['@sveltejs/kit', 'SvelteKit'],
  ['@remix-run/react', 'Remix'],
  ['remix', 'Remix'],
  ['astro', 'Astro'],
  ['@angular/core', 'Angular'],
  ['@nestjs/core', 'NestJS'],
  ['react-dom', 'React'],
  ['vue', 'Vue'],
  ['svelte', 'Svelte'],
  ['fastify', 'Fastify'],
  ['express', 'Express'],
];

const DATA_DEPS = [
  ['drizzle-orm', 'Drizzle'],
  ['@prisma/client', 'Prisma'],
  ['prisma', 'Prisma'],
  ['mongoose', 'MongoDB'],
  ['pg', 'PostgreSQL'],
  ['postgres', 'PostgreSQL'],
  ['mysql2', 'MySQL'],
  ['better-sqlite3', 'SQLite'],
  ['ioredis', 'Redis'],
  ['redis', 'Redis'],
];

export function readPackageJson(targetPath) {
  const path = join(targetPath, 'package.json');
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
}

function titleCase(name) {
  const unscoped = name.includes('/') ? name.split('/').pop() : name;
  return unscoped.replace(/[-_]+/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

function basenameOf(targetPath) {
  return targetPath.split(/[\\/]/).filter(Boolean).pop() ?? targetPath;
}

function majorVersion(range) {
  const match = /(\d+)/.exec(range ?? '');
  return match ? match[1] : null;
}

export function detectPackageManager(targetPath) {
  if (existsSync(join(targetPath, 'pnpm-lock.yaml'))) return 'pnpm';
  if (existsSync(join(targetPath, 'yarn.lock'))) return 'yarn';
  if (existsSync(join(targetPath, 'bun.lockb'))) return 'bun';
  return 'npm';
}

/** @returns {Record<string, string>} placeholder -> detected value */
export function detectProjectInfo(targetPath) {
  const pkg = readPackageJson(targetPath);
  const detected = {};

  detected['[PROJECT NAME]'] = pkg?.name ? titleCase(pkg.name) : titleCase(basenameOf(targetPath));

  const deps = { ...(pkg?.dependencies ?? {}), ...(pkg?.devDependencies ?? {}) };
  const stack = [];

  for (const [dep, label] of FRAMEWORK_DEPS) {
    if (deps[dep]) {
      const version = majorVersion(deps[dep]);
      stack.push(version ? `${label} ${version}` : label);
      break;
    }
  }

  stack.push(deps['typescript'] ? 'TypeScript' : 'JavaScript');

  for (const [dep, label] of DATA_DEPS) {
    if (deps[dep] && !stack.includes(label)) {
      stack.push(label);
    }
  }

  if (stack.length > 0) {
    detected['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]'] = stack.join(', ');
  }

  return detected;
}

/** @returns {Record<string, string>} placeholder -> detected value */
export function detectCommands(targetPath) {
  const pkg = readPackageJson(targetPath);
  const scripts = pkg?.scripts ?? {};
  const pm = detectPackageManager(targetPath);
  const detected = {};

  if (scripts.test) {
    detected['[TEST COMMAND]'] = `${pm} test`;
  }

  const checks = [];
  if (scripts.typecheck) checks.push(`${pm} run typecheck`);
  if (scripts.lint) checks.push(`${pm} run lint`);
  if (checks.length > 0) {
    detected['[STATIC ANALYSIS COMMAND]'] = checks.join(' && ');
  }

  if (
    existsSync(join(targetPath, 'docker-compose.yml')) ||
    existsSync(join(targetPath, 'docker-compose.yaml')) ||
    existsSync(join(targetPath, 'compose.yaml')) ||
    existsSync(join(targetPath, 'compose.yml'))
  ) {
    detected['[START COMMAND]'] = 'docker compose up -d';
  } else if (scripts.dev) {
    detected['[START COMMAND]'] = `${pm} run dev`;
  } else if (scripts.start) {
    detected['[START COMMAND]'] = `${pm} start`;
  }

  if (scripts.build) {
    detected['[BUILD COMMAND]'] = `${pm} run build`;
  }

  return detected;
}

/** Applies [DATE] plus detectProjectInfo()/detectCommands() substitutions to AGENTS.md content. */
export function processAgentsMdContent(content, targetPath) {
  let result = content.replaceAll('[DATE]', new Date().toISOString().slice(0, 10));

  for (const [placeholder, value] of Object.entries({
    ...detectProjectInfo(targetPath),
    ...detectCommands(targetPath),
  })) {
    result = result.replaceAll(placeholder, value);
  }

  return result;
}
