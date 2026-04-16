'use strict';

async function synthesizeSpeechBuffer(client, text, { model = 'tts-1', voice = 'alloy' } = {}) {
  if (!client) {
    throw new Error('OpenAI client is not configured for speech synthesis.');
  }

  const content = String(text || '').trim();
  if (!content) {
    throw new Error('Speech input is empty; cannot synthesize audio.');
  }

  const response = await client.audio.speech.create({
    model: String(model || 'tts-1').trim() || 'tts-1',
    voice: String(voice || 'alloy').trim() || 'alloy',
    input: content,
  });

  return Buffer.from(await response.arrayBuffer());
}

module.exports = {
  synthesizeSpeechBuffer,
};
