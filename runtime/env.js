'use strict';

function parseEnv(raw) {
  const map = new Map();
  for (const line of String(raw ?? '').split(/\r?\n/)) {
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const idx = line.indexOf('=');
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1);
    if (key) map.set(key, value);
  }
  return map;
}

module.exports = {
  parseEnv,
};
