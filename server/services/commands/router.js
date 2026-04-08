'use strict';

const db = require('../../db/database');
const { clearWebChatSummary } = require('../ai/history');
const { getAvailableTools } = require('../ai/tools');
const { getSupportedModels } = require('../ai/models');
const { resolveAgentId } = require('../agents/manager');

function tokenize(text) {
  return String(text || '').trim().split(/\s+/).filter(Boolean);
}

function asSource(source) {
  const normalized = String(source || 'web').toLowerCase();
  if (normalized === 'http') return 'http';
  if (normalized === 'messaging') return 'messaging';
  return 'web';
}

function parseCommand(input, source) {
  const raw = String(input || '').trim();
  if (!raw) return null;

  const actualSource = asSource(source);
  const isMessaging = actualSource === 'messaging';
  const prefixPattern = isMessaging ? /^([/!])(\S+)/ : /^(\/)(\S+)/;
  const match = raw.match(prefixPattern);
  if (!match) return null;

  const tokens = tokenize(raw);
  const head = tokens[0] || '';
  const command = head.slice(1).toLowerCase();
  const args = tokens.slice(1);

  if (!command) return null;
  return {
    command,
    args,
    raw,
    source: actualSource,
    prefix: head[0]
  };
}

class CommandRouter {
  constructor(app) {
    this.app = app;
    this.aliases = new Map([
      ['new', 'clear'],
      ['clear', 'clear'],
      ['stop', 'stop'],
      ['help', 'help'],
      ['status', 'status'],
      ['tools', 'tools'],
      ['memory', 'memory'],
      ['tasks', 'tasks'],
      ['models', 'models'],
      ['skills', 'skills']
    ]);
  }

  resolveCommand(name) {
    return this.aliases.get(String(name || '').toLowerCase()) || null;
  }

  async dispatch(input, context = {}) {
    const parsed = parseCommand(input, context.source);
    if (!parsed) return { handled: false };

    const resolved = this.resolveCommand(parsed.command);
    if (!resolved) {
      if (parsed.source === 'messaging') return { handled: false };
      return {
        handled: true,
        content: `Unknown command: \`/${parsed.command}\`. Type \`/help\` for available commands.`,
      };
    }

    const userId = context.userId;
    if (!userId) {
      return {
        handled: true,
        content: 'Cannot run command: missing user context.'
      };
    }

    const agentId = resolveAgentId(userId, context.agentId || context.agent_id || null);

    switch (resolved) {
      case 'clear':
        return await this.handleClear(userId, parsed, { ...context, agentId });
      case 'stop':
        return this.handleStop(userId, agentId);
      case 'help':
        return this.handleHelp();
      case 'status':
        return this.handleStatus(userId, agentId);
      case 'tools':
        return this.handleTools(userId, agentId);
      case 'memory':
        return this.handleMemory(userId, agentId);
      case 'tasks':
        return this.handleTasks(userId, parsed.args, agentId);
      case 'models':
        return await this.handleModels(userId, agentId);
      case 'skills':
        return this.handleSkills();
      default:
        return { handled: false };
    }
  }

