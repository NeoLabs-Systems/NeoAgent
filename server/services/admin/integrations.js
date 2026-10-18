'use strict';

const { cleanLine, persistEnv, readEnvBool } = require('./env_config');
const { httpError } = require('../../utils/http_error');
const { LIVE_VOICE_PROVIDERS } = require('../voice/live/catalog');
const { describeLiveVoiceCatalog } = require('../voice/live/models');

// Global integration app credentials and account sign-in controls. A provider
// left unset here falls back to each user registering their own OAuth app.
const INTEGRATION_SETTINGS = [
  {
    key: 'google',
    label: 'Google Workspace',
    fields: [
      { name: 'clientId', env: 'GOOGLE_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'GOOGLE_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'GOOGLE_OAUTH_REDIRECT_URI', secret: false },
    ],
  },
  {
    key: 'openrouter',
    label: 'OpenRouter account sign-in',
    description: 'Allow registration, login, and account linking with OpenRouter. Existing model keys keep working when disabled. No OAuth app credentials are needed.',
    fields: [
      { name: 'enabled', env: 'NEOAGENT_OPENROUTER_SIGN_IN_ENABLED', type: 'boolean', defaultValue: true },
    ],
  },
  {
    key: 'notion',
    label: 'Notion',
    fields: [
      { name: 'clientId', env: 'NOTION_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'NOTION_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'NOTION_OAUTH_REDIRECT_URI', secret: false },
    ],
  },
  {
    key: 'microsoft',
    label: 'Microsoft 365',
    fields: [
      { name: 'clientId', env: 'MICROSOFT_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'MICROSOFT_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'MICROSOFT_OAUTH_REDIRECT_URI', secret: false },
      { name: 'tenantId', env: 'MICROSOFT_OAUTH_TENANT_ID', secret: false },
    ],
  },
  {
    key: 'slack',
    label: 'Slack',
    fields: [
      { name: 'clientId', env: 'SLACK_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'SLACK_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'SLACK_OAUTH_REDIRECT_URI', secret: false },
    ],
  },
  {
    key: 'figma',
    label: 'Figma',
    fields: [
      { name: 'clientId', env: 'FIGMA_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'FIGMA_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'FIGMA_OAUTH_REDIRECT_URI', secret: false },
    ],
  },
  {
    key: 'github',
    label: 'GitHub',
    fields: [
      { name: 'clientId', env: 'GITHUB_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'GITHUB_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'GITHUB_OAUTH_REDIRECT_URI', secret: false },
    ],
  },
  {
    key: 'spotify',
    label: 'Spotify',
    fields: [
      { name: 'clientId', env: 'SPOTIFY_OAUTH_CLIENT_ID', secret: false },
      { name: 'clientSecret', env: 'SPOTIFY_OAUTH_CLIENT_SECRET', secret: true },
      { name: 'redirectUri', env: 'SPOTIFY_OAUTH_REDIRECT_URI', secret: false },
    ],
  },
  {
    key: 'trello',
    label: 'Trello',
    fields: [
      { name: 'apiKey', env: 'TRELLO_API_KEY', secret: false },
    ],
  },
];

// Secrets are reported as configured or not, never echoed back.
async function getIntegrationSettings() {
  const integrations = INTEGRATION_SETTINGS.map(({ key, label, description, fields }) => ({
    key,
    label,
    ...(description ? { description } : {}),
    configured: fields.every((field) => field.type === 'boolean'
      ? readEnvBool(field.env, field.defaultValue)
      : Boolean(process.env[field.env])),
    fields: fields.map(({ name, env, secret, type, defaultValue }) => {
      if (type === 'boolean') return { name, type, value: readEnvBool(env, defaultValue) };
      return secret
        ? { name, secret: true, configured: Boolean(process.env[env]) }
        : { name, secret: false, value: process.env[env] || '' };
    }),
  }));
  // Server defaults for live voice; accounts that pick their own model in the
  // app keep it. A blank model is the newest one the server's key can reach.
  const liveVoice = {
    provider: process.env.VOICE_LIVE_PROVIDER || '',
    model: process.env.VOICE_LIVE_MODEL || '',
    voice: process.env.VOICE_LIVE_VOICE || '',
    catalog: await describeLiveVoiceCatalog(),
  };
  return { integrations, liveVoice };
}

/**
 * Applies `{ integrations: { <key>: { <field>: value } }, liveVoice }`. Unknown
 * integrations and fields are ignored; a blank secret keeps the stored one.
 */
function updateIntegrationSettings(body = {}) {
  const changes = [];
  for (const [integrationKey, values] of Object.entries(body.integrations || {})) {
    const integration = INTEGRATION_SETTINGS.find((item) => item.key === integrationKey);
    if (!integration) continue;
    for (const [fieldName, value] of Object.entries(values || {})) {
      const field = integration.fields.find((item) => item.name === fieldName);
      if (!field) continue;
      if (field.type === 'boolean') {
        if (typeof value !== 'boolean') {
          throw httpError(400, `${integrationKey}.${fieldName} must be a boolean.`);
        }
        changes.push([field.env, value ? 'true' : 'false']);
        continue;
      }
      const cleaned = cleanLine(value);
      if (field.secret && cleaned === '') continue;
      changes.push([field.env, cleaned]);
    }
  }

  if (body.liveVoice) {
    const provider = cleanLine(body.liveVoice.provider).toLowerCase();
    if (provider && !LIVE_VOICE_PROVIDERS[provider]) {
      throw new Error(`Unknown live voice provider: ${provider}`);
    }
    changes.push(['VOICE_LIVE_PROVIDER', provider]);
    changes.push(['VOICE_LIVE_MODEL', cleanLine(body.liveVoice.model)]);
    changes.push(['VOICE_LIVE_VOICE', cleanLine(body.liveVoice.voice)]);
  }
  for (const [key, value] of changes) persistEnv(key, value);
  return { ok: true };
}

module.exports = { getIntegrationSettings, updateIntegrationSettings };
