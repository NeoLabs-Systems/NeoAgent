'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { EventEmitter } = require('node:events');
const fs = require('node:fs');
const https = require('node:https');
const os = require('node:os');
const path = require('node:path');
const { Readable } = require('node:stream');
const { afterEach, test } = require('node:test');

const {
  downloadFile,
  resolveCommandLineToolsRelease,
} = require('../../../server/services/android/sdk_download');

const originalHttpsGet = https.get;

afterEach(() => {
  https.get = originalHttpsGet;
});

function mockDownload(payload) {
  https.get = (_url, callback) => {
    const request = new EventEmitter();
    request.setTimeout = () => {};
    request.destroy = (error) => {
      if (error) queueMicrotask(() => request.emit('error', error));
    };
    queueMicrotask(() => {
      const response = Readable.from([payload]);
      response.statusCode = 200;
      response.headers = { 'content-length': String(payload.length) };
      callback(response);
    });
    return request;
  };
}

test('resolves the current architecture-specific official command-line tools', () => {
  const armMac = resolveCommandLineToolsRelease('darwin', 'arm64');
  const intelMac = resolveCommandLineToolsRelease('darwin', 'x64');
  const linux = resolveCommandLineToolsRelease('linux', 'x64');
  const windows = resolveCommandLineToolsRelease('win32', 'x64');

  assert.match(armMac.url, /commandlinetools-mac_arm64-15859902_latest\.zip$/);
  assert.match(intelMac.url, /commandlinetools-mac_x86_64-15859902_latest\.zip$/);
  assert.match(linux.url, /commandlinetools-linux-15859902_latest\.zip$/);
  assert.match(windows.url, /commandlinetools-win-15859902_latest\.zip$/);
  for (const release of [armMac, intelMac, linux, windows]) {
    assert.match(release.sha256, /^[a-f0-9]{64}$/);
  }
  assert.throws(
    () => resolveCommandLineToolsRelease('darwin', 'ppc64'),
    /macOS architecture/,
  );
});

test('publishes a download only after its SHA-256 checksum matches', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-sdk-download-test-'));
  const destination = path.join(directory, 'tools.zip');
  const payload = Buffer.from('verified Android command-line tools');
  mockDownload(payload);

  try {
    await downloadFile('https://dl.google.com/android/repository/tools.zip', destination, {
      expectedSha256: crypto.createHash('sha256').update(payload).digest('hex'),
    });
    assert.deepEqual(fs.readFileSync(destination), payload);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('rejects a checksum mismatch without leaving a published or partial archive', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-sdk-download-test-'));
  const destination = path.join(directory, 'tools.zip');
  mockDownload(Buffer.from('tampered archive'));

  try {
    await assert.rejects(
      downloadFile('https://dl.google.com/android/repository/tools.zip', destination, {
        expectedSha256: '0'.repeat(64),
      }),
      { code: 'ANDROID_SDK_CHECKSUM_MISMATCH' },
    );
    assert.equal(fs.existsSync(destination), false);
    assert.deepEqual(fs.readdirSync(directory), []);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('preserves the caller abort reason while waiting for an SDK response', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-sdk-download-test-'));
  const destination = path.join(directory, 'tools.zip');
  const controller = new AbortController();
  const reason = new Error('startup was cancelled');
  https.get = () => {
    const request = new EventEmitter();
    request.setTimeout = () => {};
    request.destroy = (error) => queueMicrotask(() => request.emit('error', error));
    return request;
  };

  try {
    const pending = downloadFile('https://dl.google.com/android/repository/tools.zip', destination, {
      expectedSha256: '0'.repeat(64),
      signal: controller.signal,
    });
    controller.abort(reason);
    await assert.rejects(pending, (error) => error === reason);
    assert.deepEqual(fs.readdirSync(directory), []);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