  async handleClear(userId, parsed, context) {
    const source = parsed.source;
    const agentId = resolveAgentId(userId, context.agentId || context.agent_id || null);
    const events = [{ name: 'chat:cleared', payload: {} }];

    if (source === 'messaging') {
      const platform = String(context.platform || '').trim();
      const chatId = String(context.chatId || '').trim();
      if (platform && chatId) {
        const conversation = db
          .prepare('SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id = ?')
          .get(userId, agentId, platform, chatId);
        if (conversation?.id) {
          db.prepare('DELETE FROM conversations WHERE id = ?').run(conversation.id);
        }
      }
      return {
        handled: true,
        content: 'Context cleared for this chat. Fresh start.',
        events,
        metadata: {
          source,
          platform: context.platform || null,
          chatId: context.chatId || null
        }
      };
    }

    db.prepare('DELETE FROM conversation_history WHERE user_id = ? AND agent_id = ?').run(userId, agentId);
    clearWebChatSummary(userId, { agentId });

    const agentEngine = this.app?.locals?.agentEngine;

    if (source === 'web' && agentEngine) {
      try {
        const resetResult = await agentEngine.run(
          userId,
          'context was just cleared. say something very brief (1-2 sentences max) acknowledging the fresh start, in your own style. no tools needed.',
          { agentId }
        );
        return {
          handled: true,
          content: resetResult?.content || 'fresh start.',
          events
        };
      } catch (err) {
        return {
          handled: true,
          content: 'Context cleared. Fresh start.',
          events,
          error: err.message
        };
      }
    }

    return {
      handled: true,
      content: 'Context cleared. Fresh start.',
      events,
      metadata: {
        source,
        platform: context.platform || null
      }
    };
  }

  handleStop(userId, agentId = null) {
    const agentEngine = this.app?.locals?.agentEngine;
    if (agentEngine) {
      for (const [runId, run] of agentEngine.activeRuns?.entries?.() || []) {
        if (run.userId === userId && (!agentId || run.agentId === agentId)) {
          agentEngine.stopRun(runId);
        }
      }
    }

    const q = this.app?.locals?.userQueues;
    const queueKeys = agentId ? [`${userId}:${agentId}`, userId] : [userId];
    for (const key of queueKeys) {
      if (q && q[key]) {
        q[key].cancelRequested = true;
        if (!q[key].running) {
          q[key].pending = [];
          q[key].cancelRequested = false;
        }
      }
    }

    return {
      handled: true,
      content: 'Stopped.'
    };
  }

  handleHelp() {
    return {
      handled: true,
      content:
        '**Available commands**\n' +
        '- `/new` or `/clear` - clear conversation context\n' +
        '- `/stop` - abort active runs and clear pending queue\n' +
        '- `/status` - show current run/queue status\n' +
        '- `/tools` - list available built-in tools\n' +
        '- `/memory` - quick memory summary\n' +
        '- `/tasks` - list latest tasks and scheduled jobs\n' +
        '- `/models` - list currently available models\n' +
        '- `/skills` - list enabled skills\n' +
        '- `/help` - show this message\n\n' +
        'Messaging also accepts `!command` aliases (for example `!stop`).'
    };
  }

  handleStatus(userId, agentId = null) {
    const agentEngine = this.app?.locals?.agentEngine;
    const activeRuns = Array.from(agentEngine?.activeRuns?.values?.() || [])
      .filter((run) => run.userId === userId && (!agentId || run.agentId === agentId));
    const queue = this.app?.locals?.userQueues?.[`${userId}:${agentId || 'main'}`]
      || this.app?.locals?.userQueues?.[userId]
      || { running: false, pending: [] };
    const connectedPlatforms = this.app?.locals?.messagingManager?.getAllStatuses(userId, { agentId }) || {};
    const connectedCount = Object.values(connectedPlatforms).filter((entry) => String(entry?.status || '').toLowerCase() === 'connected').length;

    return {
      handled: true,
      content:
        `**Status**\n` +
        `- Active runs: ${activeRuns.length}\n` +
        `- Messaging queue: ${queue.running ? 'running' : 'idle'} (${Array.isArray(queue.pending) ? queue.pending.length : 0} pending)\n` +
        `- Connected messaging platforms: ${connectedCount}`
    };
  }

  handleTools(userId, agentId = null) {
    const tools = getAvailableTools(this.app, {
      includeDescriptions: false,
      userId,
      agentId,
    }) || [];
    const names = tools.map((tool) => tool.name).sort();
    const preview = names.slice(0, 30);
    const extra = names.length > preview.length ? `\n- ...and ${names.length - preview.length} more` : '';
    return {
      handled: true,
      content: `**Tools (${names.length})**\n- ${preview.join('\n- ')}${extra}`
    };
  }

