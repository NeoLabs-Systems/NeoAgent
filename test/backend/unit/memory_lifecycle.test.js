'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { ownerVerification } = require('../../../server/services/memory/provenance');
const { isOneWordSwap, isValueChange, sharesContentWord, valuesDiffer } = require('../../../server/services/memory/conflict');

let ctx;

afterEach(() => {
  if (ctx) teardownTestRuntime(ctx);
  ctx = null;
});

async function setup(username) {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username });
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  return {
    userId: user.userId,
    agentId: resolveAgentId(user.userId, null),
    manager: new MemoryManager(),
    db: require('../../../server/db/database'),
  };
}

function statusOf(db, memoryId) {
  return db.prepare('SELECT status FROM memory_facts WHERE memory_id = ?').all(memoryId).map((row) => row.status);
}

function candidate(memory, subject, predicate, object, relation = 'new', extra = {}) {
  return { memory, subject, predicate, object, relation, category: 'projects', confidence: 0.9, importance: 6, ...extra };
}

test('a value change is one swapped value in otherwise the same statement', () => {
  const same = [
    ['My staging DB moved to port 5600.', 'My staging DB runs on port 5544.'],
    ['Der Staging-Server läuft jetzt auf Port 9090.', 'Der Staging-Server läuft auf Port 8080.'],
    ['The office printer has IP 10.0.0.77.', 'The office printer has IP 10.0.0.40.'],
    ['Support mail is help@neu.example', 'Support mail is help@alt.example'],
    ['Die Miete wurde auf 950 Euro erhöht.', 'Die Miete beträgt 900 Euro.'],
  ];
  for (const [next, previous] of same) assert.equal(isValueChange(next, previous), true, next);

  const different = [
    ['Meeting with Anna at 10:00.', 'Meeting with Bob at 11:00.'],
    ['Server web01 runs nginx.', 'Server web02 runs nginx.'],
    ['Neo has 3 dogs.', 'Neo has 2 cats.'],
    ['Neo was in Rome in 2021.', 'Neo was in Rome in 2019.'],
    ['Neos Schwester ist Maria.', 'Neos Schwester ist Anna.'],
    ['Flight LH123 leaves at 10:00.', 'Flight LH456 leaves at 11:00.'],
    ['Production uses port 5600.', 'My staging DB runs on port 5544.'],
    ['Neo likes coffee.', 'Neo likes tea.'],
  ];
  for (const [next, previous] of different) assert.equal(isValueChange(next, previous), false, next);
});

test('only true rewordings count as copies of each other', () => {
  assert.equal(isOneWordSwap('User prefers dark mode.', 'User prefers light mode.'), true);
  assert.equal(isOneWordSwap('User prefers dark mode.', 'User really prefers dark mode.'), false);
  assert.equal(valuesDiffer('Port 5600 for staging', 'Port 9090 for production'), true);
  assert.equal(valuesDiffer('Port 5600 for staging', 'Staging is on port 5600'), false);
  assert.equal(valuesDiffer('Port 5600 for staging', 'Staging has a port'), false);
  assert.equal(sharesContentWord('Neo trinkt Kamillentee.', 'User drinks oat milk.'), false);
  assert.equal(sharesContentWord('Neo trinkt Kamillentee.', 'Abends gibt es Kamillentee.'), true);
});

test('plain memories that share a category or first name do not replace each other', async () => {
  const { userId, agentId, manager, db } = await setup('memory_plain_collision');
  const hiking = await manager.saveMemory(userId, 'user likes hiking in the alps.', 'episodic', 5, { agentId });
  const novels = await manager.saveMemory(userId, 'user reads science fiction novels.', 'episodic', 5, { agentId });
  const first = await manager.saveMemory(userId, 'Neo keeps a spare key at the office.', 'episodic', 5, { agentId });
  const second = await manager.saveMemory(userId, 'Neo cycles to the lake on sundays.', 'episodic', 5, { agentId });

  for (const id of [hiking, novels, first, second]) assert.deepEqual(statusOf(db, id), ['active']);
  const found = await manager.recallMemory(userId, 'Which novels do I read?', 5, { agentId, reinforce: false });
  assert.deepEqual(found.map((memory) => memory.id), [novels]);
});

