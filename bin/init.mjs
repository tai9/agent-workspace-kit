#!/usr/bin/env node
// Turns a bare workspace into one this kit can run: detects the workspace's
// shape, writes workspace.yml + the release skeleton + rules files, wires the
// hooks, and reports what it did and what still needs filling in by hand.
//
// This is the one file allowed to know about ecosystem-specific filenames
// (pubspec.yaml, shorebird.yaml) for detection purposes — see the module doc
// in ../lib for why nothing else may.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const KIT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

const argv = process.argv.slice(2);
const YES = argv.includes('--yes');
const DRY = argv.includes('--dry-run');
let ROOT = process.cwd();
{
  const i = argv.indexOf('--root');
  if (i !== -1 && argv[i + 1]) ROOT = path.resolve(argv[i + 1]);
}

const lines = []; // report lines, printed at the end in order
const fillInByHand = [];
function report(line) { lines.push(line); }

function exists(p) {
  try { fs.lstatSync(p); return true; } catch { return false; }
}
function relRoot(abs) {
  const r = path.relative(ROOT, abs);
  return r === '' ? '.' : r;
}
function sh(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, { encoding: 'utf8', ...opts });
  return r.status === 0 ? r.stdout.trim() : '';
}

// ---------------------------------------------------------------------------
// Detection
// ---------------------------------------------------------------------------

function isGitRepo(dir) { return exists(path.join(dir, '.git')); }

// Ecosystem-specific: pubspec.yaml is Flutter, nest-cli.json/prisma/ is a
// NestJS-shaped service. Kept here per the brief's ruling — nowhere else in
// the kit is allowed to look for these filenames.
function detectRole(dir) {
  if (exists(path.join(dir, 'pubspec.yaml'))) return 'release-anchor';
  if (exists(path.join(dir, 'package.json')) &&
      (exists(path.join(dir, 'nest-cli.json')) || exists(path.join(dir, 'prisma')))) {
    return 'service';
  }
  return 'other';
}

