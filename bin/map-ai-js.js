#!/usr/bin/env node
import { runDoctor, runInstall } from '../src/cli.js';

const USAGE = `Usage: map-ai-js <command> [path] [options]

Commands:
  install [path] [--force]              Install the MAP scaffold into [path] (default: cwd)
                                         --force overwrites existing SCAFFOLD_FILES (backed up to <file>.bak first)
  doctor [path] [--fix|--interactive]   Report on drift from the current template
                                         --fix applies safe repairs unattended
                                         --interactive confirms each file's changes before applying

[path] defaults to the current directory for both commands.`;

const [, , command, ...rest] = process.argv;

switch (command) {
  case 'install':
    runInstall(rest);
    break;
  case 'doctor':
    runDoctor(rest);
    break;
  case undefined:
  case '--help':
  case '-h':
    console.log(USAGE);
    break;
  default:
    console.error(`Unknown command: ${command}\n`);
    console.error(USAGE);
    process.exitCode = 1;
}
