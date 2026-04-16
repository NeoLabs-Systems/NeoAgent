'use strict';

const { getOpenAiClient } = require('./openaiClient');
const { synthesizeSpeechBuffer } = require('./openaiSpeech');

async function synthesizeAssistantSpeech(
  text,
  { model = 'tts-1', voice = 'alloy' } = {},
) {
  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Assistant reply is empty; cannot synthesize speech.');
  }

  const client = getOpenAiClient();
  if (!client) {
    throw new Error('OPENAI_API_KEY is required for voice assistant speech synthesis.');
  }

  const audioBytes = await synthesizeSpeechBuffer(client, content, { model, voice });

  return {
    mimeType: 'audio/mpeg',
    audioBytes,
  };
}

module.exports = {
  synthesizeAssistantSpeech,
};
