import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { detectCommands, detectPackageManager, detectProjectInfo, processAgentsMdContent } from '../src/detect.js';

let dir;

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'map-ai-js-detect-'));
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

function writePackageJson(content) {
  writeFileSync(join(dir, 'package.json'), JSON.stringify(content));
}

describe('detectProjectInfo', () => {
  it('title-cases the project name from package.json', () => {
    writePackageJson({ name: 'my-cool-app' });
    expect(detectProjectInfo(dir)['[PROJECT NAME]']).toBe('My Cool App');
  });

  it('strips the npm scope from a scoped package name', () => {
    writePackageJson({ name: '@acme/my_app' });
    expect(detectProjectInfo(dir)['[PROJECT NAME]']).toBe('My App');
  });

  it('falls back to the title-cased directory name when package.json has no name', () => {
    writePackageJson({});
    const expected = dir
      .split('/')
      .pop()
      .replace(/[-_]+/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());
    expect(detectProjectInfo(dir)['[PROJECT NAME]']).toBe(expected);
  });

  it('detects Next.js with its major version over plain React', () => {
    writePackageJson({ dependencies: { next: '^16.2.10', react: '19.2.4', 'react-dom': '19.2.4' } });
    expect(detectProjectInfo(dir)['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]']).toBe('Next.js 16, JavaScript');
  });

  it('detects plain React when no meta-framework is present', () => {
    writePackageJson({ dependencies: { 'react-dom': '^19.0.0' } });
    expect(detectProjectInfo(dir)['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]']).toBe('React 19, JavaScript');
  });

  it('detects Vue', () => {
    writePackageJson({ dependencies: { vue: '^3.4.0' } });
    expect(detectProjectInfo(dir)['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]']).toBe('Vue 3, JavaScript');
  });

  it('includes TypeScript instead of JavaScript when typescript is a dependency', () => {
    writePackageJson({ dependencies: { vue: '^3.4.0' }, devDependencies: { typescript: '^5.0.0' } });
    expect(detectProjectInfo(dir)['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]']).toBe('Vue 3, TypeScript');
  });

  it('appends detected data-layer dependencies to the stack', () => {
    writePackageJson({ dependencies: { next: '^16.0.0', 'drizzle-orm': '^0.45.0', postgres: '^3.4.0' } });
    expect(detectProjectInfo(dir)['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]']).toBe(
      'Next.js 16, JavaScript, Drizzle, PostgreSQL'
    );
  });

  it('still reports JavaScript as the stack when no framework or data dependency is detected', () => {
    writePackageJson({});
    expect(detectProjectInfo(dir)['[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]']).toBe('JavaScript');
  });
});

describe('detectCommands', () => {
  it('detects the test command using the right package manager', () => {
    writePackageJson({ scripts: { test: 'vitest run' } });
    writeFileSync(join(dir, 'pnpm-lock.yaml'), '');
    expect(detectCommands(dir)['[TEST COMMAND]']).toBe('pnpm test');
  });

  it('defaults to npm when no lockfile is present', () => {
    writePackageJson({ scripts: { test: 'vitest run' } });
    expect(detectCommands(dir)['[TEST COMMAND]']).toBe('npm test');
  });

  it('combines typecheck and lint into one static analysis command', () => {
    writePackageJson({ scripts: { typecheck: 'tsc --noEmit', lint: 'eslint' } });
    expect(detectCommands(dir)['[STATIC ANALYSIS COMMAND]']).toBe('npm run typecheck && npm run lint');
  });

  it('prefers docker compose for the start command when a compose file exists', () => {
    writePackageJson({ scripts: { dev: 'next dev' } });
    writeFileSync(join(dir, 'compose.yaml'), 'services: {}');
    expect(detectCommands(dir)['[START COMMAND]']).toBe('docker compose up -d');
  });

  it('falls back to the dev script for the start command with no compose file', () => {
    writePackageJson({ scripts: { dev: 'next dev' } });
    expect(detectCommands(dir)['[START COMMAND]']).toBe('npm run dev');
  });

  it('leaves undetected commands absent so the caller can fall back to [MANUAL]', () => {
    writePackageJson({});
    expect(detectCommands(dir)).toEqual({});
  });
});

describe('detectPackageManager', () => {
  it('detects yarn from yarn.lock', () => {
    writeFileSync(join(dir, 'yarn.lock'), '');
    expect(detectPackageManager(dir)).toBe('yarn');
  });
});

describe('processAgentsMdContent', () => {
  it('fills in every placeholder it can detect and leaves the rest untouched', () => {
    writePackageJson({ name: 'my-app', dependencies: { next: '^16.0.0' }, scripts: { build: 'next build' } });
    const content = [
      '_Project: [PROJECT NAME] | Stack: [e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]_',
      '_MAP v1.0 | Last updated: [DATE]_',
      '- Build: `[BUILD COMMAND]`',
      '- Static analysis: `[STATIC ANALYSIS COMMAND]`',
    ].join('\n');

    const result = processAgentsMdContent(content, dir);

    expect(result).toContain('_Project: My App | Stack: Next.js 16, JavaScript_');
    expect(result).toContain(`_MAP v1.0 | Last updated: ${new Date().toISOString().slice(0, 10)}_`);
    expect(result).toContain('- Build: `npm run build`');
    expect(result).toContain('[STATIC ANALYSIS COMMAND]'); // nothing to detect — left as-is
  });

  it('is a no-op on content with no placeholders left to fill', () => {
    writePackageJson({ name: 'my-app' });
    const content = '_Project: My App | Stack: Next.js 16_';
    expect(processAgentsMdContent(content, dir)).toBe(content);
  });
});
