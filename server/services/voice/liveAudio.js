'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { randomUUID } = require('crypto');

function normalizeAudioMimeType(mimeType, fallback = 'audio/pcm;rate=16000;channels=1') {
  const normalized = String(mimeType || '').trim().toLowerCase();
  return normalized || fallback;
}

function parsePcmMimeType(mimeType) {
  const normalized = normalizeAudioMimeType(mimeType);
  if (!normalized.startsWith('audio/pcm')) {
    return null;
  }

  const rateMatch = normalized.match(/(?:^|[;\s])rate=(\d+)/);
  const channelsMatch = normalized.match(/(?:^|[;\s])channels=(\d+)/);

  const sampleRate = Number(rateMatch?.[1] || 16000);
  const channels = Number(channelsMatch?.[1] || 1);

  if (!Number.isFinite(sampleRate) || sampleRate <= 0) return null;
  if (!Number.isFinite(channels) || channels <= 0) return null;

  return {
    sampleRate,
    channels,
    bitsPerSample: 16,
  };
}

function wrapPcm16AsWav(audioBytes, format = {}) {
  const payload = Buffer.isBuffer(audioBytes) ? audioBytes : Buffer.from(audioBytes || []);
  const sampleRate = Number(format.sampleRate || 16000);
  const channels = Number(format.channels || 1);
  const bitsPerSample = Number(format.bitsPerSample || 16);
  const blockAlign = channels * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const header = Buffer.alloc(44);

  header.write('RIFF', 0, 4, 'ascii');
  header.writeUInt32LE(36 + payload.length, 4);
  header.write('WAVE', 8, 4, 'ascii');
  header.write('fmt ', 12, 4, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36, 4, 'ascii');
  header.writeUInt32LE(payload.length, 40);

  return Buffer.concat([header, payload]);
}

function fileExtensionForMimeType(mimeType) {
  const normalized = normalizeAudioMimeType(mimeType);
  if (normalized.startsWith('audio/mpeg') || normalized.includes('mp3')) return 'mp3';
  if (normalized.startsWith('audio/webm')) return 'webm';
  if (normalized.startsWith('audio/ogg')) return 'ogg';
  if (normalized.startsWith('audio/wav')) return 'wav';
  if (normalized.startsWith('audio/mp4') || normalized.includes('m4a')) return 'm4a';
  return 'wav';
}

async function writeTempAudioFile(audioBytes, mimeType) {
  const pcmFormat = parsePcmMimeType(mimeType);
  const payload = pcmFormat ? wrapPcm16AsWav(audioBytes, pcmFormat) : Buffer.from(audioBytes || []);
  const ext = pcmFormat ? 'wav' : fileExtensionForMimeType(mimeType);
  const filePath = path.join(os.tmpdir(), `neoagent-voice-${randomUUID()}.${ext}`);
  await fs.promises.writeFile(filePath, payload);
  return {
    filePath,
    mimeType: pcmFormat ? 'audio/wav' : normalizeAudioMimeType(mimeType),
  };
}

async function removeTempFile(filePath) {
  if (!filePath) return;
  try {
    await fs.promises.unlink(filePath);
  } catch {
    // Best-effort cleanup only.
  }
}

module.exports = {
  normalizeAudioMimeType,
  parsePcmMimeType,
  wrapPcm16AsWav,
  writeTempAudioFile,
  removeTempFile,
};
