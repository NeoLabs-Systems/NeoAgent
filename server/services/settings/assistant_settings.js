'use strict';

const { UI_LANGUAGE_CODES } = require('../../config/ui_languages');
const { createDefaultAiSettings } = require('../ai/settings');
const { getSupportedModels } = require('../ai/models');
const { getSystemOneModels } = require('../ai/system_one');
const {
  INPUT_MODES,
  LIVE_VOICE_PROVIDERS,
  normalizeLiveProvider,
} = require('../voice/live/catalog');
const { applySettingsUpdate, readSettingValue } = require('./store');
const { buildAppLink } = require('./app_links');

// The settings the assistant may change on the user's behalf. Everything here
// is reversible and only shapes how the assistant itself behaves; security,
// access, credentials, runtimes and account data stay with the user, who gets
// a link to them instead. Each entry names the row that shows it in the app.

async function availableModelChoices(loadModels, { userId, agentId, signal }) {
  const models = await loadModels(userId, agentId, { signal });
  return models
    .filter((model) => model.available !== false)
    .map((model) => ({
      value: model.id,
      label: `${model.label || model.name || model.modelId} (${model.provider})`,
    }));
}

const ENTRIES = [
  {
    key: 'default_chat_model',
    description: 'Model that answers chats. "auto" lets the smart selector pick per message.',
    location: ['models', 'chatModel'],
    choices: async (context) => [
      { value: 'auto', label: 'Automatic' },
      ...await availableModelChoices(getSupportedModels, context),
    ],
  },
  {
    key: 'system_one_model',
    description: 'Fast model for behind-the-scenes decisions. "off" leaves them to the chat model.',
    location: ['models', 'systemOne'],
    choices: async (context) => [
      { value: 'auto', label: 'Automatic' },
      { value: 'off', label: 'Off' },
      ...await availableModelChoices(getSystemOneModels, context),
    ],
  },
  {
    key: 'assistant_behavior_notes',
    description: 'Standing persona and behavior instructions for this agent. Replaces the whole text, so include what should stay.',
    location: ['behavior', 'persona'],
    maxLength: 8000,
  },
  {
    key: 'voice_input_mode',
    description: 'How voice conversations take input: hands-free or push-to-talk.',
    location: ['voice', 'inputMode'],
    choices: async () => INPUT_MODES.map((mode) => ({ value: mode })),
  },
  {
    key: 'voice_live_provider',
    description: 'Live voice provider. Empty follows the server default. Changing it resets the live model and voice.',
    location: ['voice', 'liveProvider'],
    choices: async () => [
      { value: '', label: 'Server default' },
      ...Object.values(LIVE_VOICE_PROVIDERS).map((provider) => ({ value: provider.id, label: provider.label })),
    ],
    // A model or voice only fits the provider it came from.
    alsoSets: () => ({ voice_live_model: '', voice_live_voice: '' }),
  },
  {
    key: 'voice_live_voice',
    description: 'Voice the live voice provider speaks with. Empty uses the provider default.',
    location: ['voice', 'liveVoice'],
    choices: async ({ userId, agentId }) => {
      const provider = LIVE_VOICE_PROVIDERS[normalizeLiveProvider(readSettingValue(userId, agentId, 'voice_live_provider'))];
      return [
        { value: '', label: `Provider default (${provider.defaultVoice})` },
        ...provider.voices.map((voice) => ({ value: voice })),
      ];
    },
  },
  {
    key: 'ui_language',
    description: 'Language of the app interface, as a language code.',
    location: ['general', 'language'],
    choices: async () => [...UI_LANGUAGE_CODES].map((code) => ({ value: code })),
  },
  {
    key: 'timezone',
    description: 'IANA time zone (for example Europe/Berlin) for the assistant\'s clock and scheduled tasks. Stops following the device\'s zone.',
    location: ['general', 'timeZone'],
    alsoSets: () => ({ timezone_auto: false }),
  },
];

const ENTRIES_BY_KEY = new Map(ENTRIES.map((entry) => [entry.key, entry]));
const ASSISTANT_SETTING_KEYS = Object.freeze(ENTRIES.map((entry) => entry.key));
const DEFAULTS = createDefaultAiSettings();
const MAX_LISTED_CHOICES = 40;

function linkFor(entry) {
  const [page, focus] = entry.location;
  return buildAppLink({ section: 'settings', page, focus });
}

function currentValue(entry, userId, agentId) {
  return readSettingValue(userId, agentId, entry.key) ?? DEFAULTS[entry.key] ?? null;
}

function matchesSearch(choice, terms) {
  const haystack = `${choice.value} ${choice.label || ''}`.toLowerCase();
  return terms.every((term) => haystack.includes(term));
}

