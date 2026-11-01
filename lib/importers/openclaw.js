'use strict';

// Reads an OpenClaw installation into the importer's common bundle shape
// (see apply.js). Read-only: OpenClaw keeps running and nothing is changed.

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const JSON5 = require('json5');
const {
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
} = require('./common');
const { categoryFor, splitMemoryEntries } = require('./memory_text');
const { collectChannels, collectTasks } = require('./openclaw_gateway');
const { findSkillDirs, readSkill } = require('./skills');

const CONFIG_NAMES = ['openclaw.json', 'clawdbot.json', 'moltbot.json', 'config.json'];

// Every OpenClaw state folder on this computer: the default one, named
// profiles (~/.openclaw-<profile>), the pre-rename folders, and an
// OPENCLAW_STATE_DIR override.
function findOpenClawHomes(homeDir = os.homedir(), env = process.env) {
  const candidates = [];
  if (env.OPENCLAW_STATE_DIR) candidates.push(expandHome(env.OPENCLAW_STATE_DIR, homeDir));
  candidates.push(path.join(homeDir, '.openclaw'));
  try {
    for (const name of fs.readdirSync(homeDir).sort()) {
      if (/^\.openclaw-[\w.-]+$/.test(name)) candidates.push(path.join(homeDir, name));
    }
  } catch {}
  candidates.push(path.join(homeDir, '.clawdbot'), path.join(homeDir, '.moltbot'));
  const seen = new Set();
  return candidates.filter((dir) => {
    const resolved = path.resolve(dir);
    if (seen.has(resolved) || !configPath(resolved)) return false;
    seen.add(resolved);
    return true;
  });
}

function configPath(home) {
  const name = CONFIG_NAMES.find((candidate) => isFile(path.join(home, candidate)));
  return name ? path.join(home, name) : null;
}

function describeHome(home, homeDir = os.homedir()) {
  const profile = path.basename(home).match(/^\.openclaw-(.+)$/);
  return {
    label: profile ? `OpenClaw (${profile[1]})` : 'OpenClaw',
    path: home.startsWith(homeDir) ? `~${home.slice(homeDir.length)}` : home,
  };
}

function sha256(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}

function scanOpenClaw(home) {
  const config = (() => {
    try {
      return JSON5.parse(readText(configPath(home)) || '{}') || {};
    } catch {
      return {};
    }
  })();
  const stateDb = openSqlite(path.join(home, 'state', 'openclaw.sqlite'));
  const skipped = [];

  const env = collectEnv(home, config, stateDb);
  const agents = collectAgents(home, config, stateDb, skipped);
  const { keys: envKeys, ignored } = mapEnvKeys(env);
  const keys = { ...collectAuthProfileKeys(home, agents, skipped), ...envKeys };
  const providers = collectProviders(config, env, skipped);
  Object.assign(keys, providers.keys);

  const defaults = config.agents?.defaults || {};
  const sourceModel = modelOf(defaults.model, defaults.models);
  const bundle = {
    source: 'openclaw',
    ...describeHome(home),
    home,
    agents,
    skills: collectSkills(home, agents),
    keys,
    ignoredKeys: ignored,
    sourceModel,
    model: fromSlashModel(sourceModel),
    mcp: collectMcp(config, env, skipped),
    tasks: collectTasks(home, stateDb, agents, skipped),
    channels: collectChannels(home, config, env, stateDb, skipped),
    timezone: null,
    skipped,
  };
  bundle.timezone = bundle.tasks.find((task) => task.tz)?.tz || timezoneFromProfile(agents) || null;
  if (stateDb) stateDb.close();
  return bundle;
}

// agents.defaults.model is "provider/model", { primary }, or an alias name
// from agents.defaults.models.
function modelOf(model, catalog = {}) {
  const raw = typeof model === 'string' ? model : model?.primary;
  if (!raw) return null;
  if (raw.includes('/')) return raw;
  const aliased = Object.entries(catalog || {}).find(([, entry]) => entry?.alias === raw);
  return aliased ? aliased[0] : null;
}

function collectEnv(home, config, stateDb) {
  const env = { ...parseDotEnv(readText(path.join(home, '.env'))) };
  const inline = config.env && typeof config.env === 'object' ? config.env : {};
  for (const [key, value] of Object.entries({ ...inline, ...(inline.vars || {}) })) {
    if (typeof value === 'string' && value && !env[key]) env[key] = value;
  }
  for (const row of queryAll(stateDb, 'SELECT name, value FROM secret_store_entries WHERE deleted_at_ms IS NULL')) {
    if (row.value && !env[row.name]) env[row.name] = row.value;
  }
  return env;
}

