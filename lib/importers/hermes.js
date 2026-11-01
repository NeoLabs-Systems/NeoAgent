'use strict';

// Reads a Hermes Agent installation into the importer's common bundle shape
// (see apply.js). The default home becomes NeoAgent's main agent and every
// profile under profiles/ becomes an agent of its own. Read-only.

const fs = require('fs');
const os = require('os');
const path = require('path');
const YAML = require('yaml');
const {
  expandHome,
  isDir,
  isFile,
  MESSAGING_PLATFORMS,
  mapEnvKeys,
  mcpEntry,
  parseDotEnv,
  readText,
  toNeoAgentModel,
} = require('./common');
const { categoryFor, splitMemoryEntries } = require('./memory_text');
const { intervalToCron, toFiveFieldCron } = require('./schedules');
const { findSkillDirs, readSkill } = require('./skills');

// Self-hosted endpoints reach NeoAgent through its OpenAI-compatible slot.
const COMPATIBLE_PROVIDERS = new Set(['custom', 'lmstudio']);

// Hermes writes this persona when none exists; it is not the user's.
const DEFAULT_SOUL_PREFIX = 'You are Hermes Agent, built by Nous Research.';

function findHermesHomes(homeDir = os.homedir(), env = process.env) {
  const candidates = [];
  if (env.HERMES_HOME) candidates.push(expandHome(env.HERMES_HOME, homeDir));
  candidates.push(path.join(homeDir, '.hermes'));
  const seen = new Set();
  return candidates.filter((dir) => {
    const resolved = path.resolve(dir);
    // A profile folder passed through HERMES_HOME is read with its parent.
    if (seen.has(resolved) || path.basename(path.dirname(resolved)) === 'profiles') return false;
    if (!isFile(path.join(resolved, 'config.yaml')) && !isFile(path.join(resolved, '.env'))) return false;
    seen.add(resolved);
    return true;
  });
}

function describeHome(home, homeDir = os.homedir()) {
  return {
    label: 'Hermes Agent',
    path: home.startsWith(homeDir) ? `~${home.slice(homeDir.length)}` : home,
  };
}

function readConfig(home) {
  try {
    return YAML.parse(readText(path.join(home, 'config.yaml')) || '') || {};
  } catch {
    return {};
  }
}

function scanHermes(home) {
  const skipped = [];
  const profileDirs = isDir(path.join(home, 'profiles'))
    ? fs.readdirSync(path.join(home, 'profiles')).sort()
      .map((name) => path.join(home, 'profiles', name))
      .filter((dir) => isDir(dir))
    : [];
  const homes = [{ key: 'default', dir: home, isDefault: true }]
    .concat(profileDirs.map((dir) => ({ key: path.basename(dir), dir, isDefault: false })));

  const config = readConfig(home);
  const env = parseDotEnv(readText(path.join(home, '.env')));
  const { keys, ignored } = mapEnvKeys(env);
  for (const profile of homes.slice(1)) {
    // Profile-only keys still count: NeoAgent has one set for every agent.
    const profileKeys = mapEnvKeys(parseDotEnv(readText(path.join(profile.dir, '.env')))).keys;
    for (const [name, value] of Object.entries(profileKeys)) keys[name] = keys[name] || value;
  }
  Object.assign(keys, collectProviders(config, env, skipped));

  const agents = homes.map((entry) => readAgent(entry));
  const skills = [];
  const seenSkills = new Set();
  for (const entry of homes) {
    for (const skill of collectSkills(entry.dir, entry.isDefault ? 'Hermes' : entry.key)) {
      if (seenSkills.has(skill.name)) continue;
      seenSkills.add(skill.name);
      skills.push(skill);
    }
  }

  const sourceModel = modelOf(config.model);

  return {
    source: 'hermes',
    ...describeHome(home),
    home,
    agents,
    skills,
    keys,
    ignoredKeys: ignored,
    sourceModel: sourceModel ? `${sourceModel.model} (${configuredProvider(config.model)})` : null,
    model: modelId(sourceModel),
    mcp: collectMcp(config, env, skipped),
    tasks: homes.flatMap((entry) => collectTasks(entry, skipped)),
    channels: collectChannels(env, skipped),
    timezone: typeof config.timezone === 'string' && config.timezone.includes('/') ? config.timezone : null,
    skipped,
  };
}

// model: "name" or { default|model, provider }. "auto" picks a provider from
// whichever key is present; the model id then says which ("anthropic/…").
function modelOf(model) {
  const value = typeof model === 'string' ? { default: model } : (model || {});
  const id = String(value.default || value.model || '').trim();
  if (!id) return null;
  const provider = String(value.provider || 'auto').trim();
  if (COMPATIBLE_PROVIDERS.has(provider)) return { provider: 'openai-compatible', model: id };
  if (provider !== 'auto') return { provider, model: id };
  const slash = id.indexOf('/');
  return slash > 0 ? { provider: id.slice(0, slash), model: id.slice(slash + 1) } : null;
}

