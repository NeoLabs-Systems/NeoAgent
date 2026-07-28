'use strict';

const PROVIDER_FIELDS = Object.freeze([
  { key: 'ANTHROPIC_API_KEY', label: 'Anthropic API key', secret: true },
  { key: 'ANTHROPIC_BASE_URL', label: 'Anthropic base URL' },
  { key: 'OPENAI_API_KEY', label: 'OpenAI API key', secret: true },
  { key: 'OPENAI_BASE_URL', label: 'OpenAI base URL' },
  { key: 'XAI_API_KEY', label: 'xAI API key', secret: true },
  { key: 'XAI_BASE_URL', label: 'xAI base URL', defaultValue: 'https://api.x.ai/v1' },
  { key: 'GOOGLE_AI_KEY', label: 'Google API key', secret: true },
  { key: 'MINIMAX_API_KEY', label: 'MiniMax Code key', secret: true },
  { key: 'BRAVE_SEARCH_API_KEY', label: 'Brave Search API key', secret: true },
  { key: 'OLLAMA_URL', label: 'Ollama URL', defaultValue: 'http://localhost:11434' },
]);

const INTEGRATION_FIELDS = Object.freeze([
  { key: 'GOOGLE_OAUTH_CLIENT_ID', label: 'Google OAuth client ID', secret: true },
  { key: 'GOOGLE_OAUTH_CLIENT_SECRET', label: 'Google OAuth client secret', secret: true },
  { key: 'GOOGLE_OAUTH_REDIRECT_URI', label: 'Google OAuth redirect URI' },
  { key: 'NOTION_OAUTH_CLIENT_ID', label: 'Notion OAuth client ID', secret: true },
  { key: 'NOTION_OAUTH_CLIENT_SECRET', label: 'Notion OAuth client secret', secret: true },
  { key: 'NOTION_OAUTH_REDIRECT_URI', label: 'Notion OAuth redirect URI' },
  { key: 'MICROSOFT_OAUTH_CLIENT_ID', label: 'Microsoft 365 OAuth client ID', secret: true },
  { key: 'MICROSOFT_OAUTH_CLIENT_SECRET', label: 'Microsoft 365 OAuth client secret', secret: true },
  { key: 'MICROSOFT_OAUTH_REDIRECT_URI', label: 'Microsoft 365 OAuth redirect URI' },
  { key: 'MICROSOFT_OAUTH_TENANT_ID', label: 'Microsoft 365 OAuth tenant ID', defaultValue: 'common' },
  { key: 'SLACK_OAUTH_CLIENT_ID', label: 'Slack OAuth client ID', secret: true },
  { key: 'SLACK_OAUTH_CLIENT_SECRET', label: 'Slack OAuth client secret', secret: true },
  { key: 'SLACK_OAUTH_REDIRECT_URI', label: 'Slack OAuth redirect URI' },
  { key: 'FIGMA_OAUTH_CLIENT_ID', label: 'Figma OAuth client ID', secret: true },
  { key: 'FIGMA_OAUTH_CLIENT_SECRET', label: 'Figma OAuth client secret', secret: true },
  { key: 'FIGMA_OAUTH_REDIRECT_URI', label: 'Figma OAuth redirect URI' },
  { key: 'GITHUB_OAUTH_CLIENT_ID', label: 'GitHub OAuth client ID', secret: true },
  { key: 'GITHUB_OAUTH_CLIENT_SECRET', label: 'GitHub OAuth client secret', secret: true },
  { key: 'GITHUB_OAUTH_REDIRECT_URI', label: 'GitHub OAuth redirect URI' },
]);

const VOICE_FIELDS = Object.freeze([
  { key: 'DEEPGRAM_API_KEY', label: 'Deepgram API key', secret: true },
  { key: 'DEEPGRAM_BASE_URL', label: 'Deepgram base URL', defaultValue: 'https://api.deepgram.com' },
  { key: 'DEEPGRAM_MODEL', label: 'Deepgram model', defaultValue: 'nova-3' },
  { key: 'DEEPGRAM_LANGUAGE', label: 'Deepgram language', defaultValue: 'multi' },
]);

const SECTION_COMPLETION_KEYS = Object.freeze({
  providers: Object.freeze([
    'ANTHROPIC_API_KEY',
    'OPENAI_API_KEY',
    'XAI_API_KEY',
    'GOOGLE_AI_KEY',
    'MINIMAX_API_KEY',
  ]),
  integrations: Object.freeze([
    'GOOGLE_OAUTH_CLIENT_ID',
    'NOTION_OAUTH_CLIENT_ID',
    'MICROSOFT_OAUTH_CLIENT_ID',
    'SLACK_OAUTH_CLIENT_ID',
    'FIGMA_OAUTH_CLIENT_ID',
    'GITHUB_OAUTH_CLIENT_ID',
  ]),
  voice: Object.freeze(['DEEPGRAM_API_KEY']),
});

module.exports = {
  INTEGRATION_FIELDS,
  PROVIDER_FIELDS,
  SECTION_COMPLETION_KEYS,
  VOICE_FIELDS,
};
