// cli.js — thin wrapper around the vendored install.sh/doctor.sh. All
// diff/patch/copy logic lives in those scripts (kept in sync with
// larablocks/map-ai via scripts/sync-from-map-ai.sh) — this file only adds
// what genuinely needs to be JS-native: reading package.json to auto-fill
// AGENTS.md's placeholders, mirroring map-ai-laravel's ProcessesStubContent.

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { detectCommands, detectProjectInfo, processAgentsMdContent } from './detect.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const VENDOR_DIR = join(__dirname, '..', 'vendor');

function runVendoredScript(scriptName, args) {
  const scriptPath = join(VENDOR_DIR, scriptName);
  return spawnSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
}

const INFO_LABELS = {
  '[PROJECT NAME]': 'Project name',
  '[e.g. Laravel 13, PHP 8.5, PostgreSQL 16, Redis]': 'Stack',
};

const COMMAND_LABELS = {
  '[TEST COMMAND]': 'Tests',
  '[STATIC ANALYSIS COMMAND]': 'Static analysis',
  '[START COMMAND]': 'Start services',
  '[BUILD COMMAND]': 'Build',
};

function printDetection(target) {
  console.log('');
  console.log('Auto-detecting project info and commands for AGENTS.md...');
  console.log('');

  const detected = { ...detectProjectInfo(target), ...detectCommands(target) };

  for (const [placeholder, label] of [...Object.entries(INFO_LABELS)]) {
    console.log(
      detected[placeholder] ? `  [DETECTED]  ${label}: ${detected[placeholder]}` : `  [MANUAL]    ${label}: fill in manually`
    );
  }

  console.log('');

  for (const [placeholder, label] of [...Object.entries(COMMAND_LABELS)]) {
    console.log(
      detected[placeholder] ? `  [DETECTED]  ${label}: ${detected[placeholder]}` : `  [MANUAL]    ${label}: fill in manually`
    );
  }
}

/**
 * Runs vendor/install.sh, then — if it left [PROJECT NAME]/[DATE]/command
 * placeholders in AGENTS.md — fills in what package.json lets us detect.
 * Safe to run every time: substitution is a no-op once a placeholder's
 * already been replaced, so re-running install never overwrites real content.
 */
export function runInstall(args) {
  const target = args.find((a) => !a.startsWith('-')) ?? process.cwd();
  const installArgs = [target, ...args.filter((a) => a === '--force')];

  const result = runVendoredScript('install.sh', installArgs);
  if (result.status !== 0) {
    process.exitCode = result.status ?? 1;
    return;
  }

  const agentsPath = join(target, 'AGENTS.md');
  if (!existsSync(agentsPath)) return;

  const original = readFileSync(agentsPath, 'utf8');
  const processed = processAgentsMdContent(original, target);
  if (processed !== original) {
    writeFileSync(agentsPath, processed);
    printDetection(target);
  }
}

/** Runs vendor/doctor.sh, passing args straight through (path, --fix, --interactive). */
export function runDoctor(args) {
  const result = runVendoredScript('doctor.sh', args);
  process.exitCode = result.status ?? 0;
}
