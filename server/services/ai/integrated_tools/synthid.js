'use strict';

const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');
const { HOME_DIR } = require('../../../../runtime/paths');
const { resolveUserFileReference } = require('../../files/user_file_access');
const { fetchResponseText } = require('../../network/http');

const DEFAULT_LOCATION = 'us-central1';
const MODEL_ID = 'imageverification@001';
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

function text(value) {
  return String(value || '').trim();
}

function readCredentialProjectId(filePath, fsImpl = fs) {
  if (!filePath) return '';
  try {
    const credentials = JSON.parse(fsImpl.readFileSync(filePath, 'utf8'));
    return text(credentials.project_id || credentials.quota_project_id);
  } catch {
    return '';
  }
}

function defaultAdcPath(env = process.env) {
  if (process.platform === 'win32') {
    const appData = text(env.APPDATA);
    return appData ? path.join(appData, 'gcloud', 'application_default_credentials.json') : '';
  }
  return path.join(HOME_DIR, '.config', 'gcloud', 'application_default_credentials.json');
}

function existingCredentialFile(env = process.env, fsImpl = fs) {
  const candidates = [
    text(env.GOOGLE_APPLICATION_CREDENTIALS),
    defaultAdcPath(env),
  ].filter(Boolean);
  return candidates.find((candidate) => {
    try {
      return fsImpl.statSync(candidate).isFile();
    } catch {
      return false;
    }
  }) || '';
}

function resolveConfiguredGoogleAuth(options = {}) {
  const env = options.env || process.env;
  const fsImpl = options.fsImpl || fs;
  const apiKey = text(env.GOOGLE_AI_KEY || env.GOOGLE_API_KEY);
  const credentialFile = existingCredentialFile(env, fsImpl);
  const projectId = text(
    env.GOOGLE_CLOUD_PROJECT
    || env.GCLOUD_PROJECT
    || env.GCP_PROJECT
    || readCredentialProjectId(credentialFile, fsImpl),
  );
  return {
    available: Boolean(projectId && (apiKey || credentialFile)),
    apiKey,
    credentialFile,
    projectId,
  };
}

function isSynthIdDetectorAvailable(options = {}) {
  return resolveConfiguredGoogleAuth(options).available;
}

function assertSupportedLocation(location) {
  if (!/^[a-z][a-z0-9-]*$/.test(location)) {
    throw new Error('Google Cloud location contains unsupported characters.');
  }
}

function imageMimeType(image) {
  if (
    image.length >= 8
    && image.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'image/png';
  }
  if (image.length >= 3 && image[0] === 0xff && image[1] === 0xd8 && image[2] === 0xff) {
    return 'image/jpeg';
  }
  throw new Error('SynthID detection supports PNG and JPEG images only.');
}

function parseDetectorResponse(rawBody) {
  let body;
  try {
    body = JSON.parse(rawBody);
  } catch {
    throw new Error('Google SynthID detector returned invalid JSON.');
  }
  const decision = text(body?.predictions?.[0]?.decision).toUpperCase();
  if (decision !== 'ACCEPT' && decision !== 'REJECT') {
    throw new Error('Google SynthID detector returned an unrecognized result.');
  }
  return decision;
}

async function resolveGoogleCredentials(options = {}) {
  const configured = resolveConfiguredGoogleAuth(options);
  if (!configured.available) {
    throw new Error('Google Cloud authentication for SynthID detection is not configured.');
  }
  if (configured.apiKey && !configured.credentialFile) {
    return {
      projectId: configured.projectId,
      headers: { 'x-goog-api-key': configured.apiKey },
    };
  }

  const auth = options.auth || new google.auth.GoogleAuth({
    keyFilename: configured.credentialFile || undefined,
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const client = await auth.getClient();
  const tokenResult = await client.getAccessToken();
  const accessToken = text(
    typeof tokenResult === 'string' ? tokenResult : tokenResult?.token,
  );
  if (!accessToken) {
    throw new Error('Google Application Default Credentials did not provide an access token.');
  }
  return {
    projectId: configured.projectId,
    headers: { Authorization: `Bearer ${accessToken}` },
  };
}

async function detectSynthIdWatermark(args = {}, context = {}, options = {}) {
  const imagePath = resolveUserFileReference({
    userId: context.userId,
    reference: args.image_path,
    artifactStore: context.artifactStore,
    workspaceManager: context.workspaceManager,
    label: 'Image',
  });
  const stats = fs.statSync(imagePath);
  if (stats.size > MAX_IMAGE_BYTES) {
    throw new Error('SynthID detection supports images up to 10 MB.');
  }
  const image = fs.readFileSync(imagePath);
  imageMimeType(image);
  const env = options.env || process.env;
  const location = text(
    options.location
    || env.GOOGLE_CLOUD_LOCATION
    || env.VERTEX_AI_LOCATION
    || DEFAULT_LOCATION,
  );
  assertSupportedLocation(location);

  const { projectId, headers } = await resolveGoogleCredentials(options);
  const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/` +
    `${encodeURIComponent(projectId)}/locations/${location}/publishers/google/models/${MODEL_ID}:predict`;
  const fetchText = options.fetchResponseText || fetchResponseText;
  const { response, text: responseText } = await fetchText(endpoint, {
    method: 'POST',
    headers: {
      ...headers,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      instances: [{
        image: {
          bytesBase64Encoded: image.toString('base64'),
        },
      }],
      parameters: {
        watermarkVerification: true,
      },
    }),
    signal: context.signal,
    timeoutMs: 60_000,
    maxResponseBytes: 1024 * 1024,
    serviceName: 'Google SynthID detector',
  });
  if (!response.ok) {
    let message = '';
    try {
      message = text(JSON.parse(responseText)?.error?.message);
    } catch {}
    throw new Error(
      `Google SynthID detector returned ${response.status}${message ? `: ${message}` : '.'}`,
    );
  }

  const decision = parseDetectorResponse(responseText);
  const detected = decision === 'ACCEPT';
  return {
    detected,
    detector: 'Google Vertex AI SynthID',
    interpretation: detected
      ? 'A SynthID watermark was detected in this image.'
      : 'No SynthID watermark was detected. This does not prove the image was made by a human or by a non-Google model.',
  };
}

module.exports = {
  MAX_IMAGE_BYTES,
  detectSynthIdWatermark,
  isSynthIdDetectorAvailable,
  parseDetectorResponse,
  resolveConfiguredGoogleAuth,
};
