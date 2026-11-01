'use strict';

// The live speech-to-speech providers NeoAgent can talk through. This table is
// the single source for the server runtime, the settings API, the admin
// console, and the CLI setup wizard. Their models are not listed here: they
// come from each provider's model list (models.js).
const OPENAI_LIVE = Object.freeze({
  id: 'openai',
  label: 'OpenAI GPT-Live',
  runtimeProvider: 'openai',
  apiKeyEnv: 'OPENAI_API_KEY',
  defaultVoice: 'marin',
  voices: Object.freeze([
    'marin', 'quartz', 'ripple', 'vesper', 'willow', 'stone', 'gleam',
    'meridian', 'bossa', 'tempo', 'beacon', 'delta', 'cinder',
  ]),
  inputSampleRate: 24000,
  outputSampleRate: 24000,
  // Client delegation is GPT-Live's only way out: checking on, changing, or
  // stopping a task is handed off like any other request.
  taskTools: false,
});

const GOOGLE_LIVE = Object.freeze({
  id: 'google',
  label: 'Google Gemini Live',
  runtimeProvider: 'google',
  apiKeyEnv: 'GOOGLE_AI_KEY',
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
  taskTools: true,
});

const LIVE_VOICE_PROVIDERS = Object.freeze({
  openai: OPENAI_LIVE,
  google: GOOGLE_LIVE,
  // A connected NeoRouter relays both protocols to whichever of its providers
  // has the model, so it appears once per protocol with that protocol's
  // voices and audio format. `adapter` names the protocol's session adapter;
  // its models are the router's live models that speak `protocol`.
  neorouter_openai: Object.freeze({
    ...OPENAI_LIVE,
    id: 'neorouter_openai',
    label: 'NeoRouter · GPT-Live',
    runtimeProvider: 'neorouter',
    apiKeyEnv: 'NEOROUTER_API_KEY',
    adapter: 'openai',
    protocol: 'openai_live',
  }),
  neorouter_google: Object.freeze({
    ...GOOGLE_LIVE,
    id: 'neorouter_google',
    label: 'NeoRouter · Gemini Live',
    runtimeProvider: 'neorouter',
    apiKeyEnv: 'NEOROUTER_API_KEY',
    adapter: 'google',
    protocol: 'gemini_live',
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
// when it belongs to the same provider. Empty means the provider's default
// from its model list.
function configuredLiveModel(provider, value) {
  const requested = String(value || '').trim();
  if (requested) return requested;
  const envModel = String(process.env.VOICE_LIVE_MODEL || '').trim();
  return envModel && normalizeLiveProvider(provider) === serverDefaultProvider() ? envModel : '';
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

module.exports = {
  DEFAULT_INPUT_MODE,
  INPUT_MODES,
  LIVE_VOICE_PROVIDERS,
  configuredLiveModel,
  normalizeInputMode,
  normalizeLiveProvider,
  resolveLiveVoice,
  serverDefaultProvider,
};