  handleMemory(userId, agentId = null) {
    const episodicCount = db
      .prepare('SELECT COUNT(*) AS count FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0')
      .get(userId, agentId)?.count || 0;
    const coreCount = db
      .prepare('SELECT COUNT(*) AS count FROM core_memory WHERE user_id = ? AND agent_id = ?')
      .get(userId, agentId)?.count || 0;

    const latest = db
      .prepare('SELECT category, content, updated_at FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0 ORDER BY updated_at DESC LIMIT 1')
      .get(userId, agentId);

    const latestPreview = latest?.content
      ? String(latest.content).replace(/\s+/g, ' ').trim().slice(0, 140)
      : null;

    return {
      handled: true,
      content:
        `**Memory**\n` +
        `- Episodic entries: ${episodicCount}\n` +
        `- Core memory keys: ${coreCount}` +
        (latestPreview ? `\n- Latest: ${latest.category || 'episodic'} - ${latestPreview}` : '')
    };
  }

  handleTasks(userId, args = [], agentId = null) {
    const mode = String(args[0] || 'recent').toLowerCase();

    if (mode === 'scheduled') {
      const scheduled = db
        .prepare('SELECT id, name, enabled, cron_expression, run_at, one_time, last_run FROM scheduled_tasks WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC')
        .all(userId, agentId);
      if (!scheduled.length) {
        return { handled: true, content: '**Tasks**\n- No scheduled tasks found.' };
      }
      const lines = scheduled.map((task) => {
        const scheduleLabel = task.one_time ? `one-time at ${task.run_at || 'unknown'}` : (task.cron_expression || 'unspecified');
        return `- #${task.id} ${task.name} [${task.enabled ? 'enabled' : 'disabled'}] - ${scheduleLabel}`;
      });
      return {
        handled: true,
        content: `**Scheduled Tasks (${scheduled.length})**\n${lines.join('\n')}`
      };
    }

    const runs = db
      .prepare('SELECT id, title, status, trigger_source, created_at, updated_at FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT 8')
      .all(userId, agentId);
    if (!runs.length) {
      return {
        handled: true,
        content: '**Tasks**\n- No runs yet.'
      };
    }
    const lines = runs.map((run) => {
      const shortId = String(run.id || '').slice(0, 8);
      return `- ${shortId} [${run.status}] ${run.title || 'Untitled'} (${run.trigger_source || 'web'})`;
    });
    return {
      handled: true,
      content: `**Recent Tasks (${runs.length})**\n${lines.join('\n')}\n\nTip: use \`/tasks scheduled\` to view cron/one-time tasks.`
    };
  }

  async handleModels(userId, agentId = null) {
    const models = await getSupportedModels(userId, agentId);
    const available = models.filter((model) => model.available !== false);
    if (!available.length) {
      return {
        handled: true,
        content: '**Models**\n- No models are currently available. Check provider settings.'
      };
    }

    const lines = available.slice(0, 20).map((model) => {
      return `- ${model.id} (${model.provider}, ${model.purpose || 'general'})`;
    });
    const extra = available.length > 20 ? `\n- ...and ${available.length - 20} more` : '';
    return {
      handled: true,
      content: `**Models (${available.length})**\n${lines.join('\n')}${extra}`
    };
  }

  handleSkills() {
    const skillRunner = this.app?.locals?.skillRunner;
    const skills = skillRunner?.getAll?.() || [];
    const enabled = skills.filter((skill) => skill.enabled !== false);
    if (!enabled.length) {
      return {
        handled: true,
        content: '**Skills**\n- No enabled skills found.'
      };
    }

    const lines = enabled.slice(0, 20).map((skill) => `- ${skill.name}`);
    const extra = enabled.length > 20 ? `\n- ...and ${enabled.length - 20} more` : '';
    return {
      handled: true,
      content: `**Skills (${enabled.length})**\n${lines.join('\n')}${extra}`
    };
  }
}

module.exports = {
  CommandRouter,
  parseCommand,
};
