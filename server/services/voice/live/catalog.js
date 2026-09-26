'use strict';

// The live speech-to-speech models NeoAgent can talk through. This table is the
// single source for the server runtime, the settings API, the admin console,
// and the CLI setup wizard.
const LIVE_VOICE_PROVIDERS = Object.freeze({
  openai: Object.freeze({
    id: 'openai',
    label: 'OpenAI GPT-Live',
    runtimeProvider: 'openai',
    apiKeyEnv: 'OPENAI_API_KEY',
    defaultModel: 'gpt-live-1',
    models: Object.freeze(['gpt-live-1']),
    defaultVoice: 'marin',
    voices: Object.freeze([
      'marin', 'quartz', 'ripple', 'vesper', 'willow', 'stone', 'gleam',
      'meridian', 'bossa', 'tempo', 'beacon', 'delta', 'cinder',
    ]),
    inputSampleRate: 24000,
    outputSampleRate: 24000,
  }),
  google: Object.freeze({
    id: 'google',
    label: 'Google Gemini Live',
    runtimeProvider: 'google',
    apiKeyEnv: 'GOOGLE_AI_KEY',
    defaultModel: 'gemini-3.8-live',
    models: Object.freeze([
      'gemini-3.8-live',
      'gemini-3.8-live-extended-thinking',
      'gemini-3.1-flash-live-preview',
    ]),
    defaultVoice: 'Kore',
    voices: Object.freeze([
      'Kore', 'Puck', 'Charon', 'Fenrir', 'Aoede', 'Leda', 'Orus', 'Zephyr',
      'Callirrhoe', 'Autonoe', 'Enceladus', 'Iapetus', 'Umbriel', 'Algieba',
      'Despina', 'Erinome', 'Algenib', 'Rasalgethi', 'Laomedeia', 'Achernar',
      'Alnilam', 'Schedar', 'Gacrux', 'Pulcherrima', 'Achird', 'Zubenelgenubi',
      'Vindemiatrix', 'Sadachbia', 'Sadaltager', 'Sulafat',
    ]),
    inputSampleRate: 16000,
    outputSampleRate: 24000,
  }),
});

const INPUT_MODES = Object.freeze(['hands_free', 'ptt']);
const DEFAULT_INPUT_MODE = 'hands_free';

function serverDefaultProvider() {
  const configured = String(process.env.VOICE_LIVE_PROVIDER || '').trim().toLowerCase();
  return LIVE_VOICE_PROVIDERS[configured] ? configured : 'openai';
}

function normalizeLiveProvider(value) {
  const provider = String(value || '').trim().toLowerCase();
  return LIVE_VOICE_PROVIDERS[provider] ? provider : serverDefaultProvider();
}

// Stored values win; otherwise the server default from the environment applies
// when it belongs to the same provider, and finally the catalog default.
function resolveLiveModel(provider, value) {
  const requested = String(value || '').trim();
  if (requested) return requested;
  const id = normalizeLiveProvider(provider);
  const envModel = String(process.env.VOICE_LIVE_MODEL || '').trim();
  if (envModel && id === serverDefaultProvider()) return envModel;
  return LIVE_VOICE_PROVIDERS[id].defaultModel;
}

function resolveLiveVoice(provider, value) {
  const requested = String(value || '').trim();
  if (requested) return requested;
  const id = normalizeLiveProvider(provider);
  const envVoice = String(process.env.VOICE_LIVE_VOICE || '').trim();
  if (envVoice && id === serverDefaultProvider()) return envVoice;
  return LIVE_VOICE_PROVIDERS[id].defaultVoice;
}

function normalizeInputMode(value) {
  const mode = String(value || '').trim().toLowerCase();
  return INPUT_MODES.includes(mode) ? mode : DEFAULT_INPUT_MODE;
}

function describeLiveVoiceCatalog() {
  return {
    defaultProvider: serverDefaultProvider(),
    inputModes: [...INPUT_MODES],
    providers: Object.values(LIVE_VOICE_PROVIDERS).map((provider) => ({
      id: provider.id,
      label: provider.label,
      defaultModel: resolveLiveModel(provider.id, ''),
      models: [...provider.models],
      defaultVoice: resolveLiveVoice(provider.id, ''),
      voices: [...provider.voices],
    })),
  };
}

module.exports = {
  DEFAULT_INPUT_MODE,
  INPUT_MODES,
  LIVE_VOICE_PROVIDERS,
  describeLiveVoiceCatalog,
  normalizeInputMode,
  normalizeLiveProvider,
  resolveLiveModel,
  resolveLiveVoice,
};
