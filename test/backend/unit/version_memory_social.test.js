'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const childProcess = require('node:child_process');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('version info caches git metadata reads', () => {
  const versionPath = require.resolve('../../../server/utils/version');
  const originalExecSync = childProcess.execSync;
  delete require.cache[versionPath];
  let callCount = 0;
  childProcess.execSync = (command) => {
    callCount += 1;
    if (command.includes('describe')) return 'v1.2.3\n';
    if (command.includes('rev-parse --short')) return 'abc123\n';
    if (command.includes('abbrev-ref')) return 'main\n';
    throw new Error(`unexpected command: ${command}`);
  };
  try {
    const { getVersionInfo } = require('../../../server/utils/version');
    assert.equal(getVersionInfo().gitVersion, '1.2.3');
    assert.equal(getVersionInfo().gitSha, 'abc123');
    assert.equal(getVersionInfo().gitBranch, 'main');
    assert.equal(getVersionInfo().gitVersion, '1.2.3');
    assert.equal(callCount, 3);
  } finally {
    childProcess.execSync = originalExecSync;
    delete require.cache[versionPath];
  }
});

test('memory ingestion writes typed documents and materialized views', async () => {
  ctx = createTestRuntime();
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const { MemoryIngestionService, sourceTypesForConnection } = require('../../../server/services/memory/ingestion');
  const { buildAssistantFocusSnapshot } = require('../../../server/services/widgets/focus_widget');
  const user = await createTestUser(ctx.db, { username: 'memory_user' });
  const agentId = resolveAgentId(user.userId, null);
  const memoryManager = new MemoryManager();
  const service = new MemoryIngestionService({ memoryManager, intervalMs: 60_000 });

  const result = await service.ingestDocuments(user.userId, [{
    externalObjectId: 'thread-123',
    sourceType: 'email',
    normalizedType: 'email',
    title: 'Launch review',
    content: 'The launch review moved to Friday. Alice owns the deck and Bob owns QA.',
    sourceAccount: 'team@example.com',
    salience: 8,
  }], {
    agentId,
    sourceType: 'email',
    providerKey: 'google_workspace',
    sourceAccount: 'team@example.com',
  });

  assert.equal(result.status, 'completed');
  assert.equal(result.documentIds.length, 1);
  assert.equal(memoryManager.listIngestionDocuments(user.userId, { agentId }).length, 1);
  const recall = await memoryManager.recallMemory(user.userId, 'Who owns the deck?', 3, { agentId });
  assert.equal(recall.some((memory) => memory.content.includes('Alice')), true);
  assert.ok(recall.some((memory) => memory.entities.some((entity) => entity.name.includes('Alice'))));
  assert.ok(memoryManager.getMemoryStats(user.userId, { agentId }).facts > 0);
  assert.ok(memoryManager.listEntities(user.userId, { agentId }).some((entity) => entity.name.includes('Alice')));
  assert.ok(memoryManager.listKnowledgeViews(user.userId, { agentId }).length > 0);
  assert.ok(buildAssistantFocusSnapshot(memoryManager, user.userId, agentId).recentKnowledgeChanges.length > 0);
  assert.deepEqual(sourceTypesForConnection('google_workspace', 'gmail'), ['email']);
});

test('memory ingestion stores layout segment metadata on source chunks', async () => {
  ctx = createTestRuntime();
  const { resolveAgentId } = require('../../../server/services/agents/manager');
  const { MemoryManager } = require('../../../server/services/memory/manager');
  const { MemoryIngestionService } = require('../../../server/services/memory/ingestion');
  const user = await createTestUser(ctx.db, { username: 'layout_memory_user' });
  const agentId = resolveAgentId(user.userId, null);
  const memoryManager = new MemoryManager();
  const service = new MemoryIngestionService({ memoryManager, intervalMs: 60_000 });

  const result = await service.ingestDocuments(user.userId, [{
    externalObjectId: 'deck-456',
    sourceType: 'docs',
    normalizedType: 'docs',
    title: 'Architecture deck',
    content: [
      'Architecture Overview',
      'The service uses workers for document parsing.',
      'Figure 1. Pipeline',
      'Diagram showing API, queue, worker, and memory storage.',
    ].join('\n'),
    payload: {
      segments: [
        { id: 'seg-title', type: 'Title', text: 'Architecture Overview', pageNumber: 1 },
        {
          id: 'seg-text',
          type: 'Text',
          text: 'The service uses workers for document parsing.',
          pageNumber: 1,
        },
        {
          id: 'seg-caption',
          type: 'Caption',
          text: 'Figure 1. Pipeline',
          pageNumber: 2,
          bbox: { left: 40, top: 500, width: 220, height: 28 },
        },
        {
          id: 'seg-picture',
          type: 'Picture',
          text: 'Diagram showing API, queue, worker, and memory storage.',
          pageNumber: 2,
          bbox: { left: 30, top: 120, width: 540, height: 360 },
        },
      ],
    },
  }], {
    agentId,
    sourceType: 'docs',
    providerKey: 'local_test',
  });

  assert.equal(result.status, 'completed');
  const rows = ctx.db.prepare(
    `SELECT metadata_json
     FROM memory_source_chunks
     WHERE document_id = ?
     ORDER BY chunk_index`
  ).all(result.documentIds[0]);
  assert.equal(rows.length, 1);
  const metadata = JSON.parse(rows[0].metadata_json);
  assert.deepEqual(metadata.segmentIds, ['seg-title', 'seg-text', 'seg-caption', 'seg-picture']);
  assert.deepEqual(metadata.pageNumbers, [1, 2]);
  assert.ok(metadata.segmentTypes.includes('Picture'));
  assert.equal(metadata.bboxes.length, 2);

  const recall = await memoryManager.recallMemory(user.userId, 'What parses documents?', 3, { agentId });
  assert.equal(recall.some((memory) => memory.content.includes('workers for document parsing')), true);
});

test('social video utilities normalize URLs, captions, frames, metadata, and result shape', () => {
  const { normalizeAndDetectPlatform } = require('../../../server/services/social_video/url');
  const { pickCaptionTrack, parseCaptionText, decideTranscriptPath } = require('../../../server/services/social_video/captions');
  const { pickDeterministicFrameSecond, normalizeFrameReference } = require('../../../server/services/social_video/frame');
  const { extractPublicMetadataFromHtml } = require('../../../server/services/social_video/metadata');
  const { shapeSocialVideoResult } = require('../../../server/services/social_video/result');

  assert.deepEqual(normalizeAndDetectPlatform('youtu.be/abc123?si=bad').platform, 'youtube');
  assert.throws(() => normalizeAndDetectPlatform('example.com/video'), /Unsupported/);
  const track = pickCaptionTrack({ en: [{ url: 'https://example.com/a.vtt', ext: 'vtt' }] }, ['en']);
  assert.equal(track.url, 'https://example.com/a.vtt');
  assert.equal(parseCaptionText('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nHello <b>world</b>', 'vtt'), 'Hello world');
  assert.deepEqual(decideTranscriptPath({ captionTrack: track }), { mode: 'captions', reason: 'captions_present' });
  assert.equal(pickDeterministicFrameSecond(300), 99);
  assert.equal(normalizeFrameReference({ url: 'file.png', byteSize: '12' }).byteSize, 12);
  assert.equal(extractPublicMetadataFromHtml('<title>A &amp; B</title>', 'https://x.test').title, 'A & B');
  const shaped = shapeSocialVideoResult({ platform: 'youtube', errors: ['blocked'], metadata: [] });
  assert.equal(shaped.partial, true);
  assert.deepEqual(shaped.metadata, {});
});
