'use strict';

const fs = require('fs');
const path = require('path');

const { getProviderForUser } = require('./engine');
const { createProviderInstance, getSupportedModels } = require('./models');
const { withProviderRetry } = require('./providerRetry');

function resolveImageMimeType(imagePath, overrideMimeType = null) {
  const normalized = String(overrideMimeType || '').trim().toLowerCase();
  if (normalized) {
    return normalized;
  }
  const ext = path.extname(String(imagePath || '')).toLowerCase();
  const mimeMap = {
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
  };
  return mimeMap[ext] || 'image/jpeg';
}

async function analyzeImageForUser({
  userId,
  agentId = null,
  imagePath,
  imageBase64 = null,
  question = 'Describe this image in detail.',
  mimeType = null,
  signal = null,
} = {}) {
  const encodedImage = String(imageBase64 || '').trim();
  if (!encodedImage && !fs.existsSync(imagePath)) {
    throw new Error(`File not found: ${imagePath}`);
  }
  if (encodedImage && encodedImage.length > 8 * 1024 * 1024) {
    throw new Error('Image payload exceeds the analysis limit.');
  }

  const attempted = [];
  const candidates = [];

  try {
    const preferred = await getProviderForUser(userId, '', false, null, {
      agentId,
      signal,
    });
    candidates.push({
      providerName: preferred.providerName,
      provider: preferred.provider,
      model: preferred.model,
    });
  } catch (error) {
    if (signal?.aborted) throw signal.reason || error;
    attempted.push(`default-provider lookup failed: ${error.message}`);
  }

  try {
    const discoveredModels = await getSupportedModels(userId, agentId, { signal });
    for (const discovered of discoveredModels) {
      if (discovered.available === false) continue;
      if (candidates.some((candidate) => candidate.providerName === discovered.provider)) {
        continue;
      }
      try {
        candidates.push({
          providerName: discovered.provider,
          provider: createProviderInstance(discovered.provider, userId, { agentId }),
          model: discovered.modelId,
        });
      } catch (error) {
        if (signal?.aborted) throw signal.reason || error;
        attempted.push(`${discovered.provider}: ${error.message}`);
      }
    }
  } catch (error) {
    if (signal?.aborted) throw signal.reason || error;
    attempted.push(`live model discovery failed: ${error.message}`);
  }

  for (const candidate of candidates) {
    if (
      typeof candidate.provider.supportsVision !== 'function' ||
      candidate.provider.supportsVision() !== true
    ) {
      attempted.push(
        `${candidate.providerName}: image analysis is not supported by this provider integration`,
      );
      continue;
    }

    try {
      const response = await withProviderRetry(
        () => candidate.provider.analyzeImage({
          imagePath,
          imageBase64: encodedImage || null,
          mimeType: resolveImageMimeType(imagePath, mimeType),
          question,
          model: candidate.model,
          signal,
        }),
        { label: `ImageAnalysis ${candidate.providerName}`, signal },
      );
      return {
        description: String(response.content || '').trim(),
        model: response.model || null,
        provider: candidate.providerName,
      };
    } catch (error) {
      if (signal?.aborted) throw signal.reason || error;
      attempted.push(`${candidate.providerName}: ${error.message}`);
    }
  }

  throw new Error(
    attempted.length > 0
      ? `Image analysis failed. ${attempted.join(' | ')}`
      : 'No vision-capable model is currently available in the live provider catalogs.',
  );
}

module.exports = {
  analyzeImageForUser,
  resolveImageMimeType,
};