// Agent list → each agent's workspace files. Template files that were never
// edited are left out: OpenClaw records the hash of every file it generated.
function collectAgents(home, config, stateDb, skipped) {
  const generated = new Set(queryAll(stateDb, 'SELECT sha256 FROM workspace_generated_bootstrap_hashes').map((row) => row.sha256));
  const defaults = config.agents?.defaults || {};
  const entries = config.agents?.entries
    ? Object.entries(config.agents.entries).map(([id, entry]) => ({ id, ...entry }))
    : (Array.isArray(config.agents?.list) ? config.agents.list : []);
  if (entries.length === 0) entries.push({ id: 'main' });
  const defaultId = defaults.systemAgent?.agentId
    || entries.find((entry) => entry.default)?.id
    || entries[0].id;

  return entries.map((entry) => {
    const workspace = resolveWorkspace(home, entry, defaults, entries.length);
    const read = (name) => {
      const text = readText(path.join(workspace, name));
      if (text == null || !text.trim() || generated.has(sha256(text))) return null;
      return text;
    };
    const agentsFile = read('AGENTS.md');
    if (agentsFile) {
      skipped.push({ kind: 'Instructions', name: `${entry.id}/AGENTS.md`, reason: 'OpenClaw\'s operating manual for its own tools; copy any rules you added by hand' });
    }
    const identityName = entry.identity?.name || identityNameFrom(read('IDENTITY.md'));
    const soul = cleanPersona(read('SOUL.md'));
    const memory = read('MEMORY.md');
    const user = read('USER.md');
    return {
      key: entry.id,
      name: identityName || entry.name || entry.id,
      isDefault: entry.id === defaultId,
      instructions: [identityName ? `Your name is ${identityName}.` : '', soul].filter(Boolean).join('\n\n') || null,
      memories: memory
        ? splitMemoryEntries(memory).map((item) => ({ text: item.text, category: categoryFor(item.heading, 'episodic') }))
        : [],
      userProfile: user ? userProfileFrom(user) : null,
      dailyLogs: readDailyLogs(path.join(workspace, 'memory')),
      workspace,
      model: fromSlashModel(modelOf(entry.model, defaults.models)),
    };
  });
}

function resolveWorkspace(home, entry, defaults, agentCount) {
  if (entry.workspace) return expandHome(entry.workspace, os.homedir());
  if (agentCount === 1) {
    if (defaults.workspace) return expandHome(defaults.workspace, os.homedir());
    const main = path.join(home, 'workspace-main');
    return isDir(main) ? main : path.join(home, 'workspace');
  }
  if (defaults.workspace) return path.join(expandHome(defaults.workspace, os.homedir()), entry.id);
  return path.join(home, `workspace-${entry.id}`);
}

function identityNameFrom(text) {
  const match = String(text || '').match(/^\s*[-*]?\s*\*{0,2}Name:?\*{0,2}:?\s*(.+)$/im);
  const name = match ? match[1].replace(/[*_]/g, '').trim() : '';
  return name && !/^\(.*\)$/.test(name) ? name : null;
}

