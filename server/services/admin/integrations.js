'use strict';

const { cleanLine, persistEnv } = require('./env_config');

// Server-wide OAuth app credentials that let accounts connect each integration.
const OAUTH_INTEGRATIONS = [
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
function getIntegrationSettings() {
  const integrations = OAUTH_INTEGRATIONS.map(({ key, label, fields }) => ({
    key,
    label,
    configured: fields.every(({ env }) => Boolean(process.env[env])),
    fields: fields.map(({ name, env, secret }) => (secret
      ? { name, secret: true, configured: Boolean(process.env[env]) }
      : { name, secret: false, value: process.env[env] || '' })),
  }));
  const deepgram = {
    baseUrl: process.env.DEEPGRAM_BASE_URL || '',
    model: process.env.DEEPGRAM_MODEL || '',
    language: process.env.DEEPGRAM_LANGUAGE || '',
  };
  return { integrations, deepgram };
}

/**
 * Applies `{ integrations: { <key>: { <field>: value } }, deepgram }`. Unknown
 * integrations and fields are ignored; a blank secret keeps the stored one.
 */
function updateIntegrationSettings(body = {}) {
  for (const [integrationKey, values] of Object.entries(body.integrations || {})) {
    const integration = OAUTH_INTEGRATIONS.find((item) => item.key === integrationKey);
    if (!integration) continue;
    for (const [fieldName, value] of Object.entries(values || {})) {
      const field = integration.fields.find((item) => item.name === fieldName);
      if (!field) continue;
      const cleaned = cleanLine(value);
      if (field.secret && cleaned === '') continue;
      persistEnv(field.env, cleaned);
    }
  }

  if (body.deepgram) {
    persistEnv('DEEPGRAM_BASE_URL', cleanLine(body.deepgram.baseUrl));
    persistEnv('DEEPGRAM_MODEL', cleanLine(body.deepgram.model));
    persistEnv('DEEPGRAM_LANGUAGE', cleanLine(body.deepgram.language));
  }
  return { ok: true };
}

module.exports = { getIntegrationSettings, updateIntegrationSettings };
