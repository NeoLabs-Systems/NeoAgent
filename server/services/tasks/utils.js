'use strict';

function normalizeJsonObject(value, fallback = {}) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return { ...fallback, ...value };
  }
  try {
    const parsed = JSON.parse(String(value || '{}'));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? { ...fallback, ...parsed }
      : { ...fallback };
  } catch {
    return { ...fallback };
  }
}

function stringifyJson(value) {
  const normalized = normalizeJsonObject(value);
  try {
    return JSON.stringify(normalized);
  } catch {
    try {
      const seen = new WeakSet();
      return JSON.stringify(normalized, (_key, currentValue) => {
        if (typeof currentValue === 'bigint') {
          return currentValue.toString();
        }
        if (currentValue && typeof currentValue === 'object') {
          if (seen.has(currentValue)) {
            return '[Circular]';
          }
          seen.add(currentValue);
        }
        return currentValue;
      });
    } catch {
      return JSON.stringify(String(value));
    }
  }
}

module.exports = {
  normalizeJsonObject,
  stringifyJson,
};
