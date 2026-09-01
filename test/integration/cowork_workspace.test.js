'use strict';

const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

describe('Cowork desktop workspace', () => {
  let ctx;
  let app;
  let ownerClient;
  let otherClient;
  let owner;
  let other;
  const abortedRuns = [];

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    app.locals.runtimeManager.getComputerProvider = () => 'cloud';
    app.locals.runtimeManager.getComputerStatus = () => ({
      state: 'stopped',
      provider: 'cloud',
      providers: {
        cloud: { available: true },
        local: { available: true, connected: true },
      },
    });
    app.locals.agentEngine.abort = (runId) => {
      abortedRuns.push(runId);
      return true;
    };
    owner = await createTestUser(ctx.db, { username: 'cowork_owner' });
    other = await createTestUser(ctx.db, { username: 'cowork_other' });
    ownerClient = agent(app);
    otherClient = agent(app);
    await loginAs(ownerClient, owner);
    await loginAs(otherClient, other);
  });

  after(() => teardownTestRuntime(ctx));

  test('chat configuration is durable and the device target is chat-scoped', async () => {
    const created = await ownerClient.post('/api/cowork/chats').send({}).expect(201);
    const chat = created.body.chat;
    assert.equal(chat.title, 'New chat');
    assert.equal(chat.mode, 'agent');
    assert.equal(chat.device.effective, 'cloud');
    assert.equal(chat.device.inherited, true);

    const updated = await ownerClient.patch(`/api/cowork/chats/${chat.id}`).send({
      title: 'Desktop implementation',
      mode: 'plan',
      deviceTargetOverride: 'local',
    }).expect(200);
    assert.equal(updated.body.chat.title, 'Desktop implementation');
    assert.equal(updated.body.chat.mode, 'plan');
    assert.equal(updated.body.chat.device.effective, 'local');
    assert.equal(updated.body.chat.device.inherited, false);

    ctx.db.prepare(
      `INSERT INTO conversation_messages (
        conversation_id, agent_id, role, content, metadata_json
      ) VALUES (?, ?, 'user', ?, ?)`,
    ).run(
      chat.id,
      chat.agentId,
      'Review this file.\n\nShared attachments from the NeoAgent client:\n- notes.md',
      JSON.stringify({
        displayContent: 'Review this file.',
        sharedAttachments: [{
          uri: 'file:///workspace/notes.md',
          name: 'notes.md',
          mimeType: 'text/markdown',
          source: 'file_picker',
        }],
      }),
    );
    const detail = await ownerClient.get(`/api/cowork/chats/${chat.id}`).expect(200);
    assert.equal(detail.body.messages[0].content, 'Review this file.');
    assert.equal(detail.body.messages[0].metadata.sharedAttachments[0].name, 'notes.md');

    const list = await ownerClient.get('/api/cowork/chats').expect(200);
    assert.equal(list.body.chats.length, 1);
    assert.equal(list.body.chats[0].id, chat.id);
    assert.equal(list.body.chats[0].device.effective, 'local');

    await otherClient.get(`/api/cowork/chats/${chat.id}`).expect(404);
    await otherClient.patch(`/api/cowork/chats/${chat.id}`).send({ title: 'Nope' }).expect(404);
  });

  test('structured questions persist, validate answers, and close the waiting run', async () => {
    const created = await ownerClient.post('/api/cowork/chats').send({
      mode: 'plan',
    }).expect(201);
    const chat = created.body.chat;
    const runId = randomUUID();
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, runtime_state,
        conversation_id, interaction_mode, device_target
      ) VALUES (?, ?, ?, ?, 'waiting_input', 'waiting', ?, 'plan', 'cloud')`,
    ).run(runId, owner.userId, chat.agentId, 'Clarify implementation', chat.id);

    const cowork = require('../../server/services/cowork/service');
    const request = cowork.createInputRequest({
      userId: owner.userId,
      conversationId: chat.id,
      runId,
      agentId: chat.agentId,
      schema: {
        questions: [{
          id: 'scope',
          header: 'Scope',
          question: 'Which implementation scope should be used?',
          options: [
            { label: 'Desktop only', description: 'Keep the change in Flutter desktop.' },
            { label: 'All clients', description: 'Expand the change to every client.' },
          ],
        }],
      },
    });

    const detail = await ownerClient.get(`/api/cowork/chats/${chat.id}`).expect(200);
    assert.equal(detail.body.inputRequests.length, 1);
    assert.equal(detail.body.inputRequests[0].status, 'pending');
    assert.equal(detail.body.messages[0].metadata.structuredInputRequestId, request.id);

    await ownerClient
      .post(`/api/cowork/chats/${chat.id}/input-requests/${request.id}/answer`)
      .send({ answers: {} })
      .expect(400);
    const answered = await ownerClient
      .post(`/api/cowork/chats/${chat.id}/input-requests/${request.id}/answer`)
      .send({ answers: { scope: 'Desktop only' } })
      .expect(200);
    assert.match(answered.body.answer.prompt, /Scope: Desktop only/);
    assert.equal(
      ctx.db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(runId).status,
      'completed',
    );
    await otherClient
      .post(`/api/cowork/chats/${chat.id}/input-requests/${request.id}/answer`)
      .send({ answers: { scope: 'All clients' } })
      .expect(404);
  });

  test('per-chat model override is durable and clears with "default"', async () => {
    const created = await ownerClient.post('/api/cowork/chats').send({
      modelOverride: 'openai:gpt-5',
    }).expect(201);
    assert.equal(created.body.chat.modelOverride, 'openai:gpt-5');
    const cleared = await ownerClient.patch(`/api/cowork/chats/${created.body.chat.id}`).send({
      modelOverride: 'default',
    }).expect(200);
    assert.equal(cleared.body.chat.modelOverride, null);
    await ownerClient.patch(`/api/cowork/chats/${created.body.chat.id}`).send({
      modelOverride: 'x'.repeat(121),
    }).expect(400);
  });

  test('changed files are derived from completed workspace edits and the latest run carries usage', async () => {
    const created = await ownerClient.post('/api/cowork/chats').send({}).expect(201);
    const chat = created.body.chat;
    const runId = randomUUID();
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, runtime_state, conversation_id, model, total_tokens
      ) VALUES (?, ?, ?, 'Refactor', 'completed', 'completed', ?, 'anthropic:claude', 1234)`,
    ).run(runId, owner.userId, chat.agentId, chat.id);
    const insertStep = ctx.db.prepare(
      `INSERT INTO agent_steps (
        id, run_id, step_index, type, status, tool_name, tool_input, started_at, completed_at
      ) VALUES (?, ?, ?, 'tool', ?, ?, ?, datetime('now', ?), datetime('now', ?))`,
    );
    insertStep.run(randomUUID(), runId, 0, 'completed', 'read_file', JSON.stringify({ path: 'README.md' }), '-4 minutes', '-4 minutes');
    insertStep.run(randomUUID(), runId, 1, 'completed', 'write_file', JSON.stringify({ path: './src/new.js' }), '-3 minutes', '-3 minutes');
    insertStep.run(randomUUID(), runId, 2, 'completed', 'edit_file', JSON.stringify({ file_path: 'src/new.js' }), '-2 minutes', '-2 minutes');
    insertStep.run(randomUUID(), runId, 3, 'failed', 'edit_file', JSON.stringify({ path: 'src/broken.js' }), '-1 minutes', '-1 minutes');
    insertStep.run(randomUUID(), runId, 4, 'completed', 'replace_file_range', JSON.stringify({ path: 'docs/guide.md' }), '-30 seconds', '-30 seconds');

    const changes = await ownerClient.get(`/api/cowork/chats/${chat.id}/changes`).expect(200);
    assert.deepEqual(
      changes.body.changes.map((change) => [change.path, change.action, change.edits]),
      [['docs/guide.md', 'edited', 1], ['src/new.js', 'written', 2]],
    );
    const detail = await ownerClient.get(`/api/cowork/chats/${chat.id}`).expect(200);
    assert.equal(detail.body.changes.length, 2);
    assert.equal(detail.body.chat.latestRun.model, 'anthropic:claude');
    assert.equal(detail.body.chat.latestRun.totalTokens, 1234);
    await otherClient.get(`/api/cowork/chats/${chat.id}/changes`).expect(404);
  });

  test('deleting a chat stops its active run and removes chat-owned records', async () => {
    const created = await ownerClient.post('/api/cowork/chats').send({}).expect(201);
    const chat = created.body.chat;
    const runId = randomUUID();
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, runtime_state, conversation_id
      ) VALUES (?, ?, ?, 'Active Cowork run', 'running', 'executing', ?)`,
    ).run(runId, owner.userId, chat.agentId, chat.id);

    await ownerClient.delete(`/api/cowork/chats/${chat.id}`).expect(200);
    assert.deepEqual(abortedRuns, [runId]);
    assert.equal(ctx.db.prepare('SELECT 1 FROM conversations WHERE id = ?').get(chat.id), undefined);
    assert.equal(ctx.db.prepare('SELECT 1 FROM agent_runs WHERE id = ?').get(runId), undefined);
  });
});
