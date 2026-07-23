'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { GoogleProvider } = require('../../../server/services/ai/providers/google');

test('Google tool responses use supported user/model roles', () => {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  const converted = provider.convertMessages([
    { role: 'user', content: 'Check the weather.' },
    {
      role: 'assistant',
      content: '',
      tool_calls: [{
        function: {
          name: 'weather',
          arguments: '{"city":"Berlin"}',
        },
      }],
    },
    { role: 'tool', name: 'weather', content: '{"temperature":22}' },
  ]);

  assert.deepEqual(
    converted.history.map((message) => message.role),
    ['user', 'model', 'user'],
  );
  assert.equal(
    converted.history[2].parts[0].functionResponse.name,
    'weather',
  );
  assert.equal(
    converted.history.some((message) => message.role === 'function'),
    false,
  );
});

test('Google system-only structured requests receive a user generation turn', async () => {
  const provider = new GoogleProvider({ apiKey: 'test-key' });
  let sentParts = null;
  provider.genAI = {
    getGenerativeModel() {
      return {
        startChat({ history }) {
          assert.deepEqual(history, []);
          return {
            async sendMessage(parts) {
              sentParts = parts;
              return {
                response: {
                  candidates: [{
                    content: { parts: [{ text: '{"ok":true}' }] },
                  }],
                },
              };
            },
          };
        },
      };
    },
  };

  const result = await provider.chat([
    { role: 'system', content: 'Return JSON only.' },
  ]);

  assert.match(sentParts[0].text, /requested response/i);
  assert.equal(result.content, '{"ok":true}');
});
