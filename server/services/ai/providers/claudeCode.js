const os = require('os');
const fs = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');
const { AnthropicProvider } = require('./anthropic');

const CLAUDE_CLI_CREDS_PATH = path.join(os.homedir(), '.claude', '.credentials.json');
const CLAUDE_CODE_BASE_URL = 'https://api.claude.ai/api';

function readClaudeCliToken() {
  try {
    const raw = fs.readFileSync(CLAUDE_CLI_CREDS_PATH, 'utf8');
    const data = JSON.parse(raw);
    const token = data?.claudeAiOauthTokens?.accessToken;
    return typeof token === 'string' && token ? token : null;
  } catch {
    return null;
  }
}

class ClaudeCodeProvider extends AnthropicProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'claude-code';
    this.models = [
      'claude-opus-4-7',
      'claude-sonnet-4-6',
      'claude-haiku-4-5-20251001',
    ];
    this.contextWindows = {
      'claude-opus-4-7': 200000,
      'claude-sonnet-4-6': 200000,
      'claude-haiku-4-5-20251001': 200000,
    };

    const authToken = config.apiKey || process.env.CLAUDE_CODE_ACCESS_TOKEN || readClaudeCliToken();
    if (!authToken) {
      console.warn('[ClaudeCode] No access token. Run `neoagent login claude-code` to authenticate.');
    }

    // OAuth tokens use Authorization: Bearer — authToken option sends that header
    this.client = new Anthropic({
      authToken: authToken || undefined,
      baseURL: config.baseUrl || CLAUDE_CODE_BASE_URL,
    });
  }
}

module.exports = { ClaudeCodeProvider, readClaudeCliToken };
