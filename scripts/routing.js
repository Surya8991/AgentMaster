#!/usr/bin/env node
'use strict';
// Offline routing diagnostics. The deterministic baseline is not the LLM router.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const root = path.resolve(__dirname, '..');
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const sourcePath = path.join(root, 'skills/agent-master/SKILL.md');
function categories(source = fs.readFileSync(sourcePath, 'utf8')) {
  const section = source.split('## Step 1: Classify the Task')[1]?.split('### Conflict Resolution')[0];
  if (!section) throw new Error('Routing source table not found');
  return section.split('\n').filter(line => line.startsWith('| **')).map(line => {
    const cells = line.split('|').slice(1, -1).map(cell => cell.trim());
    return { name: cells[0].replaceAll('**', ''), signals: cells[1].split(',').map(s => s.trim()), text: line };
  });
}
const overrides = [
  [/\b(rag|llm app|ai app|embeddings|langchain|llamaindex|agent pipeline)\b/i, 'LLM/AI App Dev'],
  [/\b(marketing review|content review|fix copy|fix messaging|a\/b test)\b/i, 'Marketing'],
  [/\b(product roadmap|feature roadmap|user test|sprint planning for features|what to build next sprint)\b/i, 'Product'],
  [/\b(sales pipeline|revenue pipeline)\b/i, 'Business Growth'],
  [/\b(security audit|vulnerability scan|dependency scan)\b/i, 'Security'],
  [/\b(code audit|git history|commit history)\b/i, 'Code Review'],
  [/\b(security compliance|soc2)\b/i, 'Compliance'],
  [/\b(build landing page|implement landing page|container component|system design|database design|document the code|add jsdoc)\b/i, 'Build/Create'],
  [/\b(plan the sprint|sprint)\b/i, 'Project Mgmt'],
  [/\broadmap\b/i, 'Strategy/Business'],
  [/\b(analyze this binary|decompile|disassemble)\b/i, 'Reverse Engineering / Binary Analysis'],
  [/\b(explore this repo|explore the code|analyze the codebase)\b/i, 'Explore Codebase'],
  [/\b(explore options|explore ideas)\b/i, 'Build/Create'],
];
function baseline(prompt, table = categories()) {
  for (const [pattern, category] of overrides) {
    if (pattern.test(prompt)) return category;
  }
  const matches = [];
  for (const row of table) {
    if (row.name === 'Simple Question') continue;
    for (const signal of row.signals) {
      const escaped = signal.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      if (new RegExp(`(?:^|\\W)${escaped}(?:$|\\W)`, 'i').test(prompt)) {
        matches.push({ category: row.name, length: signal.length });
      }
    }
  }
  matches.sort((a, b) => b.length - a.length);
  return matches[0]?.category || 'Simple Question';
}
function evaluate(corpus, predictions) {
  const table = categories();
  const names = new Set(table.map(row => row.name));
  const seen = new Set();
  for (const item of corpus) {
    if (seen.has(item.id) || typeof item.prompt !== 'string' || !names.has(item.expected)) throw new Error(`Invalid corpus case: ${item.id}`);
    seen.add(item.id);
  }
  if (predictions) {
    if (typeof predictions !== 'object' || Array.isArray(predictions)) throw new Error('Predictions must be an object mapping case IDs to category names');
    if (Object.keys(predictions).some(id => !seen.has(id))) throw new Error('Predictions contain unknown case IDs');
  }
  return corpus.map(item => ({ ...item, actual: predictions ? predictions[item.id] ?? null : baseline(item.prompt, table) }))
    .map(item => ({ ...item, pass: item.actual === item.expected }));
}
function installed(dir, name) {
  return fs.existsSync(path.join(dir, name, 'SKILL.md')) || fs.existsSync(path.join(dir, name, 'skill.md'));
}
function availability({ skillsDir = path.join(os.homedir(), '.claude/skills'), plugins, mcp, searchPath = process.env.PATH || '' } = {}) {
  const requirements = readJson(path.join(__dirname, 'routing-requirements.json'));
  const table = categories();
  const names = new Set(table.map(row => row.name));
  if (names.size !== Object.keys(requirements.routes).length) throw new Error('Availability registry category count differs from source');
  const rows = [];
  for (const [category, skills] of Object.entries(requirements.routes)) {
    const source = table.find(row => row.name === category);
    if (!names.has(category)) throw new Error(`Unknown availability category: ${category}`);
    for (const skill of skills) {
      if (!source.text.includes(skill)) throw new Error(`Availability registry is stale: ${category}/${skill}`);
      const external = skill.includes(':');
      const state = external ? (plugins ? (plugins.includes(skill) ? 'available' : 'missing') : 'unknown') : (installed(skillsDir, skill) ? 'available' : 'missing');
      rows.push({ category, requirement: skill, state, detail: external ? 'Plugin inventory; use --plugins to supply currently loaded skill names' : 'Skill file presence only; not a runtime health check' });
    }
  }
  for (const tool of requirements.tools) {
    if (!installed(skillsDir, tool.skill)) continue;
    let state, detail;
    if (tool.command) {
      const extensions = process.platform === 'win32' ? ['', '.exe', '.cmd', '.bat'] : [''];
      const found = searchPath.split(path.delimiter).filter(Boolean).some(dir => extensions.some(ext => {
        try {
          const file = path.join(dir, tool.command + ext);
          return fs.statSync(file).isFile() && (process.platform === 'win32' || (fs.accessSync(file, fs.constants.X_OK), true));
        } catch { return false; }
      }));
      state = found ? 'available' : 'missing'; detail = 'Executable presence only; not executed';
    } else {
      const servers = mcp && (mcp.mcpServers || mcp.servers);
      const config = servers && tool.serverNames.map(name => servers[name]).find(Boolean);
      state = !mcp ? 'unknown' : (config && config.disabled !== true ? 'configured' : 'missing');
      detail = 'MCP configuration only; server reachability and native providers remain unverified';
    }
    rows.push({ category: tool.skill, requirement: tool.command || tool.serverNames.join('/'), state, detail });
  }
  return rows;
}
function main(args) {
  const command = args.shift();
  if (!command || ['--help', '-h'].includes(command)) {
    console.log('Usage: node scripts/routing.js baseline <prompt> | evaluate [--predictions file] | availability [--skills-dir path] [--plugins file] [--mcp-config file] [--json]');
    console.log('Offline deterministic baseline tests routing signals, not LLM accuracy. Evaluate captured model predictions to measure the actual router.');
    return 0;
  }
  if (command === 'baseline') { console.log(baseline(args.join(' '))); return 0; }
  if (!['evaluate', 'availability'].includes(command)) throw new Error(`Unknown command: ${command}`);
  const options = {};
  const allowed = command === 'evaluate' ? ['--predictions'] : ['--skills-dir', '--plugins', '--mcp-config'];
  while (args.length) {
    const key = args.shift();
    if (key === '--json') { options.json = true; continue; }
    if (!allowed.includes(key) || !args.length) throw new Error(`Unknown or incomplete option: ${key}`);
    options[key] = args.shift();
  }
  if (command === 'evaluate') {
    const result = evaluate(readJson(path.join(root, 'tests/routing-cases.json')), options['--predictions'] ? readJson(options['--predictions']) : undefined);
    console.log(options.json ? JSON.stringify(result, null, 2) : result.map(r => `${r.pass ? 'PASS' : 'FAIL'} ${r.id}: expected ${r.expected}; got ${r.actual}`).join('\n'));
    if (!options.json) console.log(`${result.filter(r => r.pass).length}/${result.length} passed (${options['--predictions'] ? 'captured predictions' : 'deterministic baseline; not LLM accuracy'})`);
    return result.some(r => !r.pass) ? 1 : 0;
  }
  if (command === 'availability') {
    const plugins = options['--plugins'] ? readJson(options['--plugins']) : undefined;
    if (plugins && (!Array.isArray(plugins) || plugins.some(p => typeof p !== 'string'))) throw new Error('Plugin inventory must be an array of fully qualified skill names');
    const mcp = options['--mcp-config'] ? readJson(options['--mcp-config']) : undefined;
    if (options['--mcp-config'] && (!mcp || Array.isArray(mcp) || typeof mcp !== 'object')) throw new Error('MCP configuration must be a JSON object');
    const rows = availability({ skillsDir: options['--skills-dir'], plugins, mcp });
    console.log(options.json ? JSON.stringify(rows, null, 2) : rows.map(row => `${row.state.toUpperCase()} ${row.category}: ${row.requirement} (${row.detail})`).join('\n'));
    return rows.some(row => row.state === 'missing') ? 1 : 0;
  }
  throw new Error(`Unknown command: ${command}`);
}
module.exports = { categories, baseline, evaluate, availability, main };
if (require.main === module) {
  try { process.exitCode = main(process.argv.slice(2)); }
  catch (error) { console.error(`Routing check failed: ${error.message}`); process.exitCode = 2; }
}
