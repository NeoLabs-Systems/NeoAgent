'use strict';

// What an import did, as a Markdown file and as totals for the summary.

const fs = require('fs');
const path = require('path');
const { RUNTIME_HOME } = require('../../runtime/paths');

const STATUS_ORDER = ['imported', 'exists', 'skipped', 'failed'];
const STATUS_TITLES = {
  imported: 'Brought over',
  exists: 'Already in NeoAgent',
  skipped: 'Left behind',
  failed: 'Could not be imported',
};

// A Markdown record of every item, for later. Names only: no key values.
function writeReport(session, bundles) {
  const dir = path.join(RUNTIME_HOME, 'imports');
  fs.mkdirSync(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/:/g, '-').replace(/\.\d{3}Z$/, 'Z');
  const file = path.join(dir, `import-${stamp}.md`);
  const lines = [`# Import from ${bundles.map((bundle) => `${bundle.label} (${bundle.path})`).join(', ')}`, '', new Date().toString(), ''];
  for (const status of STATUS_ORDER) {
    const entries = session.entries.filter((entry) => entry.status === status);
    if (!entries.length) continue;
    lines.push(`## ${STATUS_TITLES[status]} (${entries.length})`, '');
    for (const entry of entries) lines.push(`- **${entry.kind}** ${entry.name}${entry.detail ? ` — ${entry.detail}` : ''}`);
    lines.push('');
  }
  fs.writeFileSync(file, lines.join('\n'), { mode: 0o600 });
  return file;
}

// Report lines → "12 memories", "3 skills": one total per kind.
const KIND_NAMES = {
  Key: ['key', 'keys'],
  Agent: ['agent', 'agents'],
  Memory: ['memory', 'memories'],
  'Daily notes': ['day of notes', 'days of notes'],
  Skill: ['skill', 'skills'],
  Model: ['model choice', 'model choices'],
  'MCP server': ['MCP server', 'MCP servers'],
  Automation: ['automation', 'automations'],
  Channel: ['chat setting', 'chat settings'],
  Setting: ['setting', 'settings'],
};

function totals(entries) {
  const byKind = new Map();
  for (const entry of entries) byKind.set(entry.kind, (byKind.get(entry.kind) || 0) + entry.count);
  return [...byKind].map(([kind, total]) => {
    const [one, many] = KIND_NAMES[kind] || [kind.toLowerCase(), `${kind.toLowerCase()}s`];
    return `${total} ${total === 1 ? one : many}`;
  });
}

module.exports = {
  totals,
  writeReport,
};
