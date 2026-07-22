'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { test } = require('node:test');

const { attachRequestSignal } = require('../../../server/http/middleware');

test('HTTP request signal aborts when the client disconnects', () => {
  const req = new EventEmitter();
  const res = new EventEmitter();
  res.writableEnded = false;
  let nextCalled = false;

  attachRequestSignal(req, res, () => { nextCalled = true; });
  req.emit('aborted');

  assert.equal(nextCalled, true);
  assert.equal(req.signal.aborted, true);
  assert.equal(req.signal.reason?.code, 'ABORT_ERR');
});

test('HTTP request signal listeners are removed after a normal response', () => {
  const req = new EventEmitter();
  const res = new EventEmitter();
  res.writableEnded = true;

  attachRequestSignal(req, res, () => {});
  res.emit('finish');
  res.emit('close');

  assert.equal(req.signal.aborted, false);
  assert.equal(req.listenerCount('aborted'), 0);
  assert.equal(res.listenerCount('close'), 0);
});
