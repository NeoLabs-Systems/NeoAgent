'use strict';

const {
  ASSISTANT_SETTING_KEYS,
  readAssistantSettings,
  updateAssistantSetting,
} = require('../../settings/assistant_settings');
const { APP_SECTIONS, SETTINGS_PAGES, buildAppLink } = require('../../settings/app_links');

// Read, change and link to NeoAgent's own settings. One family, so asking for
// any of them activates all three.
const FAMILY = 'app_settings';

// What settings_link can open, each with its link ready to send. Tool
// descriptions are cut short in the schema, so the map travels in
// settings_read's result instead.
function describePlaces() {
  const sections = {};
  for (const [section, summary] of Object.entries(APP_SECTIONS)) {
    if (section === 'settings') continue;
    sections[section] = { summary, link: buildAppLink({ section }) };
  }
  const settingsPages = {};
  for (const [page, entry] of Object.entries(SETTINGS_PAGES)) {
    settingsPages[page] = { ...entry, link: buildAppLink({ section: 'settings', page }) };
  }
  return { sections, settingsPages };
}

// Returned with a rejected link, so a call made without the schema can be
// corrected on the next step.
const LINK_ARGUMENTS = Object.freeze({
  section: Object.keys(APP_SECTIONS).join(' | '),
  page: `settings page when section is settings: ${Object.keys(SETTINGS_PAGES).join(' | ')}`,
  focus: 'optional: an anchor of that settings page, or an integration key',
});

function getAppSettingsToolDefinitions() {
  return [
    {
      name: 'settings_read',
      family: FAMILY,
      access: 'read',
      description: 'Read NeoAgent\'s own settings you can change (chat model, persona notes, voice, language, time zone) with values, choices and app links; which integrations are connected; and the map of app places settings_link can open. Call it first when the user asks about configuring NeoAgent.',
      parameters: {
        type: 'object',
        properties: {
          keys: {
            type: 'array',
            items: { type: 'string', enum: ASSISTANT_SETTING_KEYS },
            description: 'Only these settings. Omit for all.',
          },
          search: {
            type: 'string',
            description: 'Filter the listed choices, for example "claude" or "sonnet" when looking for a model.',
          },
        },
      },
    },
    {
      name: 'settings_update',
      family: FAMILY,
      access: 'write',
      description: 'Change one NeoAgent setting the user asked for. Only the listed keys; for anything else (security, permissions, API keys, runtimes, account, theme, connecting platforms or integrations) use settings_link. Tell the user what changed, with the returned link.',
      parameters: {
        type: 'object',
        properties: {
          key: { type: 'string', enum: ASSISTANT_SETTING_KEYS, description: 'The setting to change.' },
          value: { type: 'string', description: 'The new value, exactly as listed in settings_read choices where the setting has them.' },
        },
        required: ['key', 'value'],
      },
    },
    {
      name: 'settings_link',
      family: FAMILY,
      access: 'read',
      description: 'Link the user to the place in the NeoAgent app where they connect or set up an integration or messaging platform, or change security, permissions, API keys, theme, or any setting you cannot change yourself. settings_read lists the places. Put the url in your reply as a markdown link.',
      parameters: {
        type: 'object',
        properties: {
          section: { type: 'string', enum: Object.keys(APP_SECTIONS), description: 'Where the link goes.' },
          page: { type: 'string', enum: Object.keys(SETTINGS_PAGES), description: 'Settings page, when section is settings.' },
          focus: {
            type: 'string',
            description: 'Optional. On a settings page, the setting to scroll to (an anchor of that page). For integrations, the integration key to open, from settings_read.',
          },
        },
        required: ['section'],
      },
    },
  ];
}

function integrationManagerOf(app) {
  return app?.locals?.integrationManager || null;
}

function summarizeIntegrations(app, userId, agentId) {
  const manager = integrationManagerOf(app);
  if (!manager) return [];
  return manager.listProviders(userId, agentId).map((provider) => ({
    key: provider.id,
    label: provider.label,
    connected: provider.connection?.connected === true,
    // An integration the server operator has not configured cannot be
    // connected by the user either.
    available: provider.env?.configured !== false,
    link: buildAppLink({ section: 'integrations', focus: provider.id, integrationKeys: [provider.id] }),
  }));
}

function notifySettingsChanged(app, userId, agentId, key) {
  app?.locals?.io?.to(`user:${userId}`).emit('settings:changed', { agentId, keys: [key] });
}

async function executeAppSettingsTool(toolName, args = {}, context = {}) {
  const { userId, agentId, app, signal } = context;
  switch (toolName) {
    case 'settings_read':
      return {
        settings: await readAssistantSettings({
          userId,
          agentId,
          keys: args.keys,
          search: args.search,
          signal,
        }),
        integrations: summarizeIntegrations(app, userId, agentId),
        places: describePlaces(),
      };
    case 'settings_update': {
      const result = await updateAssistantSetting({
        userId,
        agentId,
        key: args.key,
        value: args.value,
        taskRuntime: app?.locals?.taskRuntime || null,
        signal,
      });
      if (result.success) notifySettingsChanged(app, userId, agentId, result.key);
      return result;
    }
    case 'settings_link': {
      const manager = integrationManagerOf(app);
      const integrationKeys = manager ? manager.registry.list().map((provider) => provider.key) : [];
      try {
        return {
          url: buildAppLink({
            section: args.section,
            page: args.page,
            focus: args.focus,
            integrationKeys,
          }),
        };
      } catch (error) {
        if (error.code !== 'invalid_app_link') throw error;
        return { success: false, error: error.message, expected: LINK_ARGUMENTS };
      }
    }
    default:
      return null;
  }
}

module.exports = {
  executeAppSettingsTool,
  getAppSettingsToolDefinitions,
};