test('reconciliation restores memories hidden by the old fact collision, not real replacements', async () => {
  const { userId, agentId, manager, db } = await setup('memory_restore_collision');
  const older = await manager.saveMemory(userId, 'user likes hiking in the alps.', 'episodic', 5, { agentId });
  const newer = await manager.saveMemory(userId, 'user reads science fiction novels.', 'episodic', 5, { agentId });
  const oldPort = await manager.saveMemory(userId, 'The relay listens on port 7000.', 'episodic', 5, { agentId });
  const newPort = await manager.saveMemory(userId, 'The relay listens on port 7100.', 'episodic', 5, { agentId });
  assert.deepEqual(statusOf(db, oldPort), ['superseded']);

  // What the earlier code left behind: the newer local fact claims to replace the older.
  const olderFact = db.prepare('SELECT id FROM memory_facts WHERE memory_id = ?').get(older).id;
  db.prepare(`UPDATE memory_facts SET status = 'superseded', valid_to = datetime('now') WHERE id = ?`).run(olderFact);
  db.prepare('UPDATE memory_facts SET supersedes_fact_id = ? WHERE memory_id = ?').run(olderFact, newer);
  const newPortFact = db.prepare('SELECT id, metadata_json FROM memory_facts WHERE memory_id = ?').get(newPort);
  const { replacedMemory, ...legacyMetadata } = JSON.parse(newPortFact.metadata_json);
  assert.equal(replacedMemory, true);
  db.prepare('UPDATE memory_facts SET metadata_json = ? WHERE id = ?').run(JSON.stringify(legacyMetadata), newPortFact.id);

  const result = manager.reconcileFacts(userId, { agentId });

  assert.equal(result.restored, 1);
  assert.deepEqual(statusOf(db, older), ['active']);
  assert.deepEqual(statusOf(db, oldPort), ['superseded'], 'a real value change stays replaced');
  assert.equal(manager.reconcileFacts(userId, { agentId }).restored, 0);
});

test('a reworded copy keeps its structured fact and refreshes the memory', async () => {
  const { userId, agentId, manager, db } = await setup('memory_reworded');
  const [id] = await manager.consolidateMemoryCandidates(
    userId,
    [candidate('Neo drives a Skoda.', 'Neo', 'car', 'Skoda')],
    { agentId, metadata: { trustLevel: 'user_stated' } },
  );
  const again = await manager.consolidateMemoryCandidates(
    userId,
    [candidate('Neo is driving a Skoda these days.', 'neo', 'car', 'skoda')],
    { agentId, metadata: { trustLevel: 'agent_statement' } },
  );

  assert.deepEqual(again, [id], 'the same subject, predicate and value is one fact');
  const fact = db.prepare('SELECT subject, predicate, object FROM memory_facts WHERE memory_id = ?').get(id);
  assert.deepEqual({ ...fact }, { subject: 'Neo', predicate: 'car', object: 'Skoda' });
  const metadata = JSON.parse(db.prepare('SELECT metadata_json FROM memories WHERE id = ?').get(id).metadata_json);
  assert.equal(metadata.trustLevel, 'user_stated', 'a weaker source does not demote it');
});

test('a fact in a shared room cannot replace the owner\'s fact', async () => {
  const { userId, agentId, manager, db } = await setup('memory_room_scope');
  const [own] = await manager.consolidateMemoryCandidates(
    userId,
    [candidate('Billing goes to the Acme account.', 'billing', 'account', 'Acme')],
    { agentId },
  );
  await manager.consolidateMemoryCandidates(
    userId,
    [candidate('Billing goes to the Globex account.', 'billing', 'account', 'Globex', 'updates')],
    {
      agentId,
      scope: { scopeType: 'channel', scopeId: 'telegram:room' },
      metadata: { trustLevel: 'shared_room_conversation' },
    },
  );
  assert.deepEqual(statusOf(db, own), ['active']);
});