function trunkFor(gitDir) {
  let t = sh('git', ['-C', gitDir, 'symbolic-ref', 'refs/remotes/origin/HEAD']);
  if (t) t = t.replace(/^refs\/remotes\/origin\//, '');
  if (!t) t = 'main';
  const hasDevelop = sh('git', ['-C', gitDir, 'branch', '--list', 'develop']);
  if (hasDevelop.trim()) t = 'develop';
  return t;
}
function currentBranch(gitDir) {
  return sh('git', ['-C', gitDir, 'rev-parse', '--abbrev-ref', 'HEAD']) || '';
}

// Longest common prefix across all names, trimmed back to a "-"/"_"
// boundary, so "viespeak-app"/"viespeak-be" -> "app"/"be" but a prefix with
// no separator boundary is left alone (never strips mid-word).
function shortKeys(names) {
  if (names.length < 2) return names.slice();
  let prefix = names[0];
  for (const n of names.slice(1)) {
    let i = 0;
    while (i < prefix.length && i < n.length && prefix[i] === n[i]) i++;
    prefix = prefix.slice(0, i);
    if (!prefix) break;
  }
  const lastSep = Math.max(prefix.lastIndexOf('-'), prefix.lastIndexOf('_'));
  prefix = lastSep >= 0 ? prefix.slice(0, lastSep + 1) : '';
  if (!prefix) return names.slice();
  const stripped = names.map((n) => n.slice(prefix.length));
  if (stripped.some((s) => !s)) return names.slice();
  return stripped;
}

function detect(root) {
  const gitAtRoot = isGitRepo(root);
  const children = fs.readdirSync(root, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith('.') && d.name !== 'node_modules')
    .map((d) => d.name)
    .sort();
  const siblingRepoNames = children.filter((c) => isGitRepo(path.join(root, c)));
  const shape = (gitAtRoot && siblingRepoNames.length === 0) ? 'monorepo' : 'multi-repo';

  let candidateNames;
  if (shape === 'monorepo') {
    candidateNames = children.filter((c) => detectRole(path.join(root, c)) !== 'other');
    if (candidateNames.length === 0 && children.length > 0) {
      // Nothing recognisable — fall back to the first directory so init has
      // somewhere to anchor a release, reported below as a thing to check.
      candidateNames = [children[0]];
    }
  } else {
    candidateNames = siblingRepoNames;
  }

  const keys = shape === 'monorepo' ? candidateNames.slice() : shortKeys(candidateNames);

  let anchorAssigned = false;
  const otherRoleFallback = [];
  const repos = candidateNames.map((name, idx) => {
    const dir = path.join(root, name);
    let role = detectRole(dir);
    if (role === 'release-anchor') {
      if (anchorAssigned) { otherRoleFallback.push(name); role = 'other'; }
      else anchorAssigned = true;
    }
    const gitDir = shape === 'monorepo' ? root : dir;
    const trunk = trunkFor(gitDir);
    let mirror;
    if (role === 'release-anchor') {
      const cur = currentBranch(gitDir);
      if (cur && cur !== trunk) mirror = cur;
    }
    return { key: keys[idx], name, path: name, dir, gitDir, role, trunk, mirror };
  });

  let anchor = repos.find((r) => r.role === 'release-anchor');
  let noRecognisedAnchor = false;
  if (!anchor && repos.length > 0) {
    anchor = repos[0];
    anchor.role = 'release-anchor';
    noRecognisedAnchor = true;
  } else if (!anchor) {
    // No candidate directories at all (degenerate workspace). Anchor the
    // workspace root itself so there is still something to release.
    noRecognisedAnchor = true;
    anchor = { key: path.basename(root) || 'workspace', name: '.', path: '.', dir: root, gitDir: root, role: 'release-anchor', trunk: trunkFor(root) };
    repos.push(anchor);
  }

  const pubspec = path.join(anchor.dir, 'pubspec.yaml');
  let adapter, anchorFile, shorebirdMissing = false;
  if (exists(pubspec)) {
    adapter = 'flutter-shorebird';
    anchorFile = `${anchor.path}/pubspec.yaml`.replace(/^\.\//, '');
    shorebirdMissing = !exists(path.join(anchor.dir, 'shorebird.yaml'));
  } else {
    adapter = 'generic-semver';
    anchorFile = `${anchor.path}/VERSION`.replace(/^\.\//, '');
  }

  return { shape, repos, anchor, adapter, anchorFile, shorebirdMissing, noRecognisedAnchor, otherRoleFallback };
}

// ---------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------

async function withReadline(fn) {
  if (YES) return fn(null);
  const { createInterface } = await import('node:readline/promises');
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try { return await fn(rl); } finally { rl.close(); }
}
async function ask(rl, question, def) {
  if (!rl) return def;
  const ans = (await rl.question(`${question} [${def}]: `)).trim();
  return ans || def;
}

// ---------------------------------------------------------------------------
// Writers
// ---------------------------------------------------------------------------

function planWrite(relPath, content, { mode } = {}) {
  const abs = path.join(ROOT, relPath);
  if (exists(abs)) { report(`  exists, left alone  ${relPath}`); return false; }
  if (DRY) { report(`  would write          ${relPath}`); return false; }
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, content);
  if (mode) fs.chmodSync(abs, mode);
  report(`  wrote                ${relPath}`);
  return true;
}

function planSymlink(relPath, target) {
  const abs = path.join(ROOT, relPath);
  if (exists(abs)) { report(`  exists, left alone  ${relPath}`); return false; }
  if (DRY) { report(`  would symlink        ${relPath} -> ${target}`); return false; }
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.symlinkSync(target, abs);
  report(`  symlinked            ${relPath} -> ${target}`);
  return true;
}

function planAppendGitignore(dirAbs) {
  const abs = path.join(dirAbs, '.gitignore');
  const wantLines = ['.claude/worktrees/', '.claude/settings.local.json'];
  const relPath = relRoot(abs);
  let current = exists(abs) ? fs.readFileSync(abs, 'utf8') : '';
  const currentLines = new Set(current.split('\n').map((l) => l.trim()).filter(Boolean));
  const missing = wantLines.filter((l) => !currentLines.has(l));
  if (missing.length === 0) { report(`  exists, left alone  ${relPath}`); return; }
  if (DRY) { report(`  would append         ${relPath}`); return; }
  const sep = current.length && !current.endsWith('\n') ? '\n' : '';
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, current + sep + missing.join('\n') + '\n');
  report(`  ${current ? 'appended' : 'wrote   '}             ${relPath}`);
}

// The one file that merges instead of skip-or-write: adds the two stub hook
// entries and worktree.bgIsolation if missing, leaves everything else in
// place. Comparing on the literal `command` string is what makes a re-run a
// no-op instead of a duplicate entry.
function mergeSettings(dirAbs) {
  const abs = path.join(dirAbs, '.claude', 'settings.json');
  const relPath = relRoot(abs);
  const preCmd = '$CLAUDE_PROJECT_DIR/.claude/hooks/workspace-guards.sh';
  const startCmd = '$CLAUDE_PROJECT_DIR/.claude/hooks/workspace-guards.sh session-start';
  let json = {};
  let existed = exists(abs);
  if (existed) {
    try { json = JSON.parse(fs.readFileSync(abs, 'utf8')); } catch { json = {}; }
  }
  let changed = !existed;
  json.worktree = json.worktree || {};
  if (json.worktree.bgIsolation === undefined) { json.worktree.bgIsolation = 'none'; changed = true; }
  json.hooks = json.hooks || {};
  json.hooks.PreToolUse = json.hooks.PreToolUse || [];
  json.hooks.SessionStart = json.hooks.SessionStart || [];
  const hasCmd = (arr, cmd) => arr.some((entry) => (entry.hooks || []).some((h) => h.command === cmd));
  if (!hasCmd(json.hooks.PreToolUse, preCmd)) {
    json.hooks.PreToolUse.push({ matcher: 'Bash', hooks: [{ type: 'command', command: preCmd }] });
    changed = true;
  }
  if (!hasCmd(json.hooks.SessionStart, startCmd)) {
    json.hooks.SessionStart.push({ hooks: [{ type: 'command', command: startCmd }] });
    changed = true;
  }
  if (!changed) { report(`  exists, left alone  ${relPath}`); return; }
  if (DRY) { report(`  would ${existed ? 'merge  ' : 'write  '}       ${relPath}`); return; }
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, JSON.stringify(json, null, 2) + '\n');
  report(`  ${existed ? 'merged               ' : 'wrote                '}${relPath}`);
}

