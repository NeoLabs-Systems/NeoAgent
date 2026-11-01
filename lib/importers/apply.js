'use strict';

// Writes a scanned bundle into NeoAgent. A bundle (from openclaw.js or
// hermes.js) is plain data:
//
//   agents   [{ key, name, isDefault, instructions, memories: [{ text, category }],
//              userProfile, dailyLogs: [{ date, content }], model }]
//   skills   [{ name, description, body, dir, files }]
//   keys     { NEOAGENT_ENV_KEY: value }
//   model    "provider::model" | null
//   mcp      [{ name, url, token, headers, transport, enabled }]
//   tasks    [{ name, agentKey, prompt, trigger, enabled, notify, model, note }]
//   channels [{ platform, config | null, allow: [ids] }]
//   timezone, skipped [{ kind, name, reason }]
//
// Every step is safe to repeat: things already in NeoAgent are left alone and
// reported as such, so running the import twice changes nothing.

const fs = require('fs');
const path = require('path');
const { parseEnv } = require('../../runtime/env');
const { AGENT_DATA_DIR, ENV_FILE, readEnvFileRaw, upsertEnvValue } = require('../../runtime/paths');
const { PLATFORM_LABELS } = require('./common');
const { DEFAULT_ENV_VALUES, insertTask, providerReady } = require('./neoagent');
const { toShortFacts } = require('./memory_text');

// agents.instructions is shown to the model up to this length; anything
// longer goes to the agent's behaviour notes, which are not cut.
const MAX_INSTRUCTIONS_CHARS = 1600;
const MAX_CORE_PROFILE_CHARS = 1000;

// One importer run: shared services, the account, and which NeoAgent agent
// each source agent landed in.
class ImportSession {
  // entries: lines already recorded, such as keys setup imported earlier.
  constructor(ctx, userId, entries = []) {
    this.ctx = ctx;
    this.userId = userId;
    this.entries = [...entries];
    this.agentIds = new Map();
    this.mainClaimed = false;
    this.memory = null;
    this.skillRunner = null;
  }

  // count: how many items one line stands for (a line of 8 memories).
  record(kind, status, name, detail = '', count = 1) {
    this.entries.push({ kind, status, name, detail, count });
  }

  async applyBundle(bundle, onStep = () => {}, { keysDone = false } = {}) {
    const steps = [
      ...(keysDone ? [] : [['Keys and AI providers', () => this.applyKeys(bundle)]]),
      ['Agents and personality', () => this.applyAgents(bundle)],
      ['Memories', () => this.applyMemories(bundle)],
      ['Skills', () => this.applySkills(bundle)],
      ['Default model', () => this.applyModel(bundle)],
      ['MCP servers', () => this.applyMcp(bundle)],
      ['Automations', () => this.applyTasks(bundle)],
      ['Messaging channels', () => this.applyChannels(bundle)],
    ];
    for (const [label, run] of steps) {
      await onStep(label, async () => {
        try {
          await run();
        } catch (error) {
          this.record(label, 'failed', bundle.label, error.message);
        }
      });
    }
    for (const item of bundle.skipped) this.record(item.kind, 'skipped', item.name, item.reason);
  }

  applyKeys(bundle) {
    const current = parseEnv(readEnvFileRaw(ENV_FILE));
    for (const [key, value] of Object.entries(bundle.keys)) {
      const stored = String(current.get(key) || '').trim();
      const existing = stored === DEFAULT_ENV_VALUES[key] ? '' : stored;
      if (existing === value) {
        this.record('Key', 'exists', key);
      } else if (existing) {
        this.record('Key', 'exists', key, `kept the value NeoAgent already had (${bundle.label} has a different one)`);
      } else {
        upsertEnvValue(ENV_FILE, key, value);
        this.record('Key', 'imported', key);
      }
    }
    for (const key of bundle.ignoredKeys) {
      this.record('Key', 'skipped', key, 'NeoAgent does not use this service');
    }
  }

