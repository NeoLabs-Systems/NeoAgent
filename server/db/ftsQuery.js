'use strict';

// Shared builder for SQLite FTS5 MATCH expressions. Any code path that feeds a
// user-supplied string into a `... MATCH ?` query must route it through here:
// raw input regularly contains characters that are special in FTS5's query
// grammar and would otherwise throw at query time.
//
// Two pitfalls are handled:
//   1. Hyphens — inside a MATCH a `-` is the NOT/column operator, so a bareword
//      like `covid-19*` parses as `covid AND NOT column "19"` and throws
//      "no such column: 19". The token regex excludes `-`, splitting on it.
//   2. Bareword operators — an uppercase token such as AND/OR/NOT/NEAR is parsed
//      as an operator ("syntax error near AND"). FTS5's tokenizer is
//      case-insensitive, so lowercasing each token neutralizes the collision
//      while preserving matches.
//
// Returns a prefix-matched AND query (e.g. `covid* AND 19*`), or null when the
// input yields no usable tokens — callers should treat null as "no FTS filter".

function buildFtsQuery(query) {
  const tokens = String(query || '')
    .match(/[\p{L}\p{N}_]{2,}/gu) || [];
  if (!tokens.length) return null;
  return tokens.map((token) => `${token.toLowerCase().replace(/"/g, '')}*`).join(' AND ');
}

module.exports = { buildFtsQuery };
