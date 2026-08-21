'use strict';

const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { afterEach, test } = require('node:test');

const {
  detectSynthIdWatermark,
  parseDetectorResponse,
  resolveConfiguredGoogleAuth,
} = require('../../../server/services/ai/integrated_tools/synthid');
const {
  getIntegratedToolDefinitions,
} = require('../../../server/services/ai/integrated_tools');

const temporaryDirectories = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

function temporaryImage(bytes) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-synthid-'));
  temporaryDirectories.push(directory);
  const imagePath = path.join(directory, 'image.png');
  fs.writeFileSync(imagePath, bytes);
  return imagePath;
}

test('SynthID availability requires usable existing Google auth and a Cloud project', () => {
  const missing = resolveConfiguredGoogleAuth({
    env: {
      GOOGLE_APPLICATION_CREDENTIALS: '/not/a/credential.json',
    },
  });
  assert.equal(missing.available, false);

  const keyed = resolveConfiguredGoogleAuth({
    env: {
      GOOGLE_AI_KEY: 'configured-key',
      GOOGLE_CLOUD_PROJECT: 'configured-project',
      GOOGLE_APPLICATION_CREDENTIALS: '/not/a/credential.json',
    },
  });
  assert.equal(keyed.available, true);
  assert.equal(keyed.projectId, 'configured-project');

  const hiddenTools = getIntegratedToolDefinitions({
    env: { GOOGLE_APPLICATION_CREDENTIALS: '/not/a/credential.json' },
  });
  assert.equal(hiddenTools.some((tool) => tool.name === 'detect_synthid_watermark'), false);

  const visibleTools = getIntegratedToolDefinitions({
    env: {
      GOOGLE_AI_KEY: 'configured-key',
      GOOGLE_CLOUD_PROJECT: 'configured-project',
      GOOGLE_APPLICATION_CREDENTIALS: '/not/a/credential.json',
    },
  });
  assert.equal(visibleTools.some((tool) => tool.name === 'detect_synthid_watermark'), true);
});

test('SynthID availability reads the project from an existing ADC file', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-google-auth-'));
  temporaryDirectories.push(directory);
  const credentialsPath = path.join(directory, 'credentials.json');
  fs.writeFileSync(credentialsPath, JSON.stringify({
    type: 'service_account',
    project_id: 'credential-project',
  }));

  const configured = resolveConfiguredGoogleAuth({
    env: { GOOGLE_APPLICATION_CREDENTIALS: credentialsPath },
  });
  assert.equal(configured.available, true);
  assert.equal(configured.credentialFile, credentialsPath);
  assert.equal(configured.projectId, 'credential-project');
});

test('SynthID detector submits owned PNG bytes to the official Vertex model', async () => {
  const imagePath = temporaryImage(Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00,
  ]));
  let request;
  const result = await detectSynthIdWatermark({ image_path: 'image.png' }, {
    userId: 7,
    workspaceManager: {
      resolvePath(userId, reference) {
        assert.equal(userId, 7);
        assert.equal(reference, 'image.png');
        return imagePath;
      },
    },
  }, {
    env: {
      GOOGLE_AI_KEY: 'configured-key',
      GOOGLE_CLOUD_PROJECT: 'configured-project',
      GOOGLE_APPLICATION_CREDENTIALS: '/not/a/credential.json',
    },
    location: 'us-central1',
    fetchResponseText: async (url, options) => {
      request = { url, options };
      return {
        response: { ok: true, status: 200 },
        text: JSON.stringify({ predictions: [{ decision: 'ACCEPT' }] }),
      };
    },
  });

  assert.equal(result.detected, true);
  assert.match(request.url, /projects\/configured-project\/locations\/us-central1/);
  assert.match(request.url, /models\/imageverification@001:predict$/);
  assert.equal(request.options.headers['x-goog-api-key'], 'configured-key');
  const body = JSON.parse(request.options.body);
  assert.equal(
    body.instances[0].image.bytesBase64Encoded,
    fs.readFileSync(imagePath).toString('base64'),
  );
  assert.deepEqual(body.parameters, { watermarkVerification: true });
});

test('SynthID response parser rejects ambiguous detector output', () => {
  assert.equal(parseDetectorResponse('{"predictions":[{"decision":"REJECT"}]}'), 'REJECT');
  assert.throws(
    () => parseDetectorResponse('{"predictions":[{}]}'),
    /unrecognized result/,
  );
});
