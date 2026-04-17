'use strict';

const { sanitizeError } = require('../../utils/security');
const { getProviderForUser } = require('./engine');
const { getSupportedModels } = require('./models');
const { getAiSettings } = require('./settings');
const { parseJsonObject } = require('./taskAnalysis');

const INSIGHTS_SYSTEM_PROMPT = `You are an expert audio transcript analyzer. Your job is to read the provided transcript and extract structured insights.

You must output valid JSON ONLY, with the following exact structure:
{
  "summary": "A concise, 1-2 paragraph summary of the entire conversation.",
  "action_items": [
    "List of any action items, tasks, or follow-ups mentioned.",
    "Be specific and include who is responsible if mentioned."
  ],
  "events": [
    "List of any events, meetings, or dates mentioned in the transcript."
  ]
}

If no action items or events are found, return empty arrays for those fields.
Do NOT wrap the output in markdown \`\`\`json blocks. ONLY return the raw JSON object.
`;

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