function configuredProvider(model) {
  const provider = typeof model === 'object' && model ? String(model.provider || 'auto') : 'auto';
  return provider === 'nous-api' || provider === 'nous' ? 'Nous Portal' : provider;
}

function modelId(model) {
  return model ? toNeoAgentModel(model.provider, model.model) : null;
}

function readAgent({ key, dir, isDefault }) {
  const soul = (readText(path.join(dir, 'SOUL.md')) || '').trim();
  const memory = readText(path.join(dir, 'memories', 'MEMORY.md'));
  const user = readText(path.join(dir, 'memories', 'USER.md'));
  return {
    key,
    name: isDefault ? 'Hermes' : key,
    isDefault,
    instructions: soul && !soul.startsWith(DEFAULT_SOUL_PREFIX) ? soul : null,
    memories: memory
      ? splitMemoryEntries(memory).map((item) => ({ text: item.text, category: categoryFor(item.text, 'episodic') }))
      : [],
    userProfile: user ? splitMemoryEntries(user).map((item) => item.text).join('\n') || null : null,
    dailyLogs: [],
    workspace: dir,
    model: null,
  };
}

// Skills Hermes ships itself are listed in skills/.bundled_manifest
// ("name:hash" per line); only the rest are the user's.
function collectSkills(dir, origin) {
  const root = path.join(dir, 'skills');
  const bundled = new Set((readText(path.join(root, '.bundled_manifest')) || '')
    .split('\n')
    .map((line) => line.split(':')[0].trim())
    .filter(Boolean));
  return findSkillDirs(root)
    .map((skillDir) => readSkill(skillDir, origin))
    .filter((skill) => skill && !bundled.has(skill.name) && !bundled.has(path.basename(skill.dir)));
}

function collectProviders(config, env, skipped) {
  const keys = {};
  const model = typeof config.model === 'object' && config.model ? config.model : {};
  const entries = (Array.isArray(config.custom_providers) ? config.custom_providers : [])
    .map((entry) => ({ name: entry?.name || 'custom', baseUrl: entry?.base_url || entry?.baseUrl, apiKey: entry?.api_key || entry?.apiKey }));
  if (model.provider === 'custom' && model.base_url) {
    entries.unshift({ name: 'custom', baseUrl: model.base_url, apiKey: model.api_key || env.OPENAI_API_KEY });
  }
  if (model.provider === 'lmstudio') {
    entries.unshift({ name: 'lmstudio', baseUrl: model.base_url || 'http://127.0.0.1:1234/v1', apiKey: env.LM_API_KEY });
  }
  // A Portal login (provider "nous") is OAuth; only an API key carries over.
  if (model.provider === 'nous' && !env.NOUS_API_KEY) {
    skipped.push({ kind: 'Sign-in', name: 'Nous Portal', reason: 'the Portal sign-in cannot be copied; create an API key at portal.nousresearch.com and run the import again' });
  }
  for (const entry of entries) {
    const baseUrl = String(entry.baseUrl || '').trim();
    if (!baseUrl) continue;
    if (/:11434\b/.test(baseUrl) || /ollama/i.test(entry.name)) {
      keys.OLLAMA_URL = keys.OLLAMA_URL || baseUrl.replace(/\/v1\/?$/, '');
    } else if (!keys.OPENAI_COMPATIBLE_BASE_URL) {
      keys.OPENAI_COMPATIBLE_BASE_URL = baseUrl;
      if (entry.apiKey) keys.OPENAI_COMPATIBLE_API_KEY = entry.apiKey;
    } else {
      skipped.push({ kind: 'AI provider', name: entry.name, reason: 'NeoAgent has room for one OpenAI-compatible endpoint; add this one by hand if you need it' });
    }
  }
  return keys;
}

function collectMcp(config, env, skipped) {
  const servers = [];
  for (const [name, server] of Object.entries(config.mcp_servers || {})) {
    if (!server || typeof server !== 'object') continue;
    if (!server.url) {
      skipped.push({ kind: 'MCP server', name, reason: `runs a local program (${server.command || 'stdio'}); NeoAgent connects to MCP servers by URL`, detail: server });
      continue;
    }
    servers.push(mcpEntry(name, server.url, server.headers, server.transport, server.enabled !== false, env));
  }
  return servers;
}

