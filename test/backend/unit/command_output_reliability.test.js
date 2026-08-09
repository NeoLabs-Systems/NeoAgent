'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Readable } = require('node:stream');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { CommandOutputAccumulator } = require('../../../server/services/cli/output_accumulator');
const { uploadDesktopCommandOutput } = require('../../../server/services/desktop/command_output_upload');

let ctx;
let ownerId;
let otherId;
let ArtifactStore;

before(async () => {
  ctx = createTestRuntime();
  ownerId = (await createTestUser(ctx.db, { username: 'artifact_owner' })).userId;
  otherId = (await createTestUser(ctx.db, { username: 'artifact_other' })).userId;
  ({ ArtifactStore } = require('../../../server/services/artifacts/store'));
});

after(() => teardownTestRuntime(ctx));

test('command output preview keeps startup and terminal output', () => {
  const accumulator = new CommandOutputAccumulator({
    maxArtifactBytes: 1_024,
    stdoutPreviewBytes: 40,
    stderrPreviewBytes: 20,
  });
  accumulator.append('stdout', Buffer.from('START-'));
  accumulator.append('stdout', Buffer.from('x'.repeat(100)));
  accumulator.append('stdout', Buffer.from('-END'));
  const result = accumulator.finalize();
  try {
    assert.equal(result.truncated, true);
    assert.match(result.stdout, /^START-/);
    assert.match(result.stdout, /-END$/);
    assert.equal(result.stdoutBytes, 110);
    assert.equal(result.outputFileComplete, true);
    assert.match(fs.readFileSync(result.outputFilePath, 'utf8'), /START-/);
    assert.match(fs.readFileSync(result.outputFilePath, 'utf8'), /-END/);
  } finally {
    fs.rmSync(path.dirname(result.outputFilePath), { recursive: true, force: true });
  }
});

test('oversized command artifact is explicitly bounded head-and-tail evidence', () => {
  const accumulator = new CommandOutputAccumulator({
    maxArtifactBytes: 128,
    stdoutPreviewBytes: 20,
  });
  accumulator.append('stdout', Buffer.from(`HEAD-${'z'.repeat(300)}-TAIL`));
  const result = accumulator.finalize();
  try {
    const stored = fs.readFileSync(result.outputFilePath, 'utf8');
    assert.equal(result.outputFileComplete, false);
    assert.ok(result.outputFileByteSize <= 128);
    assert.match(stored, /^\[stdout\]\nHEAD-/);
    assert.match(stored, /artifact bounded/);
    assert.match(stored, /-TAIL$/);
  } finally {
    fs.rmSync(path.dirname(result.outputFilePath), { recursive: true, force: true });
  }
});

test('artifact reads are owner scoped, ranged, and binary safe', async () => {
  const store = new ArtifactStore({ rootDir: path.join(ctx.dir, 'artifact-test') });
  const textArtifact = store.createTextArtifact(ownerId, {
    kind: 'command-output',
    contentType: 'text/plain; charset=utf-8',
    content: 'one\ntwo\nthree\nfour',
  });
  const ranged = store.readTextArtifact(ownerId, textArtifact.artifactId, {
    startLine: 2,
    endLine: 3,
  });
  assert.equal(ranged.content, 'two\nthree');
  assert.deepEqual(ranged.rangeShown, { startLine: 2, endLine: 3 });
  assert.deepEqual(store.readTextArtifact(otherId, textArtifact.artifactId), {
    error: 'Artifact not found.',
  });

  const binary = await store.createBufferArtifact(ownerId, {
    kind: 'binary',
    contentType: 'application/octet-stream',
    extension: 'bin',
    content: Buffer.from([0, 1, 2, 3]),
  });
  const binaryRead = store.readTextArtifact(ownerId, binary.artifactId);
  assert.equal(binaryRead.binary, true);
  assert.equal(binaryRead.content, undefined);
  assert.equal(binaryRead.byteSize, 4);
});

function fakeUploadStore(root) {
  const records = new Map();
  return {
    records,
    allocateFile(_userId, options) {
      const artifactId = crypto.randomUUID();
      const storagePath = path.join(root, `${artifactId}.log`);
      records.set(artifactId, { storagePath, options });
      return { artifactId, storagePath, url: `/artifact/${artifactId}` };
    },
    finalizeFile(artifactId, storagePath) {
      return {
        artifactId,
        url: `/artifact/${artifactId}`,
        byteSize: fs.statSync(storagePath).size,
      };
    },
    deleteArtifact(_userId, artifactId) {
      const record = records.get(artifactId);
      if (record) fs.rmSync(record.storagePath, { force: true });
      records.delete(artifactId);
    },
  };
}

test('desktop command evidence upload validates correlation, bytes, and checksum', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-output-upload-'));
  const store = fakeUploadStore(root);
  const content = Buffer.from('complete command evidence');
  const uploadStates = new Map();
  const registry = {
    claimPendingCommandOutput(userId, deviceId, commandId) {
      assert.equal(userId, ownerId);
      if (deviceId !== 'device' || commandId === 'missing' || uploadStates.has(commandId)) {
        return null;
      }
      uploadStates.set(commandId, 'uploading');
      return { deviceId, commandId, sessionId: 'session', runId: 'run', stepId: 'step' };
    },
    finishPendingCommandOutput(_userId, _deviceId, commandId, { success }) {
      if (uploadStates.get(commandId) !== 'uploading') return false;
      if (success) uploadStates.set(commandId, 'completed');
      else uploadStates.delete(commandId);
      return true;
    },
  };
  try {
    const artifact = await uploadDesktopCommandOutput({
      userId: ownerId,
      deviceId: 'device',
      commandId: 'command',
      contentLength: content.length,
      checksum: crypto.createHash('sha256').update(content).digest('hex'),
      complete: true,
      stdoutBytes: content.length,
      stderrBytes: 0,
      stream: Readable.from([content]),
      registry,
      artifactStore: store,
    });
    assert.equal(artifact.byteSize, content.length);
    assert.equal(artifact.complete, true);
    assert.equal(store.records.get(artifact.artifactId).options.metadata.runId, 'run');

    await assert.rejects(
      uploadDesktopCommandOutput({
        userId: ownerId,
        deviceId: 'device',
        commandId: 'bad-checksum',
        contentLength: content.length,
        checksum: '0'.repeat(64),
        complete: true,
        stream: Readable.from([content]),
        registry,
        artifactStore: store,
      }),
      /checksum mismatch/,
    );
    assert.equal(store.records.size, 1, 'failed upload row and partial file should be removed');

    const disconnected = Readable.from((async function* interruptedUpload() {
      yield content.subarray(0, 5);
      throw new Error('desktop upload disconnected');
    }()));
    await assert.rejects(
      uploadDesktopCommandOutput({
        userId: ownerId,
        deviceId: 'device',
        commandId: 'disconnected',
        contentLength: content.length,
        checksum: crypto.createHash('sha256').update(content).digest('hex'),
        stream: disconnected,
        registry,
        artifactStore: store,
      }),
      /desktop upload disconnected/,
    );
    assert.equal(store.records.size, 1, 'disconnected upload should remove partial evidence');
    assert.equal(uploadStates.has('disconnected'), false);

    await assert.rejects(
      uploadDesktopCommandOutput({
        userId: ownerId,
        deviceId: 'wrong-device',
        commandId: 'missing',
        contentLength: content.length,
        checksum: crypto.createHash('sha256').update(content).digest('hex'),
        stream: Readable.from([content]),
        registry,
        artifactStore: store,
      }),
      /not tied to an active desktop command/,
    );
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