  // The source's default agent becomes NeoAgent's main agent. When main
  // already has instructions (yours, or another source's), the source agent
  // is added beside it instead, so no personality is overwritten.
  applyAgents(bundle) {
    const { agents } = this.ctx;
    const main = agents.ensureMainAgent(this.userId);
    for (const source of bundle.agents) {
      if (source.isDefault && source.instructions && this.holdsInstructions(main, source.instructions)) {
        this.mainClaimed = true;
        this.agentIds.set(agentRef(bundle, source), main.id);
        this.record('Agent', 'exists', `${source.name} → main agent`);
        continue;
      }
      if (source.isDefault && !String(main.instructions || '').trim() && !this.mainClaimed) {
        this.mainClaimed = true;
        this.agentIds.set(agentRef(bundle, source), main.id);
        if (source.instructions) {
          this.writeInstructions(main.id, source.instructions, { name: 'main' });
          this.record('Agent', 'imported', `${source.name} → main agent`, 'personality and instructions');
        }
        continue;
      }
      if (source.isDefault && !source.instructions) {
        this.agentIds.set(agentRef(bundle, source), main.id);
        continue;
      }
      const slug = slugFor(source.name === 'Hermes' ? 'hermes' : source.name || source.key);
      const existing = agents.getAgentBySlug(this.userId, slug);
      if (existing) {
        this.agentIds.set(agentRef(bundle, source), existing.id);
        this.record('Agent', 'exists', existing.display_name);
        continue;
      }
      const created = agents.createAgent(this.userId, {
        slug,
        displayName: source.name,
        description: `Imported from ${bundle.label}`,
        instructions: '',
      });
      this.agentIds.set(agentRef(bundle, source), created.id);
      if (source.instructions) this.writeInstructions(created.id, source.instructions, created);
      this.record('Agent', 'imported', source.name, `new agent "${slug}"`);
    }
  }

  // A repeat run finds the text it wrote last time, in either place.
  holdsInstructions(agent, text) {
    if (String(agent.instructions || '').trim() === text.trim()) return true;
    return this.memoryManager().getAssistantBehaviorNotes(this.userId, { agentId: agent.id }).trim() === text.trim();
  }

  writeInstructions(agentId, text, agent) {
    if (text.length <= MAX_INSTRUCTIONS_CHARS) {
      this.ctx.agents.updateAgent(this.userId, agentId, { instructions: text });
      return;
    }
    this.memoryManager().setAssistantBehaviorNotes(this.userId, text, { agentId });
    this.record('Agent', 'imported', agent.name || 'agent', 'long personality saved as behaviour notes');
  }

  agentIdFor(bundle, key) {
    const source = bundle.agents.find((agent) => agent.key === key) || bundle.agents.find((agent) => agent.isDefault);
    return this.agentIds.get(agentRef(bundle, source)) || null;
  }

  memoryManager() {
    if (!this.memory) this.memory = new this.ctx.MemoryManager();
    return this.memory;
  }

  async applyMemories(bundle) {
    const memory = this.memoryManager();
    for (const source of bundle.agents) {
      const agentId = this.agentIdFor(bundle, source.key);
      const sourceRef = { sourceType: 'import', sourceId: `${bundle.source}:${source.key}`, sourceLabel: `${bundle.label} import` };
      let saved = 0;
      let known = 0;
      const facts = source.memories.flatMap((item) => toShortFacts(item.text).map((text) => ({ text, category: item.category })));

      if (source.userProfile) {
        const current = memory.getCoreMemory(this.userId, { agentId }).user_profile;
        if (current === source.userProfile) {
          this.record('Memory', 'exists', `${source.name}: about you`);
        } else if (!current && source.userProfile.length <= MAX_CORE_PROFILE_CHARS) {
          memory.updateCore(this.userId, 'user_profile', source.userProfile, { agentId });
          this.record('Memory', 'imported', `${source.name}: about you`, 'saved to core memory');
        } else {
          facts.push(...source.userProfile.split('\n').flatMap((line) => toShortFacts(line)).map((text) => ({ text, category: 'identity' })));
        }
      }

      for (const fact of facts) {
        const before = this.countMemories(agentId);
        const result = await memory.saveMemory(this.userId, fact.text, fact.category, 6, { agentId, sourceRef });
        if (result && this.countMemories(agentId) > before) saved += 1;
        else known += 1;
      }
      if (saved) this.record('Memory', 'imported', `${source.name}: ${saved} memor${saved === 1 ? 'y' : 'ies'}`, '', saved);
      if (known) this.record('Memory', 'exists', `${source.name}: ${known} already known`, '', known);

      if (source.isDefault && source.dailyLogs.length) this.writeDailyLogs(source.dailyLogs, source.name);
    }
  }

