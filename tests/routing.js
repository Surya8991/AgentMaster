'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const routing = require('../scripts/routing.js');
const corpus = require('./routing-cases.json');
const requirements = require('../scripts/routing-requirements.json');
const table = routing.categories();
const covered = new Set(corpus.map(item => item.expected));
assert.deepEqual([...covered].sort(), table.map(row => row.name).sort(), 'Every source category needs a benchmark case');
assert(routing.evaluate(corpus).every(row => row.pass), 'Deterministic baseline regression');
const predictions = Object.fromEntries(corpus.map(item => [item.id, item.expected]));
assert(routing.evaluate(corpus, predictions).every(row => row.pass));
predictions.build = 'Marketing';
assert.equal(routing.evaluate(corpus, predictions).filter(row => !row.pass).length, 1, 'Incorrect predictions must fail');
delete predictions.debug;
assert.equal(routing.evaluate(corpus, predictions).filter(row => !row.pass).length, 2, 'Missing predictions must fail');
assert.throws(() => routing.evaluate(corpus, { unexpected: 'Build/Create' }), /unknown case/);
assert.throws(() => routing.evaluate([...corpus, corpus[0]]), /Invalid corpus/);

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'agentmaster-routing-'));
try {
  const plugins = [...new Set(Object.values(requirements.routes).flat().filter(skill => skill.includes(':')))];
  for (const skill of [...new Set(Object.values(requirements.routes).flat().filter(skill => !skill.includes(':')))]) {
    fs.mkdirSync(path.join(tmp, skill), { recursive: true });
    fs.writeFileSync(path.join(tmp, skill, 'SKILL.md'), '---\nname: fixture\n---\n');
  }
  const unknown = routing.availability({ skillsDir: tmp, searchPath: '' });
  assert(unknown.some(row => row.requirement === 'anthropic-skills:running-marketing' && row.state === 'unknown'));
  assert(unknown.some(row => row.requirement === 'rea/reverse-engineer-anything' && row.state === 'unknown'));
  assert(unknown.some(row => row.requirement === 'dap' && row.state === 'missing'));
  const configured = routing.availability({ skillsDir: tmp, plugins, mcp: { mcpServers: { rea: { command: 'unused', env: { SECRET: 'must-never-print' } }, 'ida-pro-mcp': { disabled: true } } }, searchPath: '' });
  assert(configured.some(row => row.requirement === 'rea/reverse-engineer-anything' && row.state === 'configured'));
  assert(configured.some(row => row.requirement === 'ida-pro-mcp/ida' && row.state === 'missing'));
  assert(!JSON.stringify(configured).includes('must-never-print'));
  fs.rmSync(path.join(tmp, 'brainstorming'), { recursive: true });
  assert(routing.availability({ skillsDir: tmp, plugins: [], mcp: {}, searchPath: '' }).some(row => row.requirement === 'brainstorming' && row.state === 'missing'));
  const cli = path.resolve(__dirname, '../scripts/routing.js');
  const processResult = spawnSync(process.execPath, [cli, 'evaluate', '--json'], { encoding: 'utf8' });
  assert.equal(processResult.status, 0);
  assert.equal(JSON.parse(processResult.stdout).length, corpus.length);
  const badPredictions = path.join(tmp, 'predictions.json');
  fs.writeFileSync(badPredictions, JSON.stringify(predictions));
  assert.equal(spawnSync(process.execPath, [cli, 'evaluate', '--predictions', badPredictions]).status, 1);
} finally { fs.rmSync(tmp, { recursive: true, force: true }); }
console.log(`PASS: ${corpus.length} baseline cases, all ${table.length} categories, captured-prediction scoring, and availability diagnostics`);
