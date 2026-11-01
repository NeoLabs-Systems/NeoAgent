'use strict';

// The importer's handles on NeoAgent itself: its services, accounts, task
// table and AI keys. Loaded by the CLI, outside the running server.

const { parseEnv } = require('../../runtime/env');
const { ENV_FILE, readEnvFileRaw } = require('../../runtime/paths');

// Values every install's .env starts with; an imported value replaces them.
const DEFAULT_ENV_VALUES = { OLLAMA_URL: 'http://localhost:11434' };

// The server reads its encryption key from .env at boot; the CLI has to do the
// same before any secret (channel tokens) is written, or the server could not
// read them back.
function openNeoAgent() {
  const env = parseEnv(readEnvFileRaw(ENV_FILE));
  for (const key of ['NEOAGENT_ENCRYPTION_KEY', 'SESSION_SECRET']) {
    if (!process.env[key] && env.get(key)) process.env[key] = env.get(key).trim();
  }
  return {
    db: require('../../server/db/database'),
    agents: require('../../server/services/agents/manager'),
    MemoryManager: require('../../server/services/memory/manager').MemoryManager,
    SkillRunner: require('../../server/services/ai/toolRunner').SkillRunner,
    prependNeoAgentNotes: require('../../server/services/skills/skills_sh').prependNeoAgentNotes,
    settings: require('../../server/services/settings/store'),
    schedule: require('../../server/services/tasks/adapters/schedule'),
    TaskRepository: require('../../server/services/tasks/task_repository').TaskRepository,
    accessPolicy: require('../../server/services/messaging/access_policy'),
    encryptValue: require('../../server/services/integrations/secrets').encryptValue,
    validateRemoteMcpEndpoint: require('../../server/services/runtime/mcp').validateRemoteMcpEndpoint,
    getUserTimeZone: require('../../server/services/account/timezone').getUserTimeZone,
    getAiSettings: require('../../server/services/ai/settings').getAiSettings,
  };
}

function listAccounts(ctx) {
  return ctx.db.prepare('SELECT id, username, is_admin FROM users ORDER BY id').all();
}

function insertTask(ctx, userId, { agentId, name, triggerConfig, taskConfig, enabled = true }) {
  return new ctx.TaskRepository().createTask(userId, {
    agentId,
    name,
    triggerType: 'schedule',
    triggerConfig,
    executionMode: 'prompt',
    taskType: 'agent_prompt',
    taskConfig,
    enabled,
    legacyCronExpression: triggerConfig.mode === 'recurring' ? triggerConfig.cronExpression : null,
    legacyRunAt: triggerConfig.mode === 'one_time' ? triggerConfig.runAt : null,
    legacyOneTime: triggerConfig.mode === 'one_time',
  });
}

// Whether any AI provider has what it needs to answer. Ollama counts only
// when pointed somewhere other than the default every install starts with.
function hasUsableAi() {
  const { AI_PROVIDER_DEFINITIONS } = require('../../server/services/ai/provider_definitions');
  const env = parseEnv(readEnvFileRaw(ENV_FILE));
  return Object.values(AI_PROVIDER_DEFINITIONS).some((definition) => (
    definition.envKey
      ? Boolean(String(env.get(definition.envKey) || '').trim())
      : String(env.get('OLLAMA_URL') || '').trim() && env.get('OLLAMA_URL').trim() !== DEFAULT_ENV_VALUES.OLLAMA_URL
  ));
}

function providerReady(model, env) {
  const { AI_PROVIDER_DEFINITIONS } = require('../../server/services/ai/provider_definitions');
  const definition = AI_PROVIDER_DEFINITIONS[model.split('::')[0]];
  if (!definition) return false;
  return !definition.envKey || Boolean(String(env.get(definition.envKey) || '').trim());
}

module.exports = {
  DEFAULT_ENV_VALUES,
  hasUsableAi,
  insertTask,
  listAccounts,
  openNeoAgent,
  providerReady,
};