  countMemories(agentId) {
    return this.ctx.db.prepare('SELECT COUNT(*) AS count FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0')
      .get(this.userId, agentId).count;
  }

  // Daily notes map one to one onto NeoAgent's daily logs (YYYY-MM-DD.md).
  writeDailyLogs(logs, agentName) {
    const dir = path.join(AGENT_DATA_DIR, 'users', String(this.userId), 'daily');
    fs.mkdirSync(dir, { recursive: true });
    let written = 0;
    for (const log of logs) {
      const file = path.join(dir, `${log.date}.md`);
      const existing = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
      if (existing.includes(log.content)) continue;
      fs.writeFileSync(file, existing ? `${existing.trimEnd()}\n\n${log.content}\n` : `${log.content}\n`);
      written += 1;
    }
    this.record('Daily notes', written ? 'imported' : 'exists', agentName, `${logs.length} day${logs.length === 1 ? '' : 's'}`, written || logs.length);
  }

  async applySkills(bundle) {
    if (!bundle.skills.length) return;
    if (!this.skillRunner) {
      this.skillRunner = new this.ctx.SkillRunner();
      await this.skillRunner.loadSkills();
    }
    for (const skill of bundle.skills) {
      const result = this.skillRunner.createSkill(
        this.userId,
        skill.name,
        skill.description,
        this.ctx.prependNeoAgentNotes(skill.body),
        { source: bundle.source, imported_from: skill.dir },
      );
      if (result.error) {
        this.record('Skill', /already exists/.test(result.error) ? 'exists' : 'failed', skill.name, /already exists/.test(result.error) ? '' : result.error);
        continue;
      }
      const root = path.dirname(result.path);
      for (const relative of skill.files) {
        const target = path.resolve(root, relative);
        if (!target.startsWith(`${root}${path.sep}`)) continue;
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.copyFileSync(path.join(skill.dir, relative), target);
      }
      this.record('Skill', 'imported', skill.name, skill.files.length ? `with ${skill.files.length} file${skill.files.length === 1 ? '' : 's'}` : '');
    }
  }

  // Only fills an unset ("auto") model, and only with a provider NeoAgent has
  // a key for, so an import never points chat at a model that cannot answer.
  applyModel(bundle) {
    const targets = [
      [bundle.model, bundle.agents.find((agent) => agent.isDefault)],
      ...bundle.agents.filter((agent) => !agent.isDefault && agent.model).map((agent) => [agent.model, agent]),
    ];
    const env = parseEnv(readEnvFileRaw(ENV_FILE));
    for (const [model, source] of targets) {
      if (!model || !source) continue;
      const agentId = this.agentIdFor(bundle, source.key);
      const current = this.ctx.getAiSettings(this.userId, agentId).default_chat_model;
      if (current && current !== 'auto') {
        this.record('Model', 'exists', source.name, current === model ? '' : `kept ${current}`);
        continue;
      }
      if (!providerReady(model, env)) {
        this.record('Model', 'skipped', model, 'no key for this provider was found');
        continue;
      }
      const result = this.ctx.settings.applySettingsUpdate({
        userId: this.userId,
        agentId,
        patch: { default_chat_model: model },
        source: 'import',
      });
      this.record('Model', result.ok ? 'imported' : 'failed', `${source.name}: ${model}`, result.ok ? '' : (result.error || 'not accepted'));
    }
  }

  applyMcp(bundle) {
    const agentId = this.agentIdFor(bundle, bundle.agents.find((agent) => agent.isDefault)?.key);
    for (const server of bundle.mcp) {
      const exists = this.ctx.db.prepare('SELECT id FROM mcp_servers WHERE user_id = ? AND name = ?').get(this.userId, server.name);
      if (exists) {
        this.record('MCP server', 'exists', server.name);
        continue;
      }
      const config = { transport: server.transport };
      if (server.token) config.auth = { type: 'bearer', token: server.token };
      if (Object.keys(server.headers).length) config.headers = server.headers;
      this.ctx.db.prepare('INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?, ?)')
        .run(this.userId, agentId, server.name, this.ctx.validateRemoteMcpEndpoint(server.url), JSON.stringify(config), server.enabled ? 1 : 0);
      this.record('MCP server', 'imported', server.name, server.enabled ? '' : 'kept switched off');
    }
  }

