'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

// Each WAV chunk is stored as a self-contained file with its own 44-byte RIFF
// header. The playback route used to stream them back-to-back, producing a file
// whose declared length only covered the first chunk so players stopped after
// ~one chunk. It now rebuilds a single continuous WAV.
describe('recording audio playback route', () => {
  const SAMPLE_RATE = 16000;
  const CHANNELS = 1;
  const BITS = 16;

  let ctx;
  let app;
  let client;
  let user;
  let manager;
  let sessionId;
  let pcmOne;
  let pcmTwo;

  function buildWav(pcm) {
    const blockAlign = CHANNELS * (BITS / 8);
    const header = Buffer.alloc(44);
    header.write('RIFF', 0, 4, 'ascii');
    header.writeUInt32LE(36 + pcm.length, 4);
    header.write('WAVE', 8, 4, 'ascii');
    header.write('fmt ', 12, 4, 'ascii');
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20);
    header.writeUInt16LE(CHANNELS, 22);
    header.writeUInt32LE(SAMPLE_RATE, 24);
    header.writeUInt32LE(SAMPLE_RATE * blockAlign, 28);
    header.writeUInt16LE(blockAlign, 32);
    header.writeUInt16LE(BITS, 34);
    header.write('data', 36, 4, 'ascii');
    header.writeUInt32LE(pcm.length, 40);
    return Buffer.concat([header, pcm]);
  }

  function binaryParser(res, callback) {
    const chunks = [];
    res.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
    res.on('end', () => callback(null, Buffer.concat(chunks)));
  }

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    user = await createTestUser(ctx.db, { username: 'playback_user' });
    client = agent(app);
    await loginAs(client, user);

    const { RecordingManager } = require('../../server/services/recordings/manager');
    manager = new RecordingManager({ to: () => ({ emit() {} }) });
    const session = manager.createSession(user.userId, {
      platform: 'desktop',
      sources: [
        { sourceKey: 'microphone', sourceKind: 'microphone', mediaKind: 'audio', mimeType: 'audio/wav' },
      ],
    });
    sessionId = session.id;

    pcmOne = Buffer.alloc(640, 1); // 20ms of mono 16-bit @ 16kHz, all 0x01
    pcmTwo = Buffer.alloc(800, 2);
    manager.appendChunk(user.userId, sessionId, {
      sourceKey: 'microphone', sequenceIndex: 0, startMs: 0, endMs: 20, mimeType: 'audio/wav',
    }, buildWav(pcmOne));
    manager.appendChunk(user.userId, sessionId, {
      sourceKey: 'microphone', sequenceIndex: 1, startMs: 20, endMs: 45, mimeType: 'audio/wav',
    }, buildWav(pcmTwo));
  });

  after(() => teardownTestRuntime(ctx));

  test('returns a single valid WAV covering every chunk', async () => {
    const res = await client
      .get(`/api/recordings/${sessionId}/audio/microphone`)
      .buffer(true)
      .parse(binaryParser)
      .expect(200);

    const body = res.body;
    const totalPcm = pcmOne.length + pcmTwo.length;

    // Exactly one header, then all PCM concatenated — not two stacked WAVs.
    assert.equal(body.length, 44 + totalPcm);
    assert.equal(body.toString('ascii', 0, 4), 'RIFF');
    assert.equal(body.toString('ascii', 8, 12), 'WAVE');
    assert.equal(body.toString('ascii', 36, 40), 'data');
    assert.equal(body.readUInt32LE(40), totalPcm, 'data length covers all chunks');
    assert.equal(body.readUInt32LE(4), 36 + totalPcm, 'RIFF size covers all chunks');
    assert.equal(body.readUInt32LE(24), SAMPLE_RATE, 'sample rate preserved');
    assert.deepEqual(body.subarray(44), Buffer.concat([pcmOne, pcmTwo]));
  });
});
