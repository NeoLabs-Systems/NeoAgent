'use strict';

const { createHash } = require('crypto');
const fs = require('fs');
const path = require('path');

// Prompts are data: one versioned file per fragment. Changing a fragment's text
// means bumping its version, because evals and run metrics compare by version.
// There is no prompt language and no model picking prompts; a fragment is either
// active for this run's context or it is not.

function parseFragment(relativePath) {
  const raw = fs.readFileSync(path.join(__dirname, relativePath), 'utf8');
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) throw new Error(`Prompt fragment ${relativePath} has no header.`);
  const header = Object.fromEntries(match[1].split('\n').map((line) => {
    const index = line.indexOf(':');
    return [line.slice(0, index).trim(), line.slice(index + 1).trim()];
  }));
  return { id: header.id, version: Number(header.version), text: match[2].trim() };
}

// Stable fragments form the cacheable head of every prompt, in this order, so a
// change in what follows them cannot invalidate the provider's prompt cache.
const STABLE_FRAGMENTS = [
  { file: 'base/behavior.md' },
  { file: 'base/tools.md' },
  { file: 'base/quick_actions.md' },
  { file: 'base/external_actions.md' },
  { file: 'base/security.md' },
  { file: 'capabilities/voice_task.md', activateWhen: (ctx) => ctx.triggerSource === 'voice_live' },
  { file: 'capabilities/messaging.md', activateWhen: (ctx) => ctx.triggerSource === 'messaging' },
];

const fragmentsByFile = new Map();
const fragmentsById = new Map();

function loadFragment(file) {
  if (!fragmentsByFile.has(file)) {
    const fragment = parseFragment(file);
    fragmentsByFile.set(file, fragment);
    fragmentsById.set(fragment.id, fragment);
  }
  return fragmentsByFile.get(file);
}

function selectStableFragments(context = {}) {
  return STABLE_FRAGMENTS
    .filter((entry) => !entry.activateWhen || entry.activateWhen(context))
    .map((entry) => loadFragment(entry.file));
}

// A runtime fragment is text the harness hands the model at one specific moment.
function renderFragment(file, values = {}) {
  const { text } = loadFragment(file);
  return text.replace(/\{\{(\w+)\}\}/g, (_, key) => String(values[key] ?? ''));
}

// Names exactly which prompt text a run saw, for comparing runs and evals.
function promptVersion(fragments) {
  const list = fragments.map((fragment) => `${fragment.id}@${fragment.version}`);
  return {
    fragments: list,
    digest: createHash('sha256').update(list.join('\n')).digest('hex').slice(0, 16),
  };
}

module.exports = {
  promptVersion,
  renderFragment,
  selectStableFragments,
};
