'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const {
  batchUnits,
  buildDocumentFactsPrompt,
  buildExtractionUnits,
  normalizeDocumentFacts,
} = require('../../../server/services/memory/document_facts');

const owner = { email: 'neo@example.com', name: 'Neo' };

function email(id, title, body, extra = {}) {
  return {
    externalObjectId: id,
    sourceType: 'email',
    title,
    content: `${title}\n${body}`,
    sourceTimestamp: '2026-03-02T09:00:00Z',
    ...extra,
  };
}

const jobAcceptance = email(
  'thread-job',
  'Welcome to Acme GmbH',
  'Participants: HR Acme <hr@acme.de>, Neo <neo@example.com>\nHi Neo, we are delighted you accepted our offer. You start as Data Engineer on 1 April 2026.',
);
const newsletter = email(
  'thread-news',
  'Spring sale: 30% off',
  'Participants: Shop <news@shop.example>\nOnly this weekend, everything 30% off.',
);
const passwordReset = email(
  'thread-reset',
  'Reset your password',
  'Participants: Service <noreply@service.example>\nYour code is 482913.',
);

let ctx;
let AgentEngine;
let providerRequests;

before(() => {
  ctx = createTestRuntime();
  // The engine picks the user's model through the provider selector; a fixed
  // fake keeps these tests off the network.
  providerRequests = [];
  const selectorPath = require.resolve('../../../server/services/ai/provider_selector');
  require.cache[selectorPath] = {
    id: selectorPath,
    filename: selectorPath,
    loaded: true,
    exports: {
      getProviderForUser: async (...args) => {
        providerRequests.push(args);
        return { provider: {}, providerName: 'fake', model: 'fake-model' };
      },
    },
  };
  ({ AgentEngine } = require('../../../server/services/ai/engine'));
});

after(() => teardownTestRuntime(ctx));

test('the prompt names the owner, lists what is known, and states the memory rules', () => {
  const units = buildExtractionUnits([jobAcceptance, newsletter]);
  const prompt = buildDocumentFactsPrompt({
    owner,
    units,
    knownMemories: ['User lives in Berlin.'],
    now: new Date('2026-10-17T00:00:00Z'),
  });

  assert.match(prompt, /Neo <neo@example\.com>/);
  assert.match(prompt, /Today is 2026-10-17/);
  assert.match(prompt, /Already known:\n- User lives in Berlin\./);
  assert.match(prompt, /at most 150 characters/);
  assert.match(prompt, /Not worth remembering: newsletters/);
  assert.match(prompt, /\[1\] email · 2026-03-02T09:00:00Z\nWelcome to Acme GmbH/);
  assert.match(prompt, /\[2\] email/);
  assert.doesNotMatch(prompt, /evidence/);
});

test('only facts that pass the memory rules and cite a real source are kept', () => {
  const units = buildExtractionUnits([jobAcceptance]);
  const fact = (memory, extra = {}) => ({
    memory,
    subject: 'User',
    predicate: 'works at',
    object: 'Acme GmbH',
    category: 'identity',
    source: 1,
    ...extra,
  });

  const facts = normalizeDocumentFacts({
    facts: [
      fact('User works at Acme GmbH as a Data Engineer since April 2026.'),
      fact('User works at Acme GmbH as a Data Engineer since April 2026.'),
      fact(`User ${'x'.repeat(160)}`),
      fact('User has a fact from a source that does not exist.', { source: 9 }),
      fact('User has no predicate.', { predicate: '' }),
    ],
  }, units);

  assert.equal(facts.length, 1);
  assert.equal(facts[0].candidate.memory, 'User works at Acme GmbH as a Data Engineer since April 2026.');
  assert.equal(facts[0].document, jobAcceptance);
});

test('sources are batched by size and long documents are read in chunks', () => {
  const long = email('doc-long', 'Handbook', 'Paragraph.\n\n'.repeat(900));
  const units = buildExtractionUnits([jobAcceptance, long]);
  assert.ok(units.length > 2);
  assert.ok(units.slice(1).every((unit) => unit.document === long));

  const batches = batchUnits(units, 3000);
  assert.ok(batches.length > 1);
  assert.deepEqual(batches.flat(), units);
});

