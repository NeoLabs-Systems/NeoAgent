'use strict';

const fs = require('fs');
const path = require('path');

const { getProviderForUser } = require('./engine');
const { createProviderInstance, getProviderCatalog } = require('./models');

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
  question = 'Describe this image in detail.',
  mimeType = null,
} = {}) {
  if (!fs.existsSync(imagePath)) {
    throw new Error(`File not found: ${imagePath}`);
  }

  const attempted = [];
  const candidates = [];

  try {
    const preferred = await getProviderForUser(userId, '', false, null, {
      agentId,
    });
    candidates.push({
      providerName: preferred.providerName,
      provider: preferred.provider,
    });
  } catch (error) {
    attempted.push(`default-provider lookup failed: ${error.message}`);
  }

  for (const providerInfo of getProviderCatalog(userId, agentId)) {
    if (!providerInfo.available) continue;
    if (candidates.some((candidate) => candidate.providerName === providerInfo.id)) {
      continue;
    }
    if (!['grok', 'openai'].includes(providerInfo.id)) continue;
    try {
      candidates.push({
        providerName: providerInfo.id,
        provider: createProviderInstance(providerInfo.id, userId, { agentId }),
      });
    } catch (error) {
      attempted.push(`${providerInfo.id}: ${error.message}`);
    }
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
      const response = await candidate.provider.analyzeImage({
        imagePath,
        mimeType: resolveImageMimeType(imagePath, mimeType),
        question,
      });
      return {
        description: String(response.content || '').trim(),
        model: response.model || null,
        provider: candidate.providerName,
      };
    } catch (error) {
      attempted.push(`${candidate.providerName}: ${error.message}`);
    }
  }

  throw new Error(
    attempted.length > 0
      ? `Image analysis failed. ${attempted.join(' | ')}`
      : 'No vision-capable provider is currently available. Configure OpenAI or xAI for image analysis.',
  );
}

module.exports = {
  analyzeImageForUser,
  resolveImageMimeType,
};
