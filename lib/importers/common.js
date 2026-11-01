'use strict';

// Shared reading helpers for the OpenClaw and Hermes importers: files, env
// keys, model ids and secrets. Everything here only reads; nothing writes.

const fs = require('fs');
const os = require('os');
const path = require('path');

const PLATFORM_LABELS = { telegram: 'Telegram', discord: 'Discord', slack: 'Slack', whatsapp: 'WhatsApp' };
const MESSAGING_PLATFORMS = new Set(Object.keys(PLATFORM_LABELS));

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8').replace(/^﻿/, '').replace(/\r\n?/g, '\n');
  } catch {
    return null;
  }
}

function isDir(target) {
  try {
    return fs.statSync(target).isDirectory();
  } catch {
    return false;
  }
}

function isFile(target) {
  try {
    return fs.statSync(target).isFile();
  } catch {
    return false;
  }
}

function expandHome(value, homeDir) {
  const text = String(value || '').trim();
  if (text === '~') return homeDir;
  if (text.startsWith('~/')) return path.join(homeDir, text.slice(2));
  return text;
}

// OpenClaw keeps state in SQLite; opened read-only, and a missing file or
// table reads as empty.
function openSqlite(file) {
  if (!isFile(file)) return null;
  try {
    const Database = require('better-sqlite3');
    return new Database(file, { readonly: true, fileMustExist: true });
  } catch {
    return null;
  }
}

function queryAll(db, sql) {
  if (!db) return [];
  try {
    return db.prepare(sql).all();
  } catch {
    return [];
  }
}

// .env files written by hand: `export KEY=value`, quotes, inline comments.
function parseDotEnv(text) {
  const values = {};
  for (const rawLine of String(text || '').split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const match = line.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) continue;
    let value = match[2].trim();
    const quote = value[0];
    if ((quote === '"' || quote === "'") && value.lastIndexOf(quote) > 0) {
      value = value.slice(1, value.lastIndexOf(quote));
    } else {
      value = value.replace(/\s+#.*$/, '').trim();
    }
    if (value) values[match[1]] = value;
  }
  return values;
}

// Source env names → the names NeoAgent reads. First match wins.
const ENV_ALIASES = [
  ['ANTHROPIC_API_KEY', ['ANTHROPIC_API_KEY']],
  ['OPENAI_API_KEY', ['OPENAI_API_KEY']],
  ['OPENROUTER_API_KEY', ['OPENROUTER_API_KEY']],
  ['GOOGLE_AI_KEY', ['GOOGLE_AI_KEY', 'GEMINI_API_KEY', 'GOOGLE_API_KEY', 'GOOGLE_GENERATIVE_AI_API_KEY']],
  ['XAI_API_KEY', ['XAI_API_KEY', 'GROK_API_KEY']],
  ['NVIDIA_API_KEY', ['NVIDIA_API_KEY', 'NVIDIA_NIM_API_KEY']],
  ['MINIMAX_API_KEY', ['MINIMAX_API_KEY']],
  ['NOUS_API_KEY', ['NOUS_API_KEY']],
  ['BRAVE_SEARCH_API_KEY', ['BRAVE_SEARCH_API_KEY', 'BRAVE_API_KEY']],
  ['DEEPGRAM_API_KEY', ['DEEPGRAM_API_KEY']],
  ['ELEVENLABS_API_KEY', ['ELEVENLABS_API_KEY', 'XI_API_KEY']],
];

// Keys for services NeoAgent has no use for; named in the report so the user
// knows they were seen and left behind on purpose.
const KNOWN_FOREIGN_KEYS = new Set([
  'GROQ_API_KEY', 'MISTRAL_API_KEY', 'DEEPSEEK_API_KEY', 'TOGETHER_API_KEY', 'FIREWORKS_API_KEY',
  'COHERE_API_KEY', 'PERPLEXITY_API_KEY', 'MOONSHOT_API_KEY', 'FAL_KEY', 'FAL_API_KEY',
  'FIRECRAWL_API_KEY', 'TAVILY_API_KEY', 'EXA_API_KEY', 'BROWSERBASE_API_KEY', 'HF_TOKEN',
  'HUGGINGFACE_API_KEY', 'GITHUB_TOKEN', 'VOICE_TOOLS_OPENAI_KEY',
]);

