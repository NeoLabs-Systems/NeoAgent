'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { selectWrapUpHistory } = require('../../../server/services/ai/runtime/wrap_up_history');

function toolTurns(count) {
  const messages = [];
  for (let i = 0; i < count; i += 1) {
    messages.push({ role: 'assistant', content: '', tool_calls: [{ id: `call_${i}`, type: 'function', function: { name: 'execute_command', arguments: '{}' } }] });
    messages.push({ role: 'tool', tool_call_id: `call_${i}`, content: 'exit 1' });
  }
  return messages;
}

const system = { role: 'system', content: "you're texting with Neo." };
const request = { role: 'user', content: 'Dann buche in 2 Monaten noch einen Termin für mich bitte' };

test('the wrap-up keeps the run\'s request after a long tool run pushed it out of the recent window', () => {
  const history = selectWrapUpHistory([system, request, ...toolTurns(30)], request);

  assert.deepEqual(history.slice(0, 2), [system, request]);
  assert.equal(history.filter((message) => message.role === 'user').length, 1);
});

test('the wrap-up does not repeat a request that is still in the recent window', () => {
  const messages = [system, request, ...toolTurns(3)];

  assert.deepEqual(selectWrapUpHistory(messages, { ...request }), messages);
});
