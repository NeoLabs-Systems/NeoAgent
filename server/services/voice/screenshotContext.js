'use strict';

const fs = require('fs/promises');
const os = require('os');
const path = require('path');

const { analyzeImageForUser, resolveImageMimeType } = require('../ai/imageAnalysis');

function extensionForMimeType(mimeType = '') {
  switch (String(mimeType).trim().toLowerCase()) {
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    case 'image/jpg':
    case 'image/jpeg':
    default:
      return 'jpg';
  }
}

async function analyzeVoiceAssistantScreenshot({
  userId,
  agentId = null,
  screenshotBase64,
  screenshotMimeType = 'image/jpeg',
} = {}) {
  const encoded = String(screenshotBase64 || '').trim();
  if (!encoded) {
    return null;
  }

  const mimeType = resolveImageMimeType(
    `screen.${extensionForMimeType(screenshotMimeType)}`,
    screenshotMimeType,
  );
  const buffer = Buffer.from(encoded, 'base64');
  if (!buffer.length) {
    return null;
  }

  const tempDir = await fs.mkdtemp(
    path.join(os.tmpdir(), 'neoagent-voice-screen-'),
  );
  const imagePath = path.join(
    tempDir,
    `capture.${extensionForMimeType(mimeType)}`,
  );

  try {
    await fs.writeFile(imagePath, buffer);
    const result = await analyzeImageForUser({
      userId,
      agentId,
      imagePath,
      mimeType,
      question:
        'Describe the user’s current screen for a voice assistant. Focus on the visible app, important UI state, readable text, alerts, selected items, and anything relevant to the user’s spoken request.',
    });
    return {
      ...result,
      mimeType,
    };
  } finally {
    await fs.rm(tempDir, { recursive: true, force: true });
  }
}

module.exports = {
  analyzeVoiceAssistantScreenshot,
};
