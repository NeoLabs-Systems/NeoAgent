'use strict';

const AI_PROVIDER_DEFINITIONS = Object.freeze({
  openai: {
    id: 'openai',
    label: 'OpenAI',
    description: 'Current GPT models for general work, coding, and reasoning.',
    envKey: 'OPENAI_API_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: true,
    defaultBaseUrl: ''
  },
  'openai-compatible': {
    id: 'openai-compatible',
    label: 'Custom OpenAI-compatible',
    description: 'Models exposed by a custom OpenAI-compatible Chat Completions endpoint.',
    envKey: 'OPENAI_COMPATIBLE_API_KEY',
    baseUrlEnvKey: 'OPENAI_COMPATIBLE_BASE_URL',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    requiresBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  anthropic: {
    id: 'anthropic',
    label: 'Anthropic',
    description: 'Claude models for long-context drafting and analytical work.',
    envKey: 'ANTHROPIC_API_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  google: {
    id: 'google',
    label: 'Google',
    description: 'Gemini models with large context windows and multimodal support.',
    envKey: 'GOOGLE_AI_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: false,
    defaultEnabled: true,
    defaultBaseUrl: ''
  },
  grok: {
    id: 'grok',
    label: 'xAI',
    description: 'Grok models tuned for personality-heavy chat and reasoning.',
    envKey: 'XAI_API_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: true,
    defaultBaseUrl: 'https://api.x.ai/v1'
  },
  'grok-oauth': {
    id: 'grok-oauth',
    label: 'Grok (xAI OAuth)',
    description: 'Grok models via xAI account. Login with `neoagent login grok-oauth`.',
    envKey: 'GROK_OAUTH_ACCESS_TOKEN',
    authentication: 'oauth',
    supportsApiKey: true,
    supportsBaseUrl: false,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  nvidia: {
    id: 'nvidia',
    label: 'NVIDIA NIM',
    description: 'NVIDIA-hosted models including free-tier Nemotron, Kimi, Llama 4, and DeepSeek. Get a key at build.nvidia.com.',
    envKey: 'NVIDIA_API_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://integrate.api.nvidia.com/v1'
  },
  minimax: {
    id: 'minimax',
    label: 'MiniMax Code',
    description: 'MiniMax Coding Plan for MiniMax-M2.7 through the Anthropic-compatible endpoint.',
    envKey: 'MINIMAX_API_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://api.minimax.io/anthropic'
  },
  'github-copilot': {
    id: 'github-copilot',
    label: 'GitHub Copilot',
    description: 'Use your GitHub Copilot subscription as an AI provider.',
    envKey: 'GITHUB_COPILOT_ACCESS_TOKEN',
    authentication: 'oauth',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://api.githubcopilot.com'
  },
  'openai-codex': {
    id: 'openai-codex',
    label: 'OpenAI Codex',
    description: 'Use Codex models through ChatGPT Codex authentication.',
    envKey: 'OPENAI_CODEX_ACCESS_TOKEN',
    authentication: 'oauth',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://chatgpt.com/backend-api/codex'
  },
  'claude-code': {
    id: 'claude-code',
    label: 'Claude Code',
    description: 'Claude models via Claude Code subscription. Login with `neoagent login claude-code`.',
    envKey: 'CLAUDE_CODE_OAUTH_TOKEN',
    authentication: 'oauth',
    supportsApiKey: true,
    supportsBaseUrl: false,
    defaultEnabled: false,
    defaultBaseUrl: ''
  },
  openrouter: {
    id: 'openrouter',
    label: 'OpenRouter',
    description: 'Access 300+ models through one API, including free-tier models. Get a key at openrouter.ai.',
    envKey: 'OPENROUTER_API_KEY',
    authentication: 'api_key',
    supportsApiKey: true,
    supportsBaseUrl: true,
    defaultEnabled: false,
    defaultBaseUrl: 'https://openrouter.ai/api/v1'
  },
  ollama: {
    id: 'ollama',
    label: 'Ollama',
    description: 'Local models running on your machine through an Ollama server.',
    envKey: '',
    authentication: 'local',
    supportsApiKey: false,
    supportsBaseUrl: true,
    defaultEnabled: true,
    defaultBaseUrl: 'http://localhost:11434'
  }
});

module.exports = {
  AI_PROVIDER_DEFINITIONS,
};
