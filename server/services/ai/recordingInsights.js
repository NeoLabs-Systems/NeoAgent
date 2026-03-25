'use strict';

const { sanitizeError } = require('../../utils/security');
const { getProviderForUser } = require('./engine');
const { getAiSettings } = require('./settings');

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

async function extractRecordingInsights(app, userId, transcriptText, options = {}) {
  if (!transcriptText || !transcriptText.trim()) {
    return null;
  }

  const aiSettings = getAiSettings(userId);
  const preferredModel = options.model || (aiSettings.smarter_model_selector ? 'auto' : aiSettings.default_chat_model);

  try {
    const { provider, model } = await getProviderForUser(userId, "analyze transcript", false, preferredModel);

    const messages = [
      { role: 'system', content: INSIGHTS_SYSTEM_PROMPT },
      { role: 'user', content: transcriptText }
    ];

    const response = await provider.chat(messages, [], {
      model,
      reasoningEffort: process.env.REASONING_EFFORT || 'low'
    });

    let content = response.content || '';
    
    // Clean markdown blocks if the model ignored the instructions
    content = content.trim();
    if (content.startsWith('```json')) {
      content = content.replace(/^```json\s*/, '').replace(/```\s*$/, '').trim();
    } else if (content.startsWith('```')) {
      content = content.replace(/^```\s*/, '').replace(/```\s*$/, '').trim();
    }

    try {
      const parsed = JSON.parse(content);
      return {
        ...parsed,
        _model: model,
        _generated_at: new Date().toISOString()
      };
    } catch (parseErr) {
      console.warn('[AI] Failed to parse recording insights JSON:', content.slice(0, 100) + '...');
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
