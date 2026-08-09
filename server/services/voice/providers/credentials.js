'use strict';

const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../../runtime/paths');
const { decryptLocalValue } = require('../../../utils/local_secrets');

function resolveApiKey(candidates = [], override = '') {
  const explicit = String(override || '').trim();
  if (explicit) return explicit;
  for (const key of candidates) {
    const value = String(process.env[key] || '').trim();
    if (value) return value;
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(path.join(AGENT_DATA_DIR, 'API_KEYS.json'), 'utf8'));
    for (const key of candidates) {
      for (const variant of [key, key.toLowerCase()]) {
        const value = String(decryptLocalValue(parsed[variant]) || '').trim();
        if (value) return value;
      }
    }
  } catch {
    return '';
  }
  return '';
}

function requireApiKey(label, candidates, override = '') {
  const key = resolveApiKey(candidates, override);
  if (!key) throw new Error(`${label} is selected but ${candidates[0]} is not configured.`);
  return key;
}

module.exports = {
  requireApiKey,
  resolveApiKey,
};
