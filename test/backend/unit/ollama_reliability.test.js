'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { OllamaProvider } = require('../../../server/services/ai/providers/ollama');

const TOOL = {
  name: 'get_weather',
  description: 'Read the weather.',
  parameters: { type: 'object', properties: {} },
};

function providerWithoutModelLookup() {
  const provider = new OllamaProvider({ baseUrl: 'http://ollama.test' });
  provider.ensureModel = async () => true;
  return provider;
}

test('Ollama retries a status-200 tool rejection without tools', async () => {
  const provider = providerWithoutModelLookup();
  const originalFetch = global.fetch;
  const bodies = [];
  global.fetch = async (_url, options) => {
    bodies.push(JSON.parse(options.body));
    if (bodies.length === 1) {
      return new Response(JSON.stringify({ error: 'this model does not support tools' }));
    }
    return new Response(JSON.stringify({
      done: true,
      message: { content: 'fallback worked' },
      model: 'local-model',
    }));
  };

  try {
    const result = await provider.chat([{ role: 'user', content: 'hello' }], [TOOL], {
      model: 'local-model',
    });
    assert.equal(result.content, 'fallback worked');
    assert.equal(bodies.length, 2);
    assert.equal(bodies[0].tools.length, 1);
    assert.equal('tools' in bodies[1], false);
  } finally {
    global.fetch = originalFetch;
  }
});

test('Ollama streaming retries a status-200 tool rejection and parses a final line without a newline', async () => {
  const provider = providerWithoutModelLookup();
  const originalFetch = global.fetch;
  const bodies = [];
  global.fetch = async (_url, options) => {
    bodies.push(JSON.parse(options.body));
    if (bodies.length === 1) {
      return new Response('{"error":"tools are not supported by this model"}\n');
    }
    return new Response([
      JSON.stringify({ message: { content: 'hello ' }, done: false }),
      JSON.stringify({ message: { content: 'world' }, done: true, prompt_eval_count: 0, eval_count: 2 }),
    ].join('\n'));
  };

  try {
    const chunks = [];
    for await (const chunk of provider.stream(
      [{ role: 'user', content: 'hello' }],
      [TOOL],
      { model: 'local-model' },
    )) {
      chunks.push(chunk);
    }
    assert.deepEqual(chunks.map((chunk) => chunk.type), ['content', 'content', 'done']);
    assert.equal(chunks.at(-1).content, 'hello world');
    assert.deepEqual(chunks.at(-1).usage, {
      promptTokens: 0,
      completionTokens: 2,
      totalTokens: 2,
    });
    assert.equal(bodies.length, 2);
    assert.equal('tools' in bodies[1], false);
  } finally {
    global.fetch = originalFetch;
  }
});

test('Ollama streaming reports an incomplete or malformed stream instead of ending silently', async () => {
  const provider = providerWithoutModelLookup();
  const originalFetch = global.fetch;
  const responses = [
    new Response('{"message":{"content":"partial"},"done":false}\n'),
    new Response('not-json\n'),
  ];
  global.fetch = async () => responses.shift();

  try {
    await assert.rejects(async () => {
      for await (const _chunk of provider.stream([], [], { model: 'local-model' })) {}
    }, (error) => error.code === 'OLLAMA_STREAM_INCOMPLETE');
    await assert.rejects(async () => {
      for await (const _chunk of provider.stream([], [], { model: 'local-model' })) {}
    }, (error) => error.code === 'OLLAMA_STREAM_MALFORMED');
  } finally {
    global.fetch = originalFetch;
  }
});

test('Ollama streaming cancellation settles even when the reader never does', async () => {
  const provider = providerWithoutModelLookup();
  const originalFetch = global.fetch;
  let readStarted;
  const started = new Promise((resolve) => { readStarted = resolve; });
  const response = {
    ok: true,
    body: {
      getReader() {
        return {
          read() {
            readStarted();
            return new Promise(() => {});
          },
          async cancel() {},
          releaseLock() {},
        };
      },
    },
  };
  global.fetch = async () => response;
  const controller = new AbortController();

  try {
    const iterator = provider.stream([], [], {
      model: 'local-model',
      signal: controller.signal,
    });
    const pending = iterator.next();
    await started;
    const reason = new Error('stop local generation');
    controller.abort(reason);
    await assert.rejects(pending, (error) => error === reason);
  } finally {
    global.fetch = originalFetch;
  }
});
