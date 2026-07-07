'use strict';

const DEFAULT_SESSION_DATE = new Date('2023-05-01T00:00:00.000Z');

function parseSessionDateTime(value) {
  // LoCoMo format: "1:56 pm on 8 May, 2023"
  const match = /^(\d{1,2}):(\d{2})\s*(am|pm)\s+on\s+(\d{1,2})\s+([A-Za-z]+)\s*,?\s*(\d{4})$/i
    .exec(String(value || '').trim());
  if (!match) return DEFAULT_SESSION_DATE;
  const [, hourRaw, minuteRaw, meridiem, day, month, year] = match;
  let hour = Number.parseInt(hourRaw, 10) % 12;
  if (meridiem.toLowerCase() === 'pm') hour += 12;
  const parsed = new Date(`${day} ${month} ${year} ${String(hour).padStart(2, '0')}:${minuteRaw}:00 UTC`);
  return Number.isNaN(parsed.getTime()) ? DEFAULT_SESSION_DATE : parsed;
}

function sessionKeysFor(conversation) {
  return Object.keys(conversation)
    .filter((key) => /^session_\d+$/.test(key))
    .sort((left, right) => Number(left.split('_')[1]) - Number(right.split('_')[1]));
}

function sanitizeExternalId(value) {
  return String(value || '').replace(/[^a-zA-Z0-9_]/g, '').slice(0, 120);
}

// Builds one ingestion document per session, mirroring how omi turns each LoCoMo
// session into a real conversation instead of one giant blob.
function buildSessionDocuments(sample) {
  const conversation = sample.conversation || {};
  const documents = [];
  for (const sessionKey of sessionKeysFor(conversation)) {
    const turns = conversation[sessionKey];
    if (!Array.isArray(turns) || !turns.length) continue;
    const lines = turns
      .filter((turn) => String(turn.text || '').trim().length > 0)
      .map((turn) => `${turn.speaker}: ${String(turn.text).trim()}`);
    if (!lines.length) continue;
    const when = parseSessionDateTime(conversation[`${sessionKey}_date_time`]);
    documents.push({
      sourceType: 'chat',
      externalObjectId: sanitizeExternalId(`locomo_${sample.sample_id}_${sessionKey}`),
      title: `LoCoMo ${sample.sample_id} ${sessionKey}`,
      content: lines.join('\n'),
      sourceTimestamp: when.toISOString(),
      metadata: { benchmark: 'locomo', sampleId: sample.sample_id, sessionKey },
    });
  }
  return documents;
}

// Builds the QA manifest for a sample, excluding category 5 (adversarial) exactly like
// the standard mem0/omi LoCoMo protocol.
function buildQaManifest(sample, { qaPerSample = 0 } = {}) {
  const items = [];
  for (const [index, qa] of (sample.qa || []).entries()) {
    if (Number(qa.category) === 5) continue;
    if (qaPerSample > 0 && items.length >= qaPerSample) break;
    items.push({
      questionId: `${sample.sample_id}_${index}`,
      questionType: `locomo_cat${qa.category}`,
      question: qa.question,
      answer: String(qa.answer),
    });
  }
  return items;
}

module.exports = {
  buildQaManifest,
  buildSessionDocuments,
  parseSessionDateTime,
  sessionKeysFor,
};
