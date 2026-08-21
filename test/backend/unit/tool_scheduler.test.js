'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  groupToolCalls,
  scheduleToolCalls,
} = require('../../../server/services/ai/loop/tool_scheduler');

test('scheduler keeps exclusive barriers and commits parallel results in model order', async () => {
  const calls = [
    { name: 'read-a', parallel: true, delay: 20 },
    { name: 'read-b', parallel: true, delay: 1 },
    { name: 'write', parallel: false, delay: 1 },
    { name: 'read-c', parallel: true, delay: 1 },
  ];
  assert.deepEqual(
    groupToolCalls(calls, (call) => call.parallel).map((group) => ({
      kind: group.kind,
      names: group.calls.map((call) => call.name),
    })),
    [
      { kind: 'parallel', names: ['read-a', 'read-b'] },
      { kind: 'exclusive', names: ['write'] },
      { kind: 'parallel', names: ['read-c'] },
    ],
  );

  const trace = [];
  const committed = [];
  await scheduleToolCalls(calls, {
    isParallelSafe: (call) => call.parallel,
    maxParallel: 2,
    execute: async (call) => {
      trace.push(`${call.name}:start`);
      await new Promise((resolve) => setTimeout(resolve, call.delay));
      trace.push(`${call.name}:end`);
      return call.name;
    },
    commit: async (outcome) => committed.push(outcome),
  });

  assert.deepEqual(committed, ['read-a', 'read-b', 'write', 'read-c']);
  assert.ok(trace.indexOf('write:start') > trace.indexOf('read-a:end'));
  assert.ok(trace.indexOf('write:start') > trace.indexOf('read-b:end'));
  assert.ok(trace.indexOf('read-c:start') > trace.indexOf('write:end'));
});

test('scheduler stops replenishment after failure and drains started calls', async () => {
  const started = [];
  const finished = [];
  const calls = ['a', 'b', 'c', 'd'];

  await assert.rejects(
    scheduleToolCalls(calls, {
      isParallelSafe: () => true,
      maxParallel: 2,
      execute: async (call) => {
        started.push(call);
        if (call === 'a') {
          await new Promise((resolve) => setTimeout(resolve, 2));
          throw new Error('dispatch failed');
        }
        await new Promise((resolve) => setTimeout(resolve, 10));
        finished.push(call);
        return call;
      },
    }),
    /dispatch failed/,
  );

  assert.deepEqual(started, ['a', 'b']);
  assert.deepEqual(finished, ['b']);
});
