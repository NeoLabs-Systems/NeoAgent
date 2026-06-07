'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const Database = require('better-sqlite3');

const { buildFtsQuery } = require('../../../server/db/ftsQuery');

// buildFtsQuery feeds an FTS5 MATCH expression. It must never emit a bare `-`,
// which FTS5 treats as the NOT/column operator (a hyphenated term like
// `covid-19` would otherwise throw "no such column: 19" and silently degrade to
// a slow, unranked LIKE fallback).

function withRuntime(fn) {
  return fn(buildFtsQuery);
}

test('buildFtsQuery splits hyphenated terms into prefix-matched AND tokens', () => {
  withRuntime((buildFtsQuery) => {
    assert.equal(buildFtsQuery('covid-19 vaccine'), 'covid* AND 19* AND vaccine*');
    assert.equal(buildFtsQuery('hello'), 'hello*');
    assert.equal(buildFtsQuery('   '), null);
    assert.equal(buildFtsQuery(''), null);
  });
});

test('buildFtsQuery never emits a bare FTS NOT/column operator', () => {
  withRuntime((buildFtsQuery) => {
    for (const input of ['covid-19', 'pre-flight check-in', 'state-of-the-art', 'utf-8 encoding']) {
      const query = buildFtsQuery(input);
      assert.ok(query, `expected a query for "${input}"`);
      assert.ok(!query.includes('-'), `query for "${input}" must not contain '-': ${query}`);
    }
  });
});

test('buildFtsQuery lowercases tokens so FTS5 operator keywords are not parsed as operators', () => {
  withRuntime((buildFtsQuery) => {
    assert.equal(buildFtsQuery('AND gates'), 'and* AND gates*');
    assert.equal(buildFtsQuery('NOT done'), 'not* AND done*');
    assert.equal(buildFtsQuery('a OR b NOT c'), 'or* AND not*');
  });
});

test('buildFtsQuery output runs against a real FTS5 table without throwing', () => {
  withRuntime((buildFtsQuery) => {
    const db = new Database(':memory:');
    db.exec('CREATE VIRTUAL TABLE docs USING fts5(content);');
    db.prepare('INSERT INTO docs(content) VALUES (?)').run('covid 19 vaccine schedule update');
    db.prepare('INSERT INTO docs(content) VALUES (?)').run('logic AND gates with OR and NOT keywords');
    db.prepare('INSERT INTO docs(content) VALUES (?)').run('unrelated general note');

    const hyphenRows = db.prepare('SELECT content FROM docs WHERE docs MATCH ? ORDER BY bm25(docs)')
      .all(buildFtsQuery('covid-19 vaccine'));
    assert.equal(hyphenRows.length, 1);
    assert.match(hyphenRows[0].content, /covid 19 vaccine/);

    // Adversarial inputs that previously threw and degraded to LIKE.
    for (const input of ['AND gates', 'OR logic', 'NOT done', 'a OR b NOT c']) {
      assert.doesNotThrow(
        () => db.prepare('SELECT count(*) c FROM docs WHERE docs MATCH ?').get(buildFtsQuery(input)),
        `MATCH should not throw for "${input}"`,
      );
    }
    db.close();
  });
});
