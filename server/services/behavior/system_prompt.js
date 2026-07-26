'use strict';

const { resolveBehaviorConfig, isModuleEnabled } = require('./config');
const { createBehaviorRegistry } = require('./registry');
const { BEHAVIOR_MODULES } = require('./modules');

async function buildBehaviorSystemPrompt({
  userId,
  agentId,
  triggerSource,
  context,
  memoryManager,
}) {
  const config = resolveBehaviorConfig(userId, agentId, {
    platform: context.source || null,
    chatId: context.chatId || null,
    isGroup: context.memoryAudience === 'shared' || context.socialIntelligence?.isGroup === true,
  });
  const ctx = {
    ...context,
    userId,
    agentId,
    triggerSource,
    audience: context.memoryAudience || 'owner',
    config,
    memoryManager,
  };
  const registry = createBehaviorRegistry(BEHAVIOR_MODULES);
  const results = await registry.run('composeSystemPrompt', {
    ...ctx,
    isModuleEnabled: (moduleId) => isModuleEnabled(config, moduleId),
  });
  const priorities = {
    channel_style: 100,
    persona: 80,
    agent_identity: 60,
  };
  const entries = [];
  for (const entry of results) {
    if (!entry.value) continue;
    const priority = priorities[entry.moduleId] || 0;
    if (typeof entry.value === 'string') {
      entries.push({
        moduleId: entry.moduleId,
        content: entry.value,
        section: entry.moduleId === 'channel_style' ? 'stable' : 'dynamic',
        priority,
      });
      continue;
    }
    for (const section of ['stable', 'dynamic']) {
      const values = Array.isArray(entry.value[section])
        ? entry.value[section]
        : [entry.value[section]];
      for (const content of values) {
        if (!content) continue;
        entries.push({
          moduleId: entry.moduleId,
          content,
          section,
          priority,
        });
      }
    }
  }
  entries.sort((left, right) => right.priority - left.priority);
  return {
    stable: entries.filter((entry) => entry.section === 'stable').map((entry) => entry.content),
    dynamic: entries.filter((entry) => entry.section === 'dynamic').map((entry) => entry.content),
  };
}

module.exports = {
  buildBehaviorSystemPrompt,
};
