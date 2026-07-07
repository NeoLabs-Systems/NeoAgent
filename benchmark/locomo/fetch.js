'use strict';

const path = require('node:path');
const { ensureDir, exists, readJson, writeJson } = require('../utils');

// LoCoMo (Snap Research, CC BY-NC 4.0) ships its data file directly in the public repo,
// unlike GAIA/SWE-bench which are gated behind tokens or external runners.
const LOCOMO_SOURCE_URL = 'https://raw.githubusercontent.com/snap-research/locomo/main/data/locomo10.json';

function validateLocomoDataset(data) {
  if (!Array.isArray(data) || data.length === 0) {
    throw new Error('LoCoMo dataset must be a non-empty array of samples.');
  }
  for (const sample of data) {
    if (!sample || typeof sample !== 'object') {
      throw new Error('LoCoMo sample must be an object.');
    }
    if (!sample.sample_id) {
      throw new Error('LoCoMo sample is missing sample_id.');
    }
    if (!sample.conversation || typeof sample.conversation !== 'object') {
      throw new Error(`LoCoMo sample ${sample.sample_id} is missing conversation.`);
    }
    if (!Array.isArray(sample.qa) || !sample.qa.length) {
      throw new Error(`LoCoMo sample ${sample.sample_id} is missing qa pairs.`);
    }
  }
  return data;
}

async function ensureLocomoDataset({
  datasetPath,
  sourceUrl = LOCOMO_SOURCE_URL,
  allowDownload = true,
} = {}) {
  if (await exists(datasetPath)) {
    return validateLocomoDataset(await readJson(datasetPath));
  }
  if (!allowDownload) {
    throw new Error(`LoCoMo dataset not found at ${datasetPath} and downloads are disabled.`);
  }
  const response = await fetch(sourceUrl);
  if (!response.ok) {
    throw new Error(`Failed to download LoCoMo dataset from ${sourceUrl}: HTTP ${response.status}`);
  }
  const data = validateLocomoDataset(await response.json());
  await ensureDir(path.dirname(datasetPath));
  await writeJson(datasetPath, data);
  return data;
}

function summarizeLocomoDataset(data) {
  const categories = new Map();
  let totalQa = 0;
  for (const sample of data) {
    for (const qa of sample.qa || []) {
      totalQa += 1;
      const key = `category_${qa.category}`;
      categories.set(key, (categories.get(key) || 0) + 1);
    }
  }
  return {
    samples: data.length,
    totalQa,
    categories: Object.fromEntries(categories),
  };
}

module.exports = {
  LOCOMO_SOURCE_URL,
  ensureLocomoDataset,
  summarizeLocomoDataset,
  validateLocomoDataset,
};