  async applyTasks(bundle) {
    this.applyTimezone(bundle);
    for (const task of bundle.tasks) {
      const agentId = this.agentIdFor(bundle, task.agentKey);
      const exists = this.ctx.db.prepare('SELECT id FROM scheduled_tasks WHERE user_id = ? AND agent_id IS ? AND name = ?').get(this.userId, agentId, task.name);
      if (exists) {
        this.record('Automation', 'exists', task.name);
        continue;
      }
      const triggerConfig = await this.ctx.schedule.validateConfig(task.trigger, { userId: this.userId, agentId });
      const taskConfig = { prompt: task.prompt };
      if (task.model) taskConfig.model = task.model;
      if (task.notify) {
        taskConfig.notifyPlatform = task.notify.platform;
        if (task.notify.to) taskConfig.notifyTo = task.notify.to;
      }
      insertTask(this.ctx, this.userId, { agentId, name: task.name, triggerConfig, taskConfig, enabled: task.enabled });
      const notes = [task.enabled ? '' : 'paused', task.note || ''].filter(Boolean).join('; ');
      this.record('Automation', 'imported', task.name, notes);
    }
  }

  // Schedules are read in the account's timezone; take the source's when
  // NeoAgent has none yet.
  applyTimezone(bundle) {
    if (!bundle.timezone) return;
    const current = this.ctx.getUserTimeZone(this.userId);
    if (current) {
      if (current !== bundle.timezone && bundle.tasks.length) {
        this.record('Automation', 'skipped', 'timezone', `schedules now run in ${current}; ${bundle.label} used ${bundle.timezone}`);
      }
      return;
    }
    const result = this.ctx.settings.applySettingsUpdate({ userId: this.userId, agentId: null, patch: { timezone: bundle.timezone }, source: 'import' });
    if (result.ok) this.record('Setting', 'imported', 'timezone', bundle.timezone);
  }

  // Connections are stored the way the server stores them and come online at
  // its next start; allowlists become NeoAgent access policies.
  applyChannels(bundle) {
    const agentId = this.agentIdFor(bundle, bundle.agents.find((agent) => agent.isDefault)?.key);
    const { accessPolicy, db, encryptValue } = this.ctx;
    for (const channel of bundle.channels) {
      const label = PLATFORM_LABELS[channel.platform];
      if (channel.config) {
        const exists = db.prepare('SELECT id FROM platform_connections WHERE user_id = ? AND agent_id IS ? AND platform = ?').get(this.userId, agentId, channel.platform);
        if (exists) {
          this.record('Channel', 'exists', label);
          continue;
        }
        db.prepare('INSERT INTO platform_connections (user_id, agent_id, platform, config, status) VALUES (?, ?, ?, ?, ?)')
          .run(this.userId, agentId, channel.platform, encryptValue(JSON.stringify({ ...channel.config, autoConnect: true })), 'connecting');
        this.record('Channel', 'imported', label, 'connects when NeoAgent restarts');
      }
      const usable = channel.allow.filter((entry) => !(channel.platform === 'telegram' && entry.startsWith('@')));
      for (const entry of channel.allow.filter((value) => !usable.includes(value))) {
        this.record('Channel', 'skipped', `${label} ${entry}`, 'usernames cannot be allowed; add the numeric user id');
      }
      if (!usable.length) continue;
      const key = accessPolicy.accessPolicyKey(channel.platform);
      const exists = db.prepare('SELECT 1 FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?').get(this.userId, agentId, key);
      if (exists) {
        this.record('Channel', 'exists', `${label} allowlist`);
        continue;
      }
      const policy = accessPolicy.normalizeAccessPolicy(channel.platform, accessPolicy.migrateLegacyWhitelist(channel.platform, usable));
      db.prepare(`INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)
        ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`)
        .run(this.userId, agentId, key, JSON.stringify(policy));
      this.record('Channel', 'imported', `${label} allowlist`, `${usable.length} allowed`);
    }
  }
}

function agentRef(bundle, source) {
  return `${bundle.source}:${bundle.home}:${source?.key}`;
}

function slugFor(value) {
  return String(value || 'agent').toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'agent';
}

module.exports = {
  ImportSession,
};
