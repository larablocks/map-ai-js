import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLI_PATH = join(__dirname, '..', 'bin', 'map-ai-js.js');

let dir;

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'map-ai-js-cli-'));
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

function runCli(args, options = {}) {
  try {
    const output = execFileSync('node', [CLI_PATH, ...args], { encoding: 'utf8', ...options });
    return { status: 0, output };
  } catch (error) {
    return { status: error.status, output: (error.stdout ?? '') + (error.stderr ?? '') };
  }
}

describe('install', () => {
  it('copies the scaffold into the target directory', () => {
    const result = runCli(['install', dir]);

    expect(result.status).toBe(0);
    expect(existsSync(join(dir, 'AGENTS.md'))).toBe(true);
    expect(existsSync(join(dir, 'docs', 'BUGS.md'))).toBe(true);
    expect(existsSync(join(dir, '.claude', 'rules', 'security.md'))).toBe(true);
  });

  it('auto-detects project name and stack from package.json into AGENTS.md', () => {
    writeFileSync(
      join(dir, 'package.json'),
      JSON.stringify({ name: 'my-cool-app', dependencies: { next: '^16.0.0' } })
    );

    runCli(['install', dir]);

    const agents = readFileSync(join(dir, 'AGENTS.md'), 'utf8');
    expect(agents).toContain('My Cool App');
    expect(agents).toContain('Next.js 16');
    expect(agents).not.toContain('[PROJECT NAME]');
  });

  it('bootstraps gitignored personal files', () => {
    runCli(['install', dir]);

    expect(existsSync(join(dir, 'docs', 'MEMORY.md'))).toBe(true);
    expect(existsSync(join(dir, 'docs', 'memory', 'gotchas.md'))).toBe(true);
  });

  it('does not overwrite an existing AGENTS.md without --force', () => {
    writeFileSync(join(dir, 'AGENTS.md'), 'my custom content');

    runCli(['install', dir]);

    expect(readFileSync(join(dir, 'AGENTS.md'), 'utf8')).toBe('my custom content');
  });
});

describe('doctor', () => {
  it('exits 1 and reports missing files on an empty project', () => {
    const result = runCli(['doctor', dir]);

    expect(result.status).toBe(1);
    expect(result.output).toContain('[FIXABLE]  missing-file');
  });

  it('exits 0 clean right after doctor --fix', () => {
    runCli(['doctor', dir, '--fix']);
    const result = runCli(['doctor', dir]);

    expect(result.status).toBe(0);
    expect(result.output).toContain('Clean');
  });
});