function cleanPersona(text) {
  if (!text) return null;
  const cleaned = text
    .replace(/^#\s*SOUL\.md.*$/im, '')
    .replace(/^_?\(.*\)_?$/gm, '')
    .trim();
  return cleaned || null;
}

// USER.md → plain "Label: value" lines and notes, without template headings.
function userProfileFrom(text) {
  const lines = splitMemoryEntries(text).map((entry) => entry.text);
  return lines.length ? lines.join('\n') : null;
}

function timezoneFromProfile(agents) {
  for (const agent of agents) {
    const match = String(agent.userProfile || '').match(/time\s*zone:\s*([A-Za-z_]+\/[A-Za-z_]+)/i);
    if (match) return match[1];
  }
  return null;
}

function readDailyLogs(dir) {
  if (!isDir(dir)) return [];
  return fs.readdirSync(dir)
    .filter((name) => /^\d{4}-\d{2}-\d{2}\.md$/.test(name))
    .sort()
    .map((name) => ({ date: name.slice(0, 10), content: (readText(path.join(dir, name)) || '').trim() }))
    .filter((log) => log.content);
}

// API keys stored in each agent's auth profiles (SQLite since 2026, an
// auth-profiles.json file before that).
function collectAuthProfileKeys(home, agents, skipped) {
  const keys = {};
  const oauth = new Set();
  const stores = [];
  for (const agent of agents) {
    const agentDir = path.join(home, 'agents', agent.key, 'agent');
    const db = openSqlite(path.join(agentDir, 'openclaw-agent.sqlite'));
    for (const row of queryAll(db, 'SELECT store_json FROM auth_profile_store')) {
      try {
        stores.push(JSON.parse(row.store_json));
      } catch {}
    }
    if (db) db.close();
    const legacy = readText(path.join(agentDir, 'auth-profiles.json'));
    if (legacy) {
      try {
        stores.push(JSON.parse(legacy));
      } catch {}
    }
  }
  for (const store of stores) {
    for (const profile of Object.values(store?.profiles || {})) {
      const envKey = PROVIDER_KEY_ENV[String(profile?.provider || '').toLowerCase()];
      const secret = profile?.key || profile?.token || profile?.apiKey;
      if (envKey && secret && ['api_key', 'token'].includes(profile.type || 'api_key')) {
        keys[envKey] = keys[envKey] || secret;
      } else if (profile?.provider && (profile.type === 'oauth' || profile.access)) {
        oauth.add(profile.provider);
      }
    }
  }
  for (const provider of oauth) {
    skipped.push({ kind: 'Sign-in', name: provider, reason: 'OAuth sign-ins cannot be copied; sign in again under Admin → Providers in the app' });
  }
  return keys;
}

// Custom providers: Ollama becomes OLLAMA_URL, the first other
// OpenAI-compatible endpoint becomes NeoAgent's "OpenAI-compatible" provider.
function collectProviders(config, env, skipped) {
  const keys = {};
  for (const [name, provider] of Object.entries(config.models?.providers || {})) {
    if (!provider || typeof provider !== 'object') continue;
    const apiKey = resolveSecret(provider.apiKey, env);
    const knownEnv = PROVIDER_KEY_ENV[name.toLowerCase()];
    if (knownEnv && apiKey && !provider.baseUrl) {
      keys[knownEnv] = apiKey;
      continue;
    }
    const baseUrl = String(provider.baseUrl || '').trim();
    if (!baseUrl) continue;
    if (name.toLowerCase() === 'ollama' || /:11434\b/.test(baseUrl)) {
      keys.OLLAMA_URL = baseUrl.replace(/\/v1\/?$/, '');
    } else if (!keys.OPENAI_COMPATIBLE_BASE_URL && /openai/.test(String(provider.api || 'openai'))) {
      keys.OPENAI_COMPATIBLE_BASE_URL = baseUrl;
      if (apiKey) keys.OPENAI_COMPATIBLE_API_KEY = apiKey;
    } else {
      skipped.push({ kind: 'AI provider', name, reason: 'NeoAgent has room for one OpenAI-compatible endpoint; add this one by hand if you need it' });
    }
  }
  return { keys };
}

function collectSkills(home, agents) {
  const roots = [
    [path.join(home, 'skills'), 'OpenClaw'],
    ...agents.map((agent) => [path.join(agent.workspace, 'skills'), agent.name]),
  ];
  const seen = new Set();
  const skills = [];
  for (const [root, origin] of roots) {
    for (const dir of findSkillDirs(root)) {
      const skill = readSkill(dir, origin);
      if (!skill || seen.has(skill.name)) continue;
      seen.add(skill.name);
      skills.push(skill);
    }
  }
  return skills;
}

function collectMcp(config, env, skipped) {
  const servers = [];
  for (const [name, server] of Object.entries(config.mcp?.servers || {})) {
    if (!server || typeof server !== 'object') continue;
    if (!server.url) {
      skipped.push({ kind: 'MCP server', name, reason: `runs a local program (${server.command || 'stdio'}); NeoAgent connects to MCP servers by URL`, detail: server });
      continue;
    }
    servers.push(mcpEntry(name, server.url, server.headers, server.transport, server.enabled !== false, env));
  }
  return servers;
}

module.exports = {
  describeHome,
  findOpenClawHomes,
  scanOpenClaw,
};
