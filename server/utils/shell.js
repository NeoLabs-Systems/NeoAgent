'use strict';

function shellQuote(value) {
  const text = String(value ?? '');
  if (text.length === 0) return "''";
  return `'${text.replace(/'/g, `'\\''`)}'`;
}

module.exports = { shellQuote };
