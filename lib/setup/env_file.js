'use strict';

const { writeAtomicFile } = require('./atomic_file');

function mergeEnvText(raw, updates) {
  const pending = new Map(
    Object.entries(updates)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [String(key), String(value)]),
  );
  const updatedKeys = new Set(pending.keys());
  const seen = new Set();
  const lines = String(raw || '').split(/\r?\n/);
  const merged = [];

  for (const line of lines) {
    const match = line.match(/^([A-Z][A-Z0-9_]*)=/);
    if (!match || !updatedKeys.has(match[1])) {
      merged.push(line);
      continue;
    }
    const key = match[1];
    if (seen.has(key)) continue;
    merged.push(`${key}=${pending.get(key)}`);
    seen.add(key);
    pending.delete(key);
  }
  while (merged.length > 0 && merged[merged.length - 1] === '') merged.pop();
  for (const [key, value] of pending) merged.push(`${key}=${value}`);
  return `${merged.join('\n')}\n`;
}

function writeEnvUpdatesAtomic(envFile, raw, updates) {
  writeAtomicFile(envFile, mergeEnvText(raw, updates), { mode: 0o600 });
}

module.exports = {
  mergeEnvText,
  writeEnvUpdatesAtomic,
};