// Splits a source env map into keys NeoAgent uses and names it does not.
function mapEnvKeys(sourceEnv) {
  const keys = {};
  for (const [target, aliases] of ENV_ALIASES) {
    const alias = aliases.find((name) => sourceEnv[name]);
    if (alias) keys[target] = sourceEnv[alias];
  }
  const consumed = new Set(ENV_ALIASES.flatMap(([, aliases]) => aliases));
  const ignored = Object.keys(sourceEnv).filter((name) => !consumed.has(name) && KNOWN_FOREIGN_KEYS.has(name));
  return { keys, ignored };
}

// Provider ids used by OpenClaw auth profiles and Hermes provider names.
const PROVIDER_KEY_ENV = {
  anthropic: 'ANTHROPIC_API_KEY',
  openai: 'OPENAI_API_KEY',
  openrouter: 'OPENROUTER_API_KEY',
  google: 'GOOGLE_AI_KEY',
  gemini: 'GOOGLE_AI_KEY',
  xai: 'XAI_API_KEY',
  grok: 'XAI_API_KEY',
  nvidia: 'NVIDIA_API_KEY',
  minimax: 'MINIMAX_API_KEY',
  nous: 'NOUS_API_KEY',
};

// "provider/model" (OpenClaw, Hermes) → NeoAgent's "provider::model".
const MODEL_PROVIDER_IDS = {
  anthropic: 'anthropic',
  openai: 'openai',
  openrouter: 'openrouter',
  google: 'google',
  gemini: 'google',
  xai: 'grok',
  grok: 'grok',
  nvidia: 'nvidia',
  minimax: 'minimax',
  ollama: 'ollama',
  nous: 'nous',
  'nous-api': 'nous',
  'openai-compatible': 'openai-compatible',
};

// "anthropic/claude-x" → "anthropic::claude-x"; OpenRouter ids keep their
// own slash ("openrouter/anthropic/claude-x").
function fromSlashModel(value) {
  const text = String(value || '').trim();
  const slash = text.indexOf('/');
  return slash > 0 ? toNeoAgentModel(text.slice(0, slash), text.slice(slash + 1)) : null;
}

function toNeoAgentModel(provider, model) {
  const providerId = MODEL_PROVIDER_IDS[String(provider || '').toLowerCase()];
  const modelId = String(model || '').trim();
  if (!providerId || !modelId) return null;
  return `${providerId}::${modelId}`;
}

// SecretRef objects ({ source: 'env', id }) and "${VAR}" strings → values.
function resolveSecret(value, env) {
  if (value && typeof value === 'object') {
    if (value.source === 'env' && value.id) return env[value.id] || null;
    if (value.source === 'file' && value.path) return (readText(expandHome(value.path, os.homedir())) || '').trim() || null;
    return null;
  }
  // "${VAR}" anywhere in the value ("Bearer ${TOKEN}"); unknown names make
  // the whole value unusable rather than half-filled.
  let missing = false;
  const text = String(value || '').trim().replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, name) => {
    if (!env[name]) missing = true;
    return env[name] || '';
  });
  return missing || !text ? null : text;
}

// A remote MCP server: an Authorization: Bearer header becomes NeoAgent's
// bearer token, other headers are kept as they are.
function mcpEntry(name, url, rawHeaders, transport, enabled, env) {
  const headers = {};
  let token = null;
  for (const [header, value] of Object.entries(rawHeaders || {})) {
    const resolved = resolveSecret(value, env);
    if (!resolved) continue;
    const bearer = header.toLowerCase() === 'authorization' && resolved.match(/^Bearer\s+(.+)$/i);
    if (bearer) token = bearer[1].trim();
    else headers[header] = resolved;
  }
  const isSse = transport === 'sse' || /\/sse\/?$/.test(url);
  return { name, url, token, headers, transport: isSse ? 'sse' : 'streamable-http', enabled };
}

module.exports = {
  MESSAGING_PLATFORMS,
  PLATFORM_LABELS,
  PROVIDER_KEY_ENV,
  expandHome,
  fromSlashModel,
  isDir,
  isFile,
  mapEnvKeys,
  mcpEntry,
  openSqlite,
  parseDotEnv,
  queryAll,
  readText,
  resolveSecret,
  toNeoAgentModel,
};
