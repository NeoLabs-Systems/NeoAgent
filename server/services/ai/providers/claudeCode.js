const os = require('os');
const fs = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');
const { AnthropicProvider } = require('./anthropic');

const CLAUDE_CLI_CREDS_PATH = path.join(os.homedir(), '.claude', '.credentials.json');
const CLAUDE_CODE_BASE_URL = 'https://api.anthropic.com';
const CLAUDE_CODE_VERSION = process.env.CLAUDE_CODE_VERSION || '2.1.75';
const CLAUDE_CODE_OAUTH_BETA = 'claude-code-20250219,oauth-2025-04-20,fine-grained-tool-streaming-2025-05-14';
const CLAUDE_CODE_SYSTEM_PROMPT = "You are Claude Code, Anthropic's official CLI for Claude.";

function readTokenValue(data) {
  return data?.claudeAiOauthTokens?.accessToken
    || data?.claudeAiOauth?.accessToken
    || data?.claudeAiOauth?.access
    || null;
}

function readClaudeCliToken() {
  try {
    const raw = fs.readFileSync(CLAUDE_CLI_CREDS_PATH, 'utf8');
    const data = JSON.parse(raw);
    const token = readTokenValue(data);
    return typeof token === 'string' && token ? token : null;
  } catch {
    return null;
  }
}

function mergeAnthropicBeta(existing) {
  if (!existing) return CLAUDE_CODE_OAUTH_BETA;
  const seen = new Set();
  return String(existing)
    .split(',')
    .concat(CLAUDE_CODE_OAUTH_BETA.split(','))
    .map((item) => item.trim())
    .filter((item) => {
      if (!item || seen.has(item)) return false;
      seen.add(item);
      return true;
    })
    .join(',');
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

    const authToken = config.apiKey || process.env.CLAUDE_CODE_OAUTH_TOKEN || readClaudeCliToken();
    if (!authToken) {
      console.warn('[ClaudeCode] No access token. Run `neoagent login claude-code` to authenticate.');
    }

    const defaultHeaders = {
      ...(config.defaultHeaders || {}),
      accept: 'application/json',
      'anthropic-dangerous-direct-browser-access': 'true',
      'anthropic-beta': mergeAnthropicBeta(config.defaultHeaders?.['anthropic-beta']),
      'user-agent': `claude-cli/${CLAUDE_CODE_VERSION}`,
      'x-app': 'cli',
    };

    // OAuth tokens use Authorization: Bearer. Claude Code subscription inference
    // also requires the Claude Code beta surface headers used by the official CLI.
    this.client = new Anthropic({
      authToken: authToken || undefined,
      baseURL: config.baseUrl || CLAUDE_CODE_BASE_URL,
      defaultHeaders: authToken ? defaultHeaders : config.defaultHeaders,
      ...(config.fetch ? { fetch: config.fetch } : {}),
    });
  }

  convertMessages(messages) {
    const converted = super.convertMessages(messages);
    if (!converted.system) {
      converted.system = [{ type: 'text', text: CLAUDE_CODE_SYSTEM_PROMPT }];
      return converted;
    }
    converted.system = [
      { type: 'text', text: CLAUDE_CODE_SYSTEM_PROMPT },
      { type: 'text', text: converted.system },
    ];
    return converted;
  }
}

module.exports = { ClaudeCodeProvider, readClaudeCliToken };
