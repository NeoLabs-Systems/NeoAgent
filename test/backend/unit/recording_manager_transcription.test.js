'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;
let user;
let RecordingManager;
let originalFetch;
let originalApiKey;
let fetchCalls;

const io = { to: () => ({ emit() {} }) };

function cannedDeepgramResponse() {
  return {
    ok: true,
    status: 200,
    async text() {
      return '';
    },
    async json() {
      return {
        results: {
          utterances: [
            {
              start: 0,
              end: 2,
              confidence: 0.95,
              transcript: 'hello from the merged stream',
              words: [],
            },
          ],
          channels: [
            { alternatives: [{ transcript: 'hello from the merged stream', words: [] }] },
          ],
        },
      };
    },
  };
}

beforeEach(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
  originalApiKey = process.env.DEEPGRAM_API_KEY;
  process.env.DEEPGRAM_API_KEY = 'test-key';
  originalFetch = global.fetch;
  fetchCalls = [];
  global.fetch = async (url, options) => {
    fetchCalls.push({ url, body: options?.body, headers: options?.headers });
    return cannedDeepgramResponse();
  };
  ({ RecordingManager } = require('../../../server/services/recordings/manager'));
});

afterEach(() => {
  global.fetch = originalFetch;
  if (originalApiKey == null) {
    delete process.env.DEEPGRAM_API_KEY;
  } else {
    process.env.DEEPGRAM_API_KEY = originalApiKey;
  }
  teardownTestRuntime(ctx);
});

test('web webm chunks are concatenated into a single container before transcription', async () => {
  const manager = new RecordingManager(io);
  const session = manager.createSession(user.userId, {
    platform: 'web',
    sources: [
      {
        sourceKey: 'microphone',
        sourceKind: 'microphone',
        mediaKind: 'audio',
        mimeType: 'audio/webm',
      },
    ],
  });

  const chunkA = Buffer.from('AAAA-webm-header-and-first-cluster', 'utf8');
  const chunkB = Buffer.from('BBBB-headerless-continuation-cluster', 'utf8');
  manager.appendChunk(user.userId, session.id, {
    sourceKey: 'microphone',
    sequenceIndex: 0,
    startMs: 0,
    endMs: 4000,
    mimeType: 'audio/webm',
  }, chunkA);
  manager.appendChunk(user.userId, session.id, {
    sourceKey: 'microphone',
    sequenceIndex: 1,
    startMs: 4000,
    endMs: 8000,
    mimeType: 'audio/webm',
  }, chunkB);

  const result = await manager.processSession(user.userId, session.id, {
    includeInsights: false,
  });

  // Exactly one Deepgram call: the two chunks were merged, not sent per-chunk
  // (the second, headerless chunk would otherwise be undecodable and dropped).
  assert.equal(fetchCalls.length, 1);
  assert.deepEqual(
    Buffer.from(fetchCalls[0].body),
    Buffer.concat([chunkA, chunkB]),
  );
  assert.equal(result.status, 'completed');
  assert.match(result.transcriptText, /hello from the merged stream/);
});

test('a dropped chunk leaves a gap instead of failing the whole recording', async () => {
  const manager = new RecordingManager(io);
  const session = manager.createSession(user.userId, {
    platform: 'web',
    sources: [
      {
        sourceKey: 'microphone',
        sourceKind: 'microphone',
        mediaKind: 'audio',
        mimeType: 'audio/webm',
      },
    ],
  });

  // Sequence 1 never arrives (permanently dropped upload). The server must
  // still accept the later chunk rather than rejecting it as non-contiguous.
  manager.appendChunk(user.userId, session.id, {
    sourceKey: 'microphone',
    sequenceIndex: 0,
    startMs: 0,
    endMs: 4000,
    mimeType: 'audio/webm',
  }, Buffer.from('chunk-zero', 'utf8'));

  assert.doesNotThrow(() => {
    manager.appendChunk(user.userId, session.id, {
      sourceKey: 'microphone',
      sequenceIndex: 2,
      startMs: 8000,
      endMs: 12000,
      mimeType: 'audio/webm',
    }, Buffer.from('chunk-two', 'utf8'));
  });

  const result = await manager.processSession(user.userId, session.id, {
    includeInsights: false,
  });

  assert.equal(result.status, 'completed');
  assert.match(result.transcriptText, /hello from the merged stream/);
});

test('duplicate chunk uploads are reported as duplicates, not errors', () => {
  const manager = new RecordingManager(io);
  const session = manager.createSession(user.userId, {
    platform: 'web',
    sources: [
      { sourceKey: 'microphone', sourceKind: 'microphone', mediaKind: 'audio', mimeType: 'audio/webm' },
    ],
  });

  const meta = {
    sourceKey: 'microphone',
    sequenceIndex: 0,
    startMs: 0,
    endMs: 4000,
    mimeType: 'audio/webm',
  };
  const first = manager.appendChunk(user.userId, session.id, meta, Buffer.from('a', 'utf8'));
  const second = manager.appendChunk(user.userId, session.id, meta, Buffer.from('a', 'utf8'));

  assert.equal(first.accepted, true);
  assert.equal(second.duplicate, true);
  assert.equal(second.accepted, false);
});