test('history and points in time see replaced facts, and say they were replaced', async () => {
  const { userId, agentId, manager, db } = await setup('memory_history');
  const [berlin] = await manager.consolidateMemoryCandidates(
    userId,
    [candidate('User lives in Berlin.', 'User', 'lives in', 'Berlin')],
    { agentId },
  );
  const [munich] = await manager.consolidateMemoryCandidates(
    userId,
    [candidate('User lives in Munich.', 'User', 'lives in', 'Munich', 'updates', { valid_from: '2026-06-01T00:00:00Z' })],
    { agentId },
  );
  db.prepare(`UPDATE memory_facts SET valid_from = '2020-01-01 00:00:00' WHERE memory_id = ?`).run(berlin);

  const now = await manager.recallMemory(userId, 'Where does the user live?', 5, { agentId, reinforce: false });
  assert.deepEqual(now.map((memory) => memory.id), [munich]);

  const history = await manager.recallMemory(userId, 'Where does the user live?', 5, { agentId, reinforce: false, includeHistory: true });
  assert.equal(history.find((memory) => memory.id === berlin).current, false);
  assert.equal(history.find((memory) => memory.id === munich).current, true);

  const then = await manager.recallMemory(userId, 'Where does the user live?', 5, { agentId, reinforce: false, validAt: '2024-03-01T00:00:00.000Z' });
  assert.deepEqual(then.map((memory) => memory.id), [berlin]);
});

