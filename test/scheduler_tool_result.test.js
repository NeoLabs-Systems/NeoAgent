const assert = require('node:assert/strict');
const test = require('node:test');

const { compactToolResult } = require('../server/services/ai/toolResult');

test('compactToolResult preserves scheduled task count and list metadata for list_scheduled_tasks', () => {
  const result = compactToolResult('list_scheduled_tasks', {}, {
    tasks: [
      {
        id: 11,
        name: 'Artemis 2 Mission Update',
        cronExpression: '0 10 * * *',
        runAt: null,
        oneTime: false,
        enabled: true,
        model: null,
        config: { prompt: 'daily update' }
      },
      {
        id: 12,
        name: 'hourly recap',
        cronExpression: '0 * * * *',
        runAt: null,
        oneTime: false,
        enabled: true,
        model: null,
        config: { prompt: 'hourly summary' }
      }
    ],
    count: 2
  });

  const parsed = JSON.parse(result);
  assert.equal(parsed.tool, 'list_scheduled_tasks');
  assert.equal(parsed.status, 'ok');
  assert.equal(parsed.count, 2);
  assert.equal(parsed.tasks.length, 2);
  assert.deepEqual(parsed.tasks[0], {
    id: 11,
    name: 'Artemis 2 Mission Update',
    cronExpression: '0 10 * * *',
    oneTime: false,
    enabled: true
  });
  assert.deepEqual(parsed.tasks[1], {
    id: 12,
    name: 'hourly recap',
    cronExpression: '0 * * * *',
    oneTime: false,
    enabled: true
  });
});