function collectTasks({ key, dir }, skipped) {
  let jobs = [];
  try {
    const parsed = JSON.parse(readText(path.join(dir, 'cron', 'jobs.json')) || '[]');
    jobs = Array.isArray(parsed) ? parsed : (parsed.jobs || []);
  } catch {}

  const tasks = [];
  for (const job of jobs) {
    const name = String(job.name || job.prompt || 'Scheduled job').trim().slice(0, 80);
    if (job.no_agent || (!job.prompt && job.script)) {
      const script = job.script ? readText(path.join(dir, 'scripts', job.script)) : null;
      skipped.push({ kind: 'Automation', name, reason: 'runs a script on this computer; NeoAgent\'s agent works on its own computer', detail: { schedule: job.schedule?.display, script: job.script, content: script?.slice(0, 2000) } });
      continue;
    }
    const skills = Array.isArray(job.skills) ? job.skills.filter(Boolean) : [];
    const prompt = [skills.length ? `Use the ${skills.join(', ')} skill${skills.length > 1 ? 's' : ''}.` : '', String(job.prompt || '').trim()]
      .filter(Boolean).join('\n\n');
    const trigger = triggerFor(job.schedule);
    if (!prompt || !trigger) {
      skipped.push({ kind: 'Automation', name, reason: prompt ? 'its schedule could not be read' : 'it has no prompt' });
      continue;
    }
    if (trigger.mode === 'one_time' && Date.parse(trigger.runAt) < Date.now()) {
      skipped.push({ kind: 'Automation', name, reason: 'a one-time job whose time has passed' });
      continue;
    }
    const [platform, chat] = String(job.deliver || '').split(':');
    tasks.push({
      name,
      agentKey: key,
      prompt,
      trigger,
      enabled: job.enabled !== false && job.state !== 'paused',
      tz: null,
      notify: MESSAGING_PLATFORMS.has(platform) ? { platform, to: chat || null } : null,
      model: job.model ? modelId(modelOf({ default: job.model, provider: job.provider || 'auto' })) : null,
      note: trigger.note || null,
    });
  }
  return tasks;
}

function triggerFor(schedule = {}) {
  if (schedule.kind === 'cron' && schedule.expr) {
    const converted = toFiveFieldCron(schedule.expr);
    if (!converted) return null;
    return { mode: 'recurring', cronExpression: converted.cron, note: converted.exact ? null : 'sub-minute timing rounded to the minute' };
  }
  if (schedule.kind === 'interval' && schedule.minutes) {
    const converted = intervalToCron(Number(schedule.minutes) * 60000);
    return { mode: 'recurring', cronExpression: converted.cron, note: converted.exact ? null : `every ${schedule.minutes}m rounded to "${converted.cron}"` };
  }
  if (schedule.kind === 'once' && schedule.run_at) {
    const runAt = new Date(schedule.run_at);
    return Number.isNaN(runAt.getTime()) ? null : { mode: 'one_time', runAt: runAt.toISOString() };
  }
  return null;
}

function splitList(value) {
  return String(value || '').split(',').map((item) => item.trim()).filter((item) => item && item !== '*');
}

function collectChannels(env, skipped) {
  const channels = [];
  if (env.TELEGRAM_BOT_TOKEN) {
    channels.push({
      platform: 'telegram',
      config: { botToken: env.TELEGRAM_BOT_TOKEN },
      allow: [...new Set([...splitList(env.TELEGRAM_ALLOWED_USERS), ...splitList(env.TELEGRAM_HOME_CHANNEL)])],
    });
  }
  if (env.DISCORD_BOT_TOKEN) {
    channels.push({ platform: 'discord', config: { token: env.DISCORD_BOT_TOKEN }, allow: splitList(env.DISCORD_ALLOWED_USERS) });
  }
  if (env.WHATSAPP_ENABLED === 'true' || env.WHATSAPP_ALLOWED_USERS) {
    channels.push({ platform: 'whatsapp', config: null, allow: splitList(env.WHATSAPP_ALLOWED_USERS) });
    skipped.push({ kind: 'Channel', name: 'WhatsApp', reason: 'WhatsApp links to one app at a time; scan the QR code in NeoAgent (allowed numbers were kept)' });
  }
  if (env.SLACK_BOT_TOKEN) {
    skipped.push({ kind: 'Channel', name: 'Slack', reason: 'NeoAgent receives Slack events by webhook instead of socket mode; set it up under Integrations' });
  }
  for (const [envKey, name] of [['SIGNAL_ACCOUNT', 'Signal'], ['MATRIX_ACCESS_TOKEN', 'Matrix'], ['MATTERMOST_TOKEN', 'Mattermost'], ['EMAIL_ADDRESS', 'Email']]) {
    if (env[envKey]) skipped.push({ kind: 'Channel', name, reason: 'not supported by NeoAgent' });
  }
  return channels;
}

module.exports = {
  describeHome,
  findHermesHomes,
  scanHermes,
};