function copyStub(dirAbs) {
  const abs = path.join(dirAbs, '.claude', 'hooks', 'workspace-guards.sh');
  const relPath = relRoot(abs);
  if (exists(abs)) { report(`  exists, left alone  ${relPath}`); return; }
  if (DRY) { report(`  would write          ${relPath}`); return; }
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.copyFileSync(path.join(KIT, 'hooks', 'workspace-guards.stub.sh'), abs);
  fs.chmodSync(abs, 0o755);
  report(`  wrote                ${relPath}`);
}

// ---------------------------------------------------------------------------
// workspace.yml
// ---------------------------------------------------------------------------

const STORE_PATHS = "[android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]";

function renderWorkspaceYml(cfg) {
  const { name, shape, repos, adapter, anchorFile } = cfg;
  const out = [];
  out.push(`name: ${name}`);
  out.push(`shape: ${shape}`);
  if (shape === 'monorepo') out.push(`trunk: ${cfg.trunk}`);
  out.push('repos:');
  for (const r of repos) {
    const parts = [`path: ${r.path}`];
    if (shape === 'multi-repo') parts.push(`trunk: ${r.trunk}`);
    parts.push(`role: ${r.role}`);
    if (r.mirror) parts.push(`mirror: ${r.mirror}`);
    out.push(`  ${r.key}: { ${parts.join(', ')} }`);
  }
  out.push('release:');
  out.push(`  adapter: ${adapter}`);
  out.push(`  anchor_file: ${anchorFile}`);
  out.push('  tag: "released/{version}"');
  out.push(`  store_paths: ${adapter === 'flutter-shorebird' ? STORE_PATHS : '[]'}`);
  out.push('  contract_paths: []');
  out.push('contracts: []');
  out.push('');
  return out.join('\n');
}

