'use strict';

const { resolvePublicBaseUrl } = require('../integrations/env');

// Every page of the app's Settings screen, what lives there, and the anchors
// a link can scroll to. The Flutter client resolves the same names
// (flutter_app/lib/src/app_link.dart); a unit test keeps the anchors in step
// with the ones the settings pages declare.
const SETTINGS_PAGES = Object.freeze({
  profile: {
    summary: 'Display name, email, data export, data sharing, sign out, delete account.',
    anchors: ['displayName', 'email', 'exportData', 'dataSharing', 'signOut', 'deleteAccount'],
  },
  security: {
    summary: 'Password, two-factor, security keys and passkeys, linked sign-in providers, active sessions, QR login.',
    anchors: ['password', 'twoFactor', 'securityKeys', 'linkedProviders', 'sessions', 'qrLogin'],
  },
  usage: {
    summary: 'Usage limits and token usage.',
    anchors: ['limits', 'tokenUsage'],
  },
  agents: {
    summary: 'The user\'s agents (bots): create, rename, delegate, default agent.',
    anchors: ['agentList'],
  },
  permissions: {
    summary: 'Tool permissions: which tool categories ask for approval, run, or are blocked.',
    anchors: ['toolPermissions'],
  },
  computer: {
    summary: 'Computer workspace (VM, browser, desktop), shell, Social Reach cookies.',
    anchors: ['computerRuntime', 'shell', 'socialReach'],
  },
  models: {
    summary: 'Chat model, model pool, SystemOne models, per-task models, bring-your-own API keys.',
    anchors: ['chatModel', 'modelPool', 'systemOne', 'apiKeys'],
  },
  behavior: {
    summary: 'Persona and behavior notes, social behavior in group chats.',
    anchors: ['persona', 'socialBehavior', 'turnTaking', 'minimumNeed', 'batchWindow'],
  },
  voice: {
    summary: 'Voice input mode, live voice provider, model and voice, speech-to-text, voice reply model.',
    anchors: ['inputMode', 'liveProvider', 'liveModel', 'liveVoice', 'speechToText', 'voiceReplyModel'],
  },
  messaging: {
    summary: 'Messaging platforms (WhatsApp, Telegram, Discord, Signal, Slack, webhooks): linking, group participation, delivery.',
    anchors: ['channels', 'participation', 'delivery'],
  },
  general: {
    summary: 'Theme, language, time zone, desktop window and hotkey, location and notification triggers, redo onboarding.',
    anchors: ['theme', 'language', 'timeZone', 'closeWindow', 'hotkey', 'locationTriggers', 'notificationTriggers', 'onboarding'],
  },
  system: {
    summary: 'Server updates and release channel. Desktop app only.',
    anchors: ['server'],
  },
});

// Top-level places outside Settings. `integrations` takes an official
// integration key as its focus and opens that integration's connect sheet.
const APP_SECTIONS = Object.freeze({
  settings: 'Settings, by page.',
  integrations: 'Official integrations (Google, Microsoft, GitHub, Notion, Slack, ...): connect and manage accounts.',
  skills: 'Installed skills.',
  mcp: 'MCP servers.',
  tasks: 'Scheduled and triggered tasks.',
  memory: 'Saved memories and core memory.',
  devices: 'Paired phones, computers and the wearable.',
  health: 'Synced health data.',
  runs: 'Past agent runs and logs.',
});

const OPEN_PATH = '/app/open';

function describeAppLinkError(message) {
  const error = new Error(message);
  error.code = 'invalid_app_link';
  return error;
}

/**
 * Builds the URL that opens one place in the NeoAgent app. Opened in a
 * browser it loads the web app there; tapped inside the app it navigates in
 * place. `focus` is a settings anchor or an integration key.
 */
function buildAppLink({ section, page = null, focus = null, integrationKeys = [] }) {
  const sectionName = String(section || '').trim();
  if (!APP_SECTIONS[sectionName]) {
    throw describeAppLinkError(`Unknown app section "${sectionName}". Use one of: ${Object.keys(APP_SECTIONS).join(', ')}.`);
  }
  const segments = [sectionName];
  const focusName = String(focus || '').trim();

  if (sectionName === 'settings') {
    const pageName = String(page || '').trim();
    const pageEntry = SETTINGS_PAGES[pageName];
    if (!pageEntry) {
      throw describeAppLinkError(`Unknown settings page "${pageName}". Use one of: ${Object.keys(SETTINGS_PAGES).join(', ')}.`);
    }
    segments.push(pageName);
    if (focusName) {
      if (!pageEntry.anchors.includes(focusName)) {
        throw describeAppLinkError(`The ${pageName} page has no "${focusName}". Use one of: ${pageEntry.anchors.join(', ')}.`);
      }
      segments.push(focusName);
    }
  } else if (sectionName === 'integrations' && focusName) {
    if (!integrationKeys.includes(focusName)) {
      throw describeAppLinkError(`Unknown integration "${focusName}". Use one of: ${integrationKeys.join(', ')}.`);
    }
    segments.push(focusName);
  }

  return `${resolvePublicBaseUrl()}${OPEN_PATH}/${segments.map(encodeURIComponent).join('/')}`;
}

module.exports = {
  APP_SECTIONS,
  SETTINGS_PAGES,
  buildAppLink,
};
