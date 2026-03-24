const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-messaging-test-'));
process.env.NEOAGENT_HOME = tempHome;

const db = require('../server/db/database');
const agentsRouter = require('../server/routes/agents');
const { AgentEngine } = require('../server/services/ai/engine');
const { MessagingManager } = require('../server/services/messaging/manager');
const models = require('../server/services/ai/models');

const originalGetSupportedModels = models.getSupportedModels;
const originalCreateProviderInstance = models.createProviderInstance;

function makeIoRecorder() {
  const events = [];
  return {
    events,
    to() {
      return {
        emit(event, payload) {
          events.push({ event, payload });
        }
      };
    }
  };
}

function installFakeModel(fakeProvider) {
  models.getSupportedModels = async () => [{
    id: 'test-model',
    label: 'Test Model',
    provider: 'openai',
    purpose: 'general',
    available: true
  }];
  models.createProviderInstance = () => fakeProvider;
}

function resetDb() {
  for (const statement of [
    'DELETE FROM agent_steps',
    'DELETE FROM conversation_messages',
    'DELETE FROM conversations',
    'DELETE FROM conversation_history',
    'DELETE FROM messages',
    'DELETE FROM user_settings',
    'DELETE FROM agent_runs',
    'DELETE FROM users'
  ]) {
    db.prepare(statement).run();
  }
  db.prepare('INSERT INTO users (id, username, password) VALUES (?, ?, ?)').run(1, 'neo', 'test-password');
}

async function waitFor(check, { timeoutMs = 1000, intervalMs = 20 } = {}) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const value = check();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  return check();
}

async function startAgentsTestServer() {
  const express = require('express');
  const app = express();
  app.use((req, _res, next) => {
    req.session = { userId: 1 };
    next();
  });
  app.use('/api/agents', agentsRouter);

  const server = await new Promise((resolve) => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });

  return {
    server,
    baseUrl: `http://127.0.0.1:${server.address().port}`
  };
}

test.beforeEach(() => {
  resetDb();
});

test.after(() => {
  models.getSupportedModels = originalGetSupportedModels;
  models.createProviderInstance = originalCreateProviderInstance;
  db.close();
  fs.rmSync(tempHome, { recursive: true, force: true });
});

test('messaging-triggered runs auto-send their final reply and expose it via run detail', async () => {
  const provider = {
    getContextWindow() {
      return 200000;
    },
    async chat() {
      return {
        content: 'all set - the task is scheduled.',
        toolCalls: [],
        usage: { totalTokens: 11 }
      };
    }
  };
  installFakeModel(provider);

  const io = makeIoRecorder();
  const messagingManager = new MessagingManager(io);
  messagingManager.platforms.set('1:whatsapp', {
    async sendMessage() {
      return { ok: true };
    }
  });

  const engine = new AgentEngine(io, { messagingManager });
  const result = await engine.run(1, 'schedule this for me', {
    stream: false,
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-1'
  });

  const messageRow = await waitFor(() =>
    db.prepare('SELECT run_id, content FROM messages WHERE run_id = ? LIMIT 1').get(result.runId)
  );

  assert.ok(messageRow, 'expected the messaging fallback to persist an outbound reply');
  assert.equal(messageRow.run_id, result.runId);
  assert.equal(messageRow.content, 'all set - the task is scheduled.');

  const runRow = db.prepare('SELECT final_response FROM agent_runs WHERE id = ?').get(result.runId);
  assert.equal(runRow.final_response, 'all set - the task is scheduled.');

  const { server, baseUrl } = await startAgentsTestServer();
  try {
    const response = await fetch(`${baseUrl}/api/agents/${result.runId}/steps`);
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.response, 'all set - the task is scheduled.');
  } finally {
    await new Promise((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  }
});

test('messaging runs with tool-only replies still retain the sent message as the final response', async () => {
  let callCount = 0;
  const provider = {
    getContextWindow() {
      return 200000;
    },
    async chat() {
      callCount += 1;
      if (callCount === 1) {
        return {
          content: '',
          toolCalls: [{
            id: 'tool-1',
            type: 'function',
            function: {
              name: 'send_message',
              arguments: JSON.stringify({
                platform: 'whatsapp',
                to: 'chat-2',
                content: 'working on it now'
              })
            }
          }],
          usage: { totalTokens: 5 }
        };
      }

      return {
        content: '',
        toolCalls: [],
        usage: { totalTokens: 3 }
      };
    }
  };
  installFakeModel(provider);

  const io = makeIoRecorder();
  const messagingManager = new MessagingManager(io);
  messagingManager.platforms.set('1:whatsapp', {
    async sendMessage() {
      return { ok: true };
    }
  });

  const engine = new AgentEngine(io, { messagingManager });
  const result = await engine.run(1, 'handle this in multiple steps', {
    stream: false,
    triggerSource: 'messaging',
    source: 'whatsapp',
    chatId: 'chat-2'
  });

  const sentRows = db.prepare(
    'SELECT content, run_id FROM messages WHERE run_id = ? ORDER BY id ASC'
  ).all(result.runId);
  assert.deepEqual(
    sentRows.map((row) => row.content),
    ['working on it now']
  );
  assert.ok(sentRows.every((row) => row.run_id === result.runId));

  const runRow = db.prepare('SELECT final_response FROM agent_runs WHERE id = ?').get(result.runId);
  assert.equal(runRow.final_response, 'working on it now');

  const { server, baseUrl } = await startAgentsTestServer();
  try {
    const response = await fetch(`${baseUrl}/api/agents/${result.runId}/steps`);
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.response, 'working on it now');
  } finally {
    await new Promise((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  }
});
