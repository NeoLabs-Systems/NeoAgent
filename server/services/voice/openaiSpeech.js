'use strict';

async function synthesizeSpeechBuffer(client, text, { model = 'gpt-4o-mini-tts', voice = 'alloy' } = {}) {
  if (!client) {
    throw new Error('OpenAI client is not configured for speech synthesis.');
  }

  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Speech input is empty; cannot synthesize audio.');
  }

  const response = await client.audio.speech.create({
    model: String(model || 'gpt-4o-mini-tts').trim() || 'gpt-4o-mini-tts',
    voice: String(voice || 'alloy').trim() || 'alloy',
    input: content,
  });

  return Buffer.from(await response.arrayBuffer());
}

module.exports = {
  synthesizeSpeechBuffer,
};