test('the engine learns facts per batch, carries them forward as known, and stores provenance', async () => {
  const engine = new AgentEngine(null);
  const saved = [];
  const knownQueries = [];
  engine.memoryManager = {
    listKnownMemories: async (_userId, { query }) => {
      knownQueries.push(query);
      return ['User lives in Berlin.'];
    },
    consolidateMemoryCandidates: async (_userId, candidates, options) => {
      saved.push({ candidates, options });
      return [`memory-${saved.length}`];
    },
  };
  const prompts = [];
  engine.requestStructuredJson = async ({ prompt, normalize }) => {
    prompts.push(prompt);
    const raw = prompts.length === 1
      ? {
        facts: [{
          memory: 'User accepted a Data Engineer job at Acme GmbH, starting April 2026.',
          subject: 'User',
          predicate: 'works at',
          object: 'Acme GmbH',
          category: 'identity',
          importance: 8,
          confidence: 0.9,
          source: 1,
        }],
      }
      : { facts: [] };
    return { value: normalize(raw) };
  };
  const progress = [];
  const longNewsletter = email('thread-news', 'Spring sale', 'Only this weekend.\n\n'.repeat(700));

  const result = await engine.extractDocumentFacts(1, 'main', {
    documents: [jobAcceptance, longNewsletter, passwordReset],
    owner,
    metadata: { ingestionJobId: 'job-1' },
    onProgress: (done, total) => progress.push([done, total]),
  });

  assert.deepEqual(result.memoryIds, ['memory-1']);
  assert.ok(prompts.length > 1);
  assert.match(prompts[0], /User lives in Berlin\./);
  // What an earlier batch learned is known to every later batch.
  assert.match(prompts[1], /- User accepted a Data Engineer job at Acme GmbH, starting April 2026\./);
  assert.match(knownQueries[0], /Welcome to Acme GmbH/);
  assert.equal(saved.length, 1);
  assert.deepEqual(saved[0].options.sourceRef, {
    sourceType: 'email',
    sourceId: 'thread-job',
    sourceLabel: 'Welcome to Acme GmbH',
  });
  assert.deepEqual(saved[0].options.metadata, { ingestionJobId: 'job-1', trustLevel: 'external_source' });
  assert.deepEqual(progress[0], [0, progress.at(-1)[1]]);
  assert.equal(progress.at(-1)[0], progress.at(-1)[1]);
  assert.equal(providerRequests.length, 1);
});

test('the engine reports a failure when no batch could be read', async () => {
  const engine = new AgentEngine(null);
  engine.memoryManager = {
    listKnownMemories: async () => [],
    consolidateMemoryCandidates: async () => [],
  };
  engine.requestStructuredJson = async () => {
    throw new Error('model unavailable');
  };

  await assert.rejects(
    engine.extractDocumentFacts(1, 'main', { documents: [jobAcceptance], owner }),
    /model unavailable/,
  );
});

test('ingesting documents stores them as sources and never as memories', async () => {
  const user = await createTestUser(ctx.db, { username: 'document_facts_user' });
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const { MemoryIngestionService } = require('../../../server/services/memory/ingestion');
  const memoryManager = new MemoryManager();
  const extractCalls = [];
  const service = new MemoryIngestionService({
    memoryManager,
    extractFacts: async (userId, agentId, options) => {
      extractCalls.push(options);
      return { memoryIds: [] };
    },
  });

  const result = await service.ingestDocuments(user.userId, [jobAcceptance, newsletter], {
    sourceType: 'email',
    providerKey: 'google_workspace',
    sourceAccount: 'neo@example.com',
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.documentIds.length, 2);
  assert.equal(memoryManager.listMemories(user.userId, { limit: 50 }).length, 0);
  assert.equal(extractCalls.length, 1);
  assert.deepEqual(extractCalls[0].owner, { email: 'neo@example.com' });
  assert.deepEqual(
    extractCalls[0].documents.map((document) => document.externalObjectId),
    ['thread-job', 'thread-news'],
  );
});

test('a memory longer than 150 characters is refused and a reworded fact is a duplicate', async () => {
  const user = await createTestUser(ctx.db, { username: 'memory_limit_user' });
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const memoryManager = new MemoryManager();

  assert.equal(await memoryManager.saveMemory(user.userId, `User ${'x'.repeat(150)}`), null);

  const fact = (memory, relation = 'new', object = 'Acme GmbH') => ({
    memory,
    subject: 'User',
    predicate: 'works at',
    object,
    relation,
    category: 'identity',
    confidence: 0.9,
  });
  const [first] = await memoryManager.consolidateMemoryCandidates(user.userId, [
    fact('User works at Acme GmbH as a Data Engineer.'),
  ]);
  const [again] = await memoryManager.consolidateMemoryCandidates(user.userId, [
    fact('User works at Acme GmbH as Data Engineer.'),
  ]);
  const [moved] = await memoryManager.consolidateMemoryCandidates(user.userId, [
    fact('User works at Globex Corp as a Data Engineer.', 'updates', 'Globex Corp'),
  ]);

  assert.equal(again, first);
  assert.notEqual(moved, first);
  assert.equal(memoryManager.listMemories(user.userId, { limit: 50 }).length, 2);
});