function simpleDiff(oldText, newText) {
  const a = oldText.split('\n');
  const b = newText.split('\n');
  const out = [];
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    if (a[i] === b[i]) continue;
    if (a[i] !== undefined) out.push(`- ${a[i]}`);
    if (b[i] !== undefined) out.push(`+ ${b[i]}`);
  }
  return out;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

async function main() {
  if (!exists(ROOT)) { console.error(`init: no such directory: ${ROOT}`); process.exit(1); }

  const d = detect(ROOT);

  await withReadline(async (rl) => {
    d.name = await ask(rl, 'Workspace name', path.basename(ROOT));
    report(`shape: ${d.shape}`);
    for (const r of d.repos) {
      const role = await ask(rl, `Role for ${r.path}`, r.role);
      r.role = role;
    }
    const anchor = d.repos.find((r) => r.role === 'release-anchor') || d.anchor;
    anchor.trunk = await ask(rl, `Trunk for ${anchor.path}`, anchor.trunk);
  });
  if (d.shape === 'monorepo') d.trunk = d.anchor.trunk;

  report(`\nDetected: ${d.shape} workspace, ${d.repos.length} repo(s), anchor ${d.anchor.path} (${d.adapter})\n`);
  report('Writing:');

  // -- workspace.yml: never overwritten -------------------------------------
  const wsAbs = path.join(ROOT, 'workspace.yml');
  const wsContent = renderWorkspaceYml(d);
  if (exists(wsAbs)) {
    report('workspace.yml exists — here is the diff against what init would generate now:');
    const existing = fs.readFileSync(wsAbs, 'utf8');
    const diff = simpleDiff(existing, wsContent);
    if (diff.length === 0) report('  (no difference)');
    else for (const l of diff) report(`  ${l}`);
  } else if (DRY) {
    report('  would write          workspace.yml');
  } else {
    fs.writeFileSync(wsAbs, wsContent);
    report('  wrote                workspace.yml');
  }

  // -- release skeleton -------------------------------------------------------
  const trunkForInventory = d.shape === 'monorepo' ? d.trunk : d.anchor.trunk;
  const unreleased = fs.readFileSync(path.join(KIT, 'templates', 'releases', 'UNRELEASED.md'), 'utf8')
    .replaceAll('{{NAME}}', d.name).replaceAll('{{TRUNK}}', trunkForInventory);
  planWrite('releases/UNRELEASED.md', unreleased);

  const releaseProcess = fs.readFileSync(path.join(KIT, 'templates', 'releases', 'RELEASE_PROCESS.md'), 'utf8')
    .replaceAll('{{NAME}}', d.name);
  planWrite('releases/RELEASE_PROCESS.md', releaseProcess);

  planWrite('releases/_TEMPLATE.base.md', fs.readFileSync(path.join(KIT, 'templates', 'releases', '_TEMPLATE.base.md'), 'utf8'));
  planWrite('releases/_TEMPLATE.patch.md', fs.readFileSync(path.join(KIT, 'templates', 'releases', '_TEMPLATE.patch.md'), 'utf8'));
  planWrite('docs/cross-repo-contracts.md', fs.readFileSync(path.join(KIT, 'templates', 'cross-repo-contracts.md'), 'utf8'));

  // -- rules files: workspace root -------------------------------------------
  const rootClaude = path.join(ROOT, 'CLAUDE.md');
  const rootAgents = path.join(ROOT, 'AGENTS.md');
  if (!exists(rootClaude) && !exists(rootAgents)) {
    const claudeContent = fs.readFileSync(path.join(KIT, 'templates', 'CLAUDE.md'), 'utf8').replaceAll('{{NAME}}', d.name);
    planWrite('CLAUDE.md', claudeContent);
  } else {
    report(`  exists, left alone  CLAUDE.md`);
  }
  if (!exists(rootAgents)) planSymlink('AGENTS.md', 'CLAUDE.md');
  else report('  exists, left alone  AGENTS.md');

  // -- rules files: every repo in a multi-repo workspace (the ruling) --------
  // The doctor requires a rules file in EVERY repo, not just the workspace
  // root. A repo's own CLAUDE.md stays short — it points at the workspace's,
  // rather than repeating it.
  if (d.shape === 'multi-repo') {
    for (const r of d.repos) {
      const repoClaude = path.join(r.dir, 'CLAUDE.md');
      const repoAgents = path.join(r.dir, 'AGENTS.md');
      if (!exists(repoClaude) && !exists(repoAgents)) {
        const relToRoot = path.relative(r.dir, rootClaude).split(path.sep).join('/');
        const content = `# ${r.path}\n\nRules for this repo live at the workspace root: see [\`${relToRoot}\`](${relToRoot})\n(symlinked here as \`AGENTS.md\` too, so both readers land on the same file).\n`;
        planWrite(path.join(r.path, 'CLAUDE.md'), content);
      } else {
        report(`  exists, left alone  ${r.path}/CLAUDE.md`);
      }
      if (!exists(repoAgents)) planSymlink(path.join(r.path, 'AGENTS.md'), 'CLAUDE.md');
      else report(`  exists, left alone  ${r.path}/AGENTS.md`);
    }
  }

  // -- .claude/settings.json + hooks/workspace-guards.sh ----------------------
  // Root always gets both. In a multi-repo workspace, every guarded repo gets
  // its own byte copy of the stub (a session opened inside it never sees the
  // workspace's own settings.json) plus its own settings.json. A monorepo has
  // one settings.json and no relay, so that loop does not run there.
  mergeSettings(ROOT);
  copyStub(ROOT);
  if (d.shape === 'multi-repo') {
    for (const r of d.repos) {
      mergeSettings(r.dir);
      copyStub(r.dir);
    }
  }

  // -- .agents/skills symlink --------------------------------------------------
  if (exists(path.join(ROOT, '.claude', 'skills'))) {
    if (!exists(path.join(ROOT, '.agents', 'skills'))) planSymlink('.agents/skills', '../.claude/skills');
    else report('  exists, left alone  .agents/skills');
  }

  // -- .gitignore: root, and every repo in multi-repo --------------------------
  planAppendGitignore(ROOT);
  if (d.shape === 'multi-repo') {
    for (const r of d.repos) planAppendGitignore(r.dir);
  }

  // -- git hooks ----------------------------------------------------------------
  if (!DRY) {
    const r = spawnSync('bash', [path.join(KIT, 'bin', 'install-git-hooks')], {
      cwd: ROOT, env: { ...process.env, WORKSPACE_ROOT: ROOT }, encoding: 'utf8',
    });
    report('\ninstall-git-hooks:');
    for (const l of (r.stdout || '').split('\n')) if (l) report(`  ${l}`);
    if (r.stderr) for (const l of r.stderr.split('\n')) if (l) report(`  ${l}`);
  } else {
    report('\n  would run            bin/install-git-hooks');
  }

  // -- fill-in-by-hand ------------------------------------------------------
  fillInByHand.push('contracts: in workspace.yml — list each cross-repo contract and the paths that mark it touched');
  fillInByHand.push('the contract table in CLAUDE.md — one row per contract from workspace.yml');
  fillInByHand.push('preflight.base_url_from in workspace.yml — e.g. env:BACKEND_URL@backend/.env.{env}');
  if (d.adapter === 'flutter-shorebird' && d.shorebirdMissing) {
    fillInByHand.push(`Shorebird is not initialised in ${d.anchor.path}; see the runbook`);
  }
  if (d.noRecognisedAnchor) {
    fillInByHand.push(`no repo looked like a release anchor (no pubspec.yaml found) — ${d.anchor.path} was picked by default; check release.adapter and release.anchor_file in workspace.yml`);
  }
  if (d.otherRoleFallback.length) {
    fillInByHand.push(`more than one repo looked like a release anchor; only ${d.anchor.path} was kept, the rest (${d.otherRoleFallback.join(', ')}) were set to role: other — check workspace.yml`);
  }

  process.stdout.write(lines.join('\n') + '\n');

  if (fillInByHand.length) {
    process.stdout.write('\nFill in by hand:\n');
    for (const item of fillInByHand) process.stdout.write(`  - ${item}\n`);
  }

  if (DRY) process.stdout.write('\n(--dry-run: nothing was written)\n');
}

main().catch((e) => { console.error(e); process.exit(1); });
