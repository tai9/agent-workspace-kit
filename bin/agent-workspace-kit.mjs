#!/usr/bin/env node
// The one dispatcher a person actually types. Routes a subcommand to the
// script that implements it and exits with that child's own exit code.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const [cmd, ...rest] = process.argv.slice(2);

const table = {
  init: ['node', path.join(here, 'init.mjs')],
  doctor: ['bash', path.join(here, 'doctor')],
  check: ['bash', path.join(here, 'check')],
  live: ['bash', path.join(here, 'release-live')],
  'contract-check': ['bash', path.join(here, 'contract-check')],
  'install-git-hooks': ['bash', path.join(here, 'install-git-hooks')],
};

let target;
let args = rest;
if (cmd === 'release') {
  const sub = rest[0];
  args = rest.slice(1);
  if (['add', 'status', 'preflight', 'cut'].includes(sub)) {
    target = ['bash', path.join(here, `release-${sub}`)];
  }
} else {
  target = table[cmd];
}

if (!target) {
  console.log(`usage: agent-workspace-kit <command>
  init [--yes] [--dry-run] [--root <dir>]   set a workspace up
  doctor                                     report drift
  check                                      shellcheck + tests + doctor
  release add|status|preflight|cut           the release inventory and ship
  live <version> [...]                       report/apply a build going live
  contract-check [<repo>] [<base>]           which cross-repo contracts a diff touches
  install-git-hooks [--dry-run]              (re)install the workspace git hooks`);
  process.exit(cmd ? 2 : 0);
}

const r = spawnSync(target[0], [...target.slice(1), ...args], { stdio: 'inherit' });
process.exit(r.status ?? 1);