function searchTerms(search) {
  return String(search || '').toLowerCase().split(/\s+/).filter(Boolean);
}

async function describeSetting(entry, context, search) {
  const description = {
    key: entry.key,
    description: entry.description,
    value: currentValue(entry, context.userId, context.agentId),
    link: linkFor(entry),
  };
  if (entry.maxLength) description.maxLength = entry.maxLength;
  if (!entry.choices) return description;

  const terms = searchTerms(search);
  const choices = (await entry.choices(context))
    .filter((choice) => terms.length === 0 || matchesSearch(choice, terms));
  description.choices = choices.slice(0, MAX_LISTED_CHOICES);
  if (choices.length > MAX_LISTED_CHOICES) {
    description.moreChoices = choices.length - MAX_LISTED_CHOICES;
  }
  return description;
}

/** Current values, allowed choices and app links for the requested settings. */
async function readAssistantSettings({ userId, agentId, keys = null, search = '', signal = null }) {
  const requested = Array.isArray(keys) && keys.length
    ? keys.map((key) => ENTRIES_BY_KEY.get(String(key))).filter(Boolean)
    : ENTRIES;
  const context = { userId, agentId, signal };
  return Promise.all(requested.map((entry) => describeSetting(entry, context, search)));
}

// The choices sharing the most words with a rejected value, so a near miss
// ("gemini 1.5 flash") comes back with what is actually there.
function closestChoices(choices, value, limit = 12) {
  const words = String(value).toLowerCase().split(/[^a-z0-9.]+/).filter(Boolean);
  const scored = choices
    .map((choice) => {
      const haystack = `${choice.value} ${choice.label || ''}`.toLowerCase();
      return { choice, score: words.filter((word) => haystack.includes(word)).length };
    })
    .filter((item) => item.score > 0)
    .sort((left, right) => right.score - left.score);
  return (scored.length ? scored.map((item) => item.choice) : choices).slice(0, limit);
}

// A call made without the tool's schema guesses at names ("chat_model",
// "gemini-2.5-flash"). A guess that fits exactly one setting or one choice is
// taken; anything vaguer is refused with what would fit.
function findEntry(key) {
  const name = String(key || '').trim();
  if (ENTRIES_BY_KEY.has(name)) return ENTRIES_BY_KEY.get(name);
  const matches = name ? ENTRIES.filter((entry) => entry.key.endsWith(`_${name}`)) : [];
  return matches.length === 1 ? matches[0] : null;
}

async function resolveValue(entry, value, context) {
  if (entry.choices) {
    const choices = await entry.choices(context);
    if (choices.some((choice) => choice.value === value)) return { value };
    const byModelId = choices.filter((choice) => choice.value.endsWith(`::${value}`));
    if (byModelId.length === 1) return { value: byModelId[0].value };
    return {
      error: `"${value}" is not an option for ${entry.key}.`,
      choices: closestChoices(choices, value),
    };
  }
  if (entry.maxLength && value.length > entry.maxLength) {
    return { error: `${entry.key} is limited to ${entry.maxLength} characters.` };
  }
  return { value };
}

/**
 * Changes one assistant-managed setting through the same store the settings
 * screen uses. Returns the previous and new value plus the app link to it.
 */
async function updateAssistantSetting({ userId, agentId, key, value, taskRuntime = null, signal = null }) {
  const entry = findEntry(key);
  if (!entry) {
    return {
      success: false,
      error: `There is no setting "${key || ''}" here. Use a key from expected.key (settings_read lists their values); anything not listed there is linked with settings_link instead.`,
      expected: { key: ASSISTANT_SETTING_KEYS.join(' | '), value: 'string, as listed by settings_read' },
    };
  }
  const requested = typeof value === 'string' ? value.trim() : String(value ?? '');
  const resolved = await resolveValue(entry, requested, { userId, agentId, signal });
  if (resolved.error) return { success: false, ...resolved };
  const nextValue = resolved.value;

  const previous = currentValue(entry, userId, agentId);
  const result = applySettingsUpdate({
    userId,
    agentId,
    patch: { [entry.key]: nextValue, ...(entry.alsoSets ? entry.alsoSets(nextValue) : {}) },
    taskRuntime,
    source: 'assistant',
  });
  if (!result.ok) return { success: false, error: result.error };
  return {
    success: true,
    key: entry.key,
    previous,
    value: result.settings[entry.key],
    link: linkFor(entry),
  };
}

module.exports = {
  ASSISTANT_SETTING_KEYS,
  readAssistantSettings,
  updateAssistantSetting,
};
