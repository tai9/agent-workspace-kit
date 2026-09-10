#!/usr/bin/env node
// Flatten workspace.yml to key=value lines so bash reads it once with no YAML parser.
import fs from 'node:fs';
import YAML from 'yaml';
const file = process.argv[2];
if (!file) { console.error('usage: config.mjs <workspace.yml>'); process.exit(2); }
let doc;
try { doc = YAML.parse(fs.readFileSync(file, 'utf8')) ?? {}; }
catch (e) { console.error(`workspace.yml: ${e.message}`); process.exit(1); }
const out = [];
function walk(v, p) {
  if (Array.isArray(v)) { out.push(`${p}.#=${v.length}`); v.forEach((x, i) => walk(x, `${p}.${i}`)); }
  else if (v && typeof v === 'object') { for (const [k, x] of Object.entries(v)) walk(x, p ? `${p}.${k}` : k); }
  else out.push(`${p}=${v ?? ''}`);
}
walk(doc, '');
process.stdout.write(out.join('\n') + (out.length ? '\n' : ''));
