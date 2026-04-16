'use strict';

const { sanitizeError } = require('../../utils/security');
const { readChunkBody } = require('./readChunkBody');

const CHUNK_READ_OPTIONS = Object.freeze({
  maxSize: 10 * 1024 * 1024,
  timeout: 30000,
});

async function readWearableAudioChunk(req) {
  const rawBuffer = await readChunkBody(req, CHUNK_READ_OPTIONS);
  if (rawBuffer.length === 0) {
    throw new Error('Empty payload');
  }
  return rawBuffer;
}

function requireCharacteristicUuid(req, errorMessage = 'Missing characteristicUuid') {
  const characteristicUuid = req.headers['x-characteristic-uuid'] || req.query.characteristicUuid;
  if (!characteristicUuid || String(characteristicUuid).trim().length === 0) {
    throw new Error(errorMessage);
  }
  return String(characteristicUuid);
}

function requireMacAddress(value, errorMessage = 'macAddress is required') {
  const macAddress = String(value || '').trim();
  if (!macAddress) {
    throw new Error(errorMessage);
  }
  return macAddress;
}

function requireWearableManager(appLocals, errorMessage = 'Wearable manager unavailable') {
  const manager = appLocals?.wearableManager;
  if (!manager) {
    throw new Error(errorMessage);
  }
  return manager;
}

function buildIngestHttpResponse(ingestResult) {
  if (!ingestResult) {
    return {
      status: 202,
      body: {
        success: true,
        accepted: false,
        ignored: true,
      },
    };
  }

  return {
    status: ingestResult.duplicate ? 202 : 201,
    body: {
      success: true,
      ...ingestResult,
    },
  };
}

function toWearableRouteError(err) {
  const message = sanitizeError(err);
  if (/payload too large/i.test(message)) {
    return { status: 413, message };
  }
  if (/request timeout/i.test(message)) {
    return { status: 408, message };
  }
  if (/empty payload|missing characteristicuuid|required/i.test(message)) {
    return { status: 400, message };
  }
  if (/unavailable/i.test(message)) {
    return { status: 503, message };
  }
  return {
    status: /not found/i.test(message) ? 404 : 500,
    message,
  };
}

module.exports = {
  buildIngestHttpResponse,
  requireMacAddress,
  requireWearableManager,
  readWearableAudioChunk,
  requireCharacteristicUuid,
  toWearableRouteError,
};
