'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  resolveTtsModel,
  synthesizeVoiceReply,
  synthesizeVoiceReplyStream,
} = require('../../../server/services/voice/providers');
const {
  PROVIDERS,
  VoiceProviderRegistry,
} = require('../../../server/services/voice/provider_registry');
const {
  VoiceDeliveryPresenter,
} = require('../../../server/services/voice/voice_delivery_presenter');

const CURRENT_GEMINI_TTS_MODEL = 'gemini-3.1-flash-tts-preview';
const RETIRED_GEMINI_TTS_MODEL = 'gemini-2.5-flash-preview-tts';

function audioInteraction(bytes = Buffer.from([1, 2, 3, 4])) {
  return {
    id: 'interaction-test',
    status: 'completed',
    steps: [{
      type: 'model_output',
      content: [{
        type: 'audio',
        data: bytes.toString('base64'),
        mime_type: 'audio/l16',
        sample_rate: 24000,
      }],
    }],
  };
}

function audioEvent(bytes = Buffer.from([5, 6, 7, 8])) {
  return `data: ${JSON.stringify({
    event_type: 'step.delta',
    index: 0,
    delta: {
      type: 'audio',
      data: bytes.toString('base64'),
      mime_type: 'audio/l16',
      sample_rate: 16000,
    },
  })}\n\n`;
}

test('Gemini voice defaults migrate the retired non-streaming model to 3.1', () => {
  assert.equal(resolveTtsModel('gemini', ''), CURRENT_GEMINI_TTS_MODEL);
  assert.equal(
    resolveTtsModel('gemini', RETIRED_GEMINI_TTS_MODEL),
    CURRENT_GEMINI_TTS_MODEL,
  );
  assert.equal(PROVIDERS.gemini.streamingTts.model, CURRENT_GEMINI_TTS_MODEL);

  const resolved = new VoiceProviderRegistry().resolve({
    sttProvider: 'gemini',
    ttsProvider: 'gemini',
    ttsModel: RETIRED_GEMINI_TTS_MODEL,
  });
  assert.equal(resolved.ttsModel, CURRENT_GEMINI_TTS_MODEL);
});

test('Gemini TTS uses the Interactions API with an explicit transcript contract', async () => {
  const previousFetch = global.fetch;
  let request = null;
  global.fetch = async (url, options) => {
    request = { url, options, body: JSON.parse(options.body) };
    return new Response(JSON.stringify(audioInteraction()), {
      headers: { 'Content-Type': 'application/json' },
    });
  };
  try {
    const result = await synthesizeVoiceReply('The deployment is healthy.', {
      provider: 'gemini',
      model: RETIRED_GEMINI_TTS_MODEL,
      voice: 'Kore',
      apiKey: 'test-key',
    });

    assert.equal(request.url, 'https://generativelanguage.googleapis.com/v1beta/interactions');
    assert.equal(request.options.headers['Api-Revision'], '2026-05-20');
    assert.equal(request.body.model, CURRENT_GEMINI_TTS_MODEL);
    assert.deepEqual(request.body.response_format, { type: 'audio' });
    assert.deepEqual(request.body.generation_config.speech_config, [{ voice: 'Kore' }]);
    assert.match(request.body.input, /Synthesize speech for the transcript below\./);
    assert.match(request.body.input, /### TRANSCRIPT\nThe deployment is healthy\.\n### END TRANSCRIPT/);
    assert.equal(request.body.stream, false);
    assert.equal(result.mimeType, 'audio/wav');
    assert.equal(result.audioBytes.subarray(0, 4).toString('ascii'), 'RIFF');
  } finally {
    global.fetch = previousFetch;
  }
});

test('Gemini TTS forwards streamed audio immediately with its advertised sample rate', async () => {
  const previousFetch = global.fetch;
  let requestBody = null;
  global.fetch = async (_url, options) => {
    requestBody = JSON.parse(options.body);
    return new Response(audioEvent());
  };
  const chunks = [];
  try {
    await synthesizeVoiceReplyStream('A short spoken reply.', {
      provider: 'gemini',
      apiKey: 'test-key',
    }, async (chunk) => chunks.push(chunk));

    assert.equal(requestBody.model, CURRENT_GEMINI_TTS_MODEL);
    assert.equal(requestBody.stream, true);
    assert.equal(chunks.length, 1);
    assert.equal(chunks[0].mimeType, 'audio/wav');
    assert.equal(chunks[0].audioBytes.readUInt32LE(24), 16000);
  } finally {
    global.fetch = previousFetch;
  }
});

test('Gemini retries one provider 5xx without switching voice providers', async () => {
  const previousFetch = global.fetch;
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    if (calls === 1) return new Response('temporary speech failure', { status: 500 });
    return new Response(JSON.stringify(audioInteraction()));
  };
  try {
    const result = await synthesizeVoiceReply('Retry this speech.', {
      provider: 'gemini',
      apiKey: 'test-key',
    });
    assert.equal(calls, 2);
    assert.equal(result.mimeType, 'audio/wav');
  } finally {
    global.fetch = previousFetch;
  }
});

test('voice delivery keeps provider diagnostics out of the recoverable UI error', async () => {
  const previousFetch = global.fetch;
  global.fetch = async () => new Response(JSON.stringify({
    error: {
      code: 400,
      message: 'Model tried to generate text instead of audio.',
    },
  }), { status: 400 });
  const publishedErrors = [];
  const session = {
    attached: true,
    sink: {},
    state: 'working',
    signal: new AbortController().signal,
    currentTurnId: 'turn-1',
    platform: 'flutter',
    voiceSettings: {
      mediaMode: 'composed',
      ttsProvider: 'gemini',
      ttsModel: CURRENT_GEMINI_TTS_MODEL,
      ttsVoice: 'Kore',
      ttsApiKey: 'test-key',
    },
    async setState() {},
    async publishAssistantText() {},
    async publishError(message) { publishedErrors.push(message); },
  };
  try {
    const result = await new VoiceDeliveryPresenter().present(session, {
      id: 'delivery-1',
      messageKind: 'final',
      runId: 'run-1',
      payload: { content: 'The deployment is healthy.' },
    });

    assert.equal(result.presented, true);
    assert.deepEqual(publishedErrors, [
      'Voice playback failed. The text reply is still available.',
    ]);
  } finally {
    global.fetch = previousFetch;
  }
});