test('the recall block separates verified, retrieved and assumed memory', async () => {
  const { userId, manager } = await setup('memory_recall_tiers');
  const message = await manager.buildRecallMessage(userId, 'wo arbeitet neo?', {
    recalled: [
      { id: 'a', category: 'identity', content: 'Neo arbeitet bei Acme.', metadata: { trustLevel: 'user_stated', verification: ownerVerification('Neo arbeitet bei Acme.') } },
      { id: 'b', category: 'contacts', content: 'Neo hat eine Mail von Globex.', metadata: { trustLevel: 'external_source' } },
      { id: 'c', category: 'tasks', content: 'Neo will wohl wechseln.', metadata: { trustLevel: 'model_inference', relation: 'derives' } },
      { id: 'd', category: 'events', content: 'Alte Notiz ohne Herkunft.', metadata: {} },
      { id: 'e', category: 'projects', content: 'Neo sagte es selbst, aber unsicher.', metadata: { trustLevel: 'user_stated', verification: ownerVerification('Neo sagte es selbst, aber unsicher.') }, confidence: 0.3 },
    ],
  });
  const [verified, retrieved, assumption] = ['Verified memory', 'Retrieved memory', 'Assumptions']
    .map((heading) => message.indexOf(heading));
  assert.ok(verified >= 0 && verified < retrieved && retrieved < assumption);
  const section = (from, to) => message.slice(from, to);
  assert.match(section(verified, retrieved), /Neo arbeitet bei Acme/);
  assert.match(section(verified, retrieved), /aber unsicher/);
  assert.match(section(retrieved, assumption), /Mail von Globex/);
  assert.match(section(retrieved, assumption), /Alte Notiz/);
  assert.match(section(assumption), /will wohl wechseln/);
  assert.match(message, /^\[Recalled context/, 'prompt metrics key on this prefix');
});

test('a memory nobody restated for long says how old it is, unless it does not age', async () => {
  const { userId, manager } = await setup('memory_stale_marker');
  const message = await manager.buildRecallMessage(userId, 'staging', {
    recalled: [
      { id: 'a', content: 'Staging runs on the old box.', category: 'projects', importance: 5, updated_at: '2024-02-01 10:00:00' },
      { id: 'b', content: 'Staging was set up last week.', category: 'projects', importance: 5, updated_at: new Date().toISOString() },
      { id: 'c', content: 'Neo prefers staging first.', category: 'preferences', importance: 5, updated_at: '2024-02-01 10:00:00' },
    ],
  });
  assert.match(message, /old box\. \(as of 2024-02\)/);
  assert.doesNotMatch(message, /last week\. \(as of/);
  assert.doesNotMatch(message, /staging first\. \(as of/);
});

test('recall brings in task runs on a matching subject, not on a shared word', async () => {
  const { userId, agentId, manager, db } = await setup('memory_task_runs');
  db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status, trigger_source, final_response, completed_at)
     VALUES ('run-1', ?, ?, 'Morning briefing', 'completed', 'schedule', 'The morning briefing has the weather and the calendar.', datetime('now'))`
  ).run(userId, agentId);

  const related = await manager.buildRecallMessage(userId, 'Show me the morning briefing', { agentId, recalled: [] });
  assert.match(related, /Earlier task runs/);
  assert.equal(await manager.buildRecallMessage(userId, 'What is the capital of France?', { agentId, recalled: [] }), null);
  assert.equal(await manager.buildRecallMessage(userId, 'Explain the calendar reform of 1582', { agentId, recalled: [] }), null);
});

test('only what reaches the prompt is reinforced, and unrelated requests reach nothing', async () => {
  const { userId, agentId, manager, db } = await setup('memory_reinforcement');
  const { AgentEngine } = require('../../../server/services/ai/engine');
  const engine = new AgentEngine(null);
  const id = await manager.saveMemory(userId, 'User is allergic to penicillin.', 'identity', 10, { agentId });
  const accessCount = () => db.prepare('SELECT access_count FROM memories WHERE id = ?').get(id).access_count;

  const unrelated = await engine.buildMemoryRecall({
    memoryManager: manager,
    userId,
    agentId,
    query: 'Write a Python function that reverses a string',
    runId: null,
  });
  assert.equal(unrelated, null);
  assert.equal(accessCount(), 0);

  const related = await engine.buildMemoryRecall({
    memoryManager: manager,
    userId,
    agentId,
    query: 'Am I allergic to anything?',
    runId: null,
  });
  assert.match(related, /penicillin/);
  assert.equal(accessCount(), 1);
});

test('an inference stays out of the profile and cannot replace a known fact', async () => {
  const { userId, agentId, manager, db } = await setup('memory_inference');
  const known = await manager.saveMemory(userId, 'The relay listens on port 7000.', 'projects', 6, {
    agentId,
    metadata: { trustLevel: 'user_stated' },
  });
  const guess = await manager.saveMemory(userId, 'The relay listens on port 7100.', 'projects', 6, {
    agentId,
    confidence: 0.45,
    metadata: { trustLevel: 'model_inference', relation: 'derives' },
  });
  assert.deepEqual(statusOf(db, known), ['active']);
  const profile = manager.getUserProfile(userId, { agentId });
  const statements = [...profile.static, ...profile.dynamic];
  assert.ok(statements.includes('The relay listens on port 7000.'));
  assert.ok(!statements.includes('The relay listens on port 7100.'));

  // The user saying it settles it.
  const confirmed = await manager.saveMemory(userId, 'The relay listens on port 7100.', 'projects', 6, {
    agentId,
    metadata: { trustLevel: 'user_stated', verification: ownerVerification('The relay listens on port 7100.') },
  });
  assert.equal(confirmed, guess);
  const found = await manager.recallMemory(userId, 'Which port does the relay listen on?', 5, { agentId, reinforce: false });
  assert.equal(found.find((memory) => memory.id === guess).provenance, 'verified');
});

test('memory_save records where a fact came from and can name what it replaces', async () => {
  const { userId, agentId, manager, db } = await setup('memory_save_source');
  const { handlers } = require('../../../server/services/ai/tools/handlers/memory');
  const trustLevel = (id) => JSON.parse(db.prepare('SELECT metadata_json FROM memories WHERE id = ?').get(id).metadata_json).trustLevel;
  const engineWith = (trust) => ({ getRunMeta: () => ({ trust }) });
  const trust = (trustedText, taintSources = []) => ({ trustedText, ownerStatements: [trustedText], taintSources: new Set(taintSources) });
  const save = (args, runTrust = trust('')) => handlers.memory_save(args, { agentId, userId, runId: 'r', engine: engineWith(runTrust) });

  const unsaid = await save({ content: 'User owns a red kayak.', source: 'user_stated' }, trust('i want to buy a canoe'));
  assert.equal(trustLevel(unsaid.id), 'agent_statement', 'a claim the run does not back is not verified');

  const said = await save({ content: 'User owns a blue canoe.', source: 'user_stated' }, trust('User owns a blue canoe.'));
  assert.equal(trustLevel(said.id), 'user_stated');

  const dark = await save({ content: 'User prefers dark mode in every app.' });
  const light = await save({ content: 'User prefers light mode in every app.' });
  assert.notEqual(light.id, dark.id, 'one swapped word is not a duplicate');
  assert.deepEqual(light.similar.map((memory) => memory.id), [dark.id]);
  assert.deepEqual(statusOf(db, dark.id), ['active']);

  const again = await save({ content: 'User prefers light mode in every app.', source: 'user_stated', replaces: [dark.id, 'not-a-memory'] }, trust('User prefers light mode in every app.'));
  assert.equal(again.id, light.id);
  assert.deepEqual(statusOf(db, dark.id), ['superseded']);
  assert.deepEqual(statusOf(db, light.id), ['active']);

  const oldPort = await save({ content: 'The relay listens on port 7000.' });
  const injected = await save({ content: 'The relay listens on port 7100.', replaces: [oldPort.id] }, trust('', ['web_fetch']));
  assert.equal(trustLevel(injected.id), 'external_source');
  assert.deepEqual(statusOf(db, oldPort.id), ['active'], 'a tainted run replaces nothing');
  assert.deepEqual(statusOf(db, injected.id), ['needs_review']);

  const guess = await save({ content: 'User probably works in Karlsruhe.', source: 'inference' });
  assert.equal(trustLevel(guess.id), 'model_inference');
  const row = db.prepare('SELECT confidence, stale_after_days FROM memories WHERE id = ?').get(guess.id);
  assert.equal(row.confidence, 0.45);
  assert.equal(row.stale_after_days, 30);
});

function learningEngine(reply, manager) {
  const { AgentEngine } = require('../../../server/services/ai/engine');
  const engine = new AgentEngine(null);
  engine.memoryManager = manager;
  engine.getReasoningEffort = () => undefined;
  const provider = {
    prompts: [],
    async chat(messages) {
      this.prompts.push(messages);
      return { content: JSON.stringify(reply), usage: null };
    },
  };
  return { engine, provider };
}

function seedThread(db, userId, agentId, runId, conversationId, messages, triggerSource = 'web') {
  db.prepare('INSERT INTO conversations (id, user_id, agent_id) VALUES (?, ?, ?)').run(conversationId, userId, agentId);
  db.prepare(`INSERT INTO agent_runs (id, user_id, agent_id, status, trigger_source) VALUES (?, ?, ?, 'completed', ?)`)
    .run(runId, userId, agentId, triggerSource);
  for (const [role, content] of messages) {
    db.prepare('INSERT INTO conversation_messages (conversation_id, run_id, agent_id, role, content) VALUES (?, ?, ?, ?, ?)')
      .run(conversationId, runId, agentId, role, content);
  }
}

test('conversation learning stores what the user said and refuses what only the assistant said', async () => {
  const { userId, agentId, manager, db } = await setup('memory_learning');
  const { refreshConversationState } = require('../../../server/services/ai/loop/memory_writer');
  const [known] = await manager.consolidateMemoryCandidates(
    userId,
    [candidate('My staging DB runs on port 5544.', 'staging db', 'port', '5544')],
    { agentId },
  );
  seedThread(db, userId, agentId, 'run-learn', 'conv-learn', [
    ['user', 'my staging db moved to port 5600, also what should I use for caching?'],
    ['assistant', 'Noted. You should use Valkey for caching, it is probably what your team runs.'],
  ]);
  db.prepare(
    `INSERT INTO agent_steps (id, run_id, step_index, type, status, tool_name, result)
     VALUES ('s1', 'run-learn', 0, 'tool', 'completed', 'memory_recall', '{"text":"deploy target is hetzner"}')`
  ).run();

  const { engine, provider } = learningEngine({
    summary: 'Staging moved.',
    last_verified_facts: ['Staging DB is on port 5600.', 'The team runs Valkey.'],
    memory_candidates: [
      candidate('User staging DB is on port 5600.', 'Staging DB', 'port', '5600', 'updates', { evidence: 'my staging db moved to port 5600' }),
      candidate('User team runs Valkey for caching.', 'team', 'cache', 'Valkey', 'new', { evidence: 'it is probably what your team runs' }),
      candidate('Deploy target is Hetzner.', 'deploy', 'target', 'Hetzner', 'new', { evidence: 'deploy target is hetzner' }),
      candidate('Benutzer plant wohl einen Umzug.', 'User', 'plan', 'Umzug', 'new', { evidence: 'plant einen Umzug' }),
    ],
  }, manager);

  const state = await refreshConversationState(engine, {
    conversationId: 'conv-learn',
    runId: 'run-learn',
    provider,
    providerName: 'fake',
    model: 'fake',
    finalReply: 'Noted. You should use Valkey for caching, it is probably what your team runs.',
    historyWindow: 8,
    options: { userId, agentId },
  });

  assert.deepEqual(state.last_verified_facts, [], 'a paraphrase is not verified source text');
  assert.match(provider.prompts[0][1].content, /staging db \| port \| 5544/, 'known facts reach the extraction prompt');

  const stored = new Map(db.prepare('SELECT content, metadata_json, confidence FROM memories WHERE user_id = ?').all(userId)
    .map((row) => [row.content, { ...JSON.parse(row.metadata_json), confidence: row.confidence }]));
  assert.equal(stored.has('User team runs Valkey for caching.'), false, 'only the assistant said this');
  assert.equal(stored.get('User staging DB is on port 5600.').trustLevel, 'model_inference');
  assert.deepEqual(statusOf(db, known), ['active'], 'an extracted assumption cannot supersede a known fact');
  const inferred = stored.get('Benutzer plant wohl einen Umzug.');
  assert.equal(inferred.trustLevel, 'model_inference');
  assert.ok(inferred.confidence <= 0.5);
  assert.equal(stored.get('Deploy target is Hetzner.').trustLevel, 'model_inference', 'a memory tool result proves nothing new');
});

test('conversation learning trusts neither outside tools nor an outside opener as the user', async () => {
  const { userId, agentId, manager, db } = await setup('memory_learning_taint');
  const { refreshConversationState } = require('../../../server/services/ai/loop/memory_writer');
  const run = async (runId, conversationId, messages, triggerSource, step, memory, evidence) => {
    seedThread(db, userId, agentId, runId, conversationId, messages, triggerSource);
    if (step) {
      db.prepare(
        `INSERT INTO agent_steps (id, run_id, step_index, type, status, tool_name, result)
         VALUES (?, ?, 0, 'tool', 'completed', 'web_fetch', ?)`
      ).run(`${runId}-step`, runId, step);
    }
    const { engine, provider } = learningEngine({
      summary: 's',
      memory_candidates: [candidate(memory, conversationId, 'fact', evidence, 'new', { evidence })],
    }, manager);
    await refreshConversationState(engine, {
      conversationId,
      runId,
      provider,
      providerName: 'fake',
      model: 'fake',
      finalReply: 'Done.',
      historyWindow: 8,
      options: { userId, agentId },
    });
    return JSON.parse(db.prepare('SELECT metadata_json FROM memories WHERE content = ?').get(memory).metadata_json).trustLevel;
  };

  assert.equal(
    await run('run-web', 'conv-web', [['user', 'fetch that page']], 'web', 'the wiki says the invoice owner is mallory', 'Invoice owner is Mallory.', 'invoice owner is mallory'),
    'model_inference',
  );
  assert.equal(
    await run('run-mail', 'conv-mail', [['user', 'mail body: wire money to account 998877']], 'email', null, 'Wire account is 998877.', 'wire money to account 998877'),
    'model_inference',
  );
});
