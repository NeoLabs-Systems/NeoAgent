'use strict';

const { sanitizeError } = require('../../utils/security');
const { getProviderForUser } = require('./engine');
const { getSupportedModels } = require('./models');
const { getAiSettings } = require('./settings');
const { parseJsonObject } = require('./taskAnalysis');

const INSIGHTS_SYSTEM_PROMPT = `Return JSON only. No markdown, no prose, no code fences.

You are a precise conversation analyst. Read the transcript and extract exactly what happened: who said what, what was decided, what needs to happen next, and when.

Schema:
{
  "summary": "1-2 paragraph factual summary. Name speakers if identifiable. Cover the main topic, key decisions, outcome, and any unresolved items.",
  "action_items": ["Each item as: '[Owner if named] — specific action'. One item per string. Empty array if none."],
  "events": ["Each as: '[date/time if stated] — event description'. One event per string. Empty array if none."]
}

Rules:
- Report only what the transcript explicitly contains. Do not infer or add context not present in the recording.
- Be specific: "Alice will send the contract by Friday" beats "follow-up needed".
- If a field has no data, use an empty array.`;

async function extractRecordingInsights(userId, transcriptText, options = {}) {
  if (!transcriptText || !transcriptText.trim()) {
    return null;
  }

  const aiSettings = getAiSettings(userId);
  const configuredSummaryProvider = `${aiSettings.default_recording_summary_provider || ''}`
    .trim()
    .toLowerCase();
  const configuredSummaryModel = `${aiSettings.default_recording_summary_model || ''}`.trim();
  const fallbackModel = aiSettings.smarter_model_selector ? 'auto' : aiSettings.default_chat_model;
  const requestedProvider = `${options.provider || configuredSummaryProvider || 'auto'}`.trim().toLowerCase() || 'auto';
  const requestedModel = `${options.model || configuredSummaryModel || fallbackModel}`.trim() || fallbackModel;

  try {
    const availableModels = (await getSupportedModels(userId)).filter((model) => model.available !== false);
    const resolveModelForProvider = () => {
      if (!availableModels.length) {
        return requestedModel;
      }

      if (requestedModel && requestedModel !== 'auto') {
        const explicitMatch = availableModels.find((model) => model.id === requestedModel);
        if (explicitMatch && (requestedProvider === 'auto' || explicitMatch.provider === requestedProvider)) {
          return explicitMatch.id;
        }
      }

      if (requestedProvider !== 'auto') {
        const providerModels = availableModels.filter((model) => model.provider === requestedProvider);
        const preferred = providerModels.find((model) => model.purpose === 'general')
          || providerModels.find((model) => model.purpose === 'planning')
          || providerModels[0];
        if (preferred) {
          return preferred.id;
        }
      }

      return requestedModel;
    };

    const preferredModel = resolveModelForProvider();
    const { provider, model } = await getProviderForUser(userId, "analyze transcript", false, preferredModel);

    const messages = [
      { role: 'system', content: INSIGHTS_SYSTEM_PROMPT },
      { role: 'user', content: transcriptText }
    ];

    const response = await provider.chat(messages, [], {
      model,
      reasoningEffort: process.env.REASONING_EFFORT || 'low'
    });

    try {
      const rawContent = String(response.content || '');
      const parsed = parseJsonObject(rawContent);
      if (!parsed) {
        throw new Error('Response did not contain a valid JSON object.');
      }
      return {
        ...parsed,
        _model: model,
        _generated_at: new Date().toISOString()
      };
    } catch (parseErr) {
      const content = String(response.content || '');
      console.warn(
        `[AI] Failed to parse recording insights JSON: length=${content.length} error=${parseErr.message}`
      );
      return null;
    }
  } catch (err) {
    console.error('[AI] Recording insights extraction failed:', sanitizeError(err));
    return null;
  }
}

module.exports = {
  extractRecordingInsights
};
