const db = require('../../db/database');
const { getProviderHealthCatalog } = require('./models');

function capabilityEntry(overrides = {}) {
  return {
    connected: false,
    configured: false,
    healthy: false,
    degraded: false,
    safe: true,
    summary: '',
    details: {},
    ...overrides,
  };
}

function summarizeCapabilityHealth(health) {
  const lines = [];
  for (const [name, entry] of Object.entries(health.capabilities || {})) {
    const state = entry.healthy
      ? (entry.degraded ? 'degraded' : 'healthy')
      : (entry.configured ? 'unhealthy' : 'unconfigured');
    const detail = entry.summary ? ` - ${entry.summary}` : '';
    lines.push(`${name}: ${state}${detail}`);
  }

  if (Array.isArray(health.providers) && health.providers.length > 0) {
    const providerLine = health.providers
      .map((provider) => `${provider.id}:${provider.healthy ? 'healthy' : provider.configured ? 'unhealthy' : 'unconfigured'}`)
      .join(', ');
    lines.push(`providers: ${providerLine}`);
  }

  return lines.join('\n');
}

async function getBrowserHealth(userId, app, engine, deviceTarget = null) {
  const runtimeManager = app?.locals?.runtimeManager || engine?.runtimeManager || null;
  if (!runtimeManager) {
    return capabilityEntry({
      summary: 'Cloud computer runtime is not available in this environment.',
    });
  }

  const snapshot = typeof runtimeManager.getCapabilitySnapshot === 'function'
    ? runtimeManager.getCapabilitySnapshot(userId, { deviceTarget })
    : null;
  const computer = snapshot?.computer || {};
  const state = String(computer.state || 'stopped');
  const active = ['starting', 'ready', 'agent_control', 'user_control', 'teaching'].includes(state);
  const healthy = state !== 'error';

  return capabilityEntry({
    connected: active,
    configured: true,
    healthy,
    degraded: false,
    summary: state === 'error'
      ? String(computer.error || 'Cloud computer failed to start.')
      : active
        ? 'The unified cloud computer is available.'
        : 'The unified cloud computer will start on first use.',
    details: {
      backend: snapshot?.browser?.activeBackend || 'cloud-computer',
      state,
      runtimeInitialized: snapshot?.browser?.vmInitialized === true,
    },
  });
}

async function getAndroidHealth(userId, app, engine, deviceTarget = null) {
  const runtimeManager = app?.locals?.runtimeManager || engine?.runtimeManager || null;
  if (!runtimeManager) {
    return capabilityEntry({
      summary: 'Android runtime is not available in this environment.',
    });
  }

  // Like browser health, Android health is a snapshot. Creating a controller or
  // running adb here makes unrelated chat turns pay runtime startup/status costs.
  const runtimeSnapshot = typeof runtimeManager.getCapabilitySnapshot === 'function'
    ? runtimeManager.getCapabilitySnapshot(userId, { deviceTarget })
    : null;
  const status = runtimeSnapshot?.android?.status || null;
  const bootstrapped = status?.bootstrapped === true;
  const starting = status?.starting === true;
  const lastStartError = String(status?.lastStartError || '').trim();
  return capabilityEntry({
    connected: bootstrapped,
    configured: true,
    healthy: !lastStartError,
    degraded: Boolean(lastStartError),
    summary: lastStartError
      ? `Android tooling reported: ${lastStartError}`
      : bootstrapped
        ? 'Android environment is ready.'
        : starting
          ? 'Android environment is starting.'
          : 'Android runtime is available and will initialize on first use.',
    details: status || {
      initialized: runtimeSnapshot?.android?.initialized === true,
      bootstrapped: false,
      starting: false,
    },
  });
}

function getMessagingHealth(userId, app, engine, agentId = null) {
  const manager = app?.locals?.messagingManager || engine?.messagingManager;
  if (!manager || typeof manager.getAllStatuses !== 'function') {
    return capabilityEntry({
      summary: 'Messaging manager is not available.',
    });
  }

  const statuses = manager.getAllStatuses(userId, { agentId }) || {};
  const entries = Object.entries(statuses);
  const connectedCount = entries.filter(([, value]) => value?.status === 'connected').length;

  return capabilityEntry({
    connected: connectedCount > 0,
    configured: entries.length > 0,
    healthy: entries.length > 0 ? connectedCount > 0 : false,
    degraded: entries.some(([, value]) => ['error', 'disconnected'].includes(String(value?.status || '').toLowerCase())),
    summary: entries.length === 0
      ? 'No messaging platforms are configured.'
      : `${connectedCount}/${entries.length} messaging platforms are connected.`,
    details: statuses,
  });
}

function getSearchHealth() {
  const configured = Boolean(String(process.env.BRAVE_SEARCH_API_KEY || '').trim());
  return capabilityEntry({
    connected: configured,
    configured,
    healthy: configured,
    summary: configured
      ? 'Brave Search API is configured.'
      : 'Brave Search API key is not configured.',
  });
}

function getMcpHealth(userId, app, engine, agentId = null) {
  const client = app?.locals?.mcpClient || app?.locals?.mcpManager || engine?.mcpManager;
  if (!client || typeof client.getStatus !== 'function') {
    return capabilityEntry({
      summary: 'MCP manager is not available.',
    });
  }

  const statuses = client.getStatus(userId, { agentId }) || {};
  const entries = Object.values(statuses);
  const runningCount = entries.filter((entry) => entry?.status === 'running').length;
  return capabilityEntry({
    connected: runningCount > 0,
    configured: entries.length > 0,
    healthy: entries.length > 0 ? runningCount > 0 : true,
    degraded: entries.some((entry) => entry?.status && entry.status !== 'running'),
    summary: entries.length === 0
      ? 'No MCP servers are configured.'
      : `${runningCount}/${entries.length} MCP servers are running.`,
    details: statuses,
  });
}

function getIntegrationHealth(userId, app, agentId = null) {
  const manager = app?.locals?.integrationManager;
  if (!manager || typeof manager.listProviders !== 'function') {
    return capabilityEntry({
      summary: 'Official integration manager is not available.',
    });
  }

  const providers = manager.listProviders(userId, agentId) || [];
  const connectedCount = providers.filter((provider) => provider.connection?.connected).length;
  const providerSummary = providers
    .map((provider) => {
      const label = provider?.label || provider?.id || 'Integration';
      if (!provider?.env?.configured) {
        return `${label}: unconfigured on this server`;
      }
      if (Array.isArray(provider?.apps) && provider.apps.length > 0) {
        const connectedApps = provider.apps.filter((appSnapshot) => appSnapshot?.connection?.connected).length;
        return `${label}: ${connectedApps}/${provider.apps.length} apps connected on this server`;
      }
      return provider?.connection?.connected
        ? `${label}: connected on this server`
        : `${label}: not connected on this server`;
    })
    .join('; ');
  return capabilityEntry({
    connected: connectedCount > 0,
    configured: providers.some((provider) => provider.env?.configured),
    healthy: providers.length > 0 ? connectedCount > 0 : false,
    degraded: providers.some((provider) => provider.connection?.status === 'env_not_configured'),
    summary: providers.length === 0
      ? 'No official integrations are available.'
      : providerSummary,
    details: { providers },
  });
}

function getSkillHealth(app, engine) {
  const runner = app?.locals?.skillRunner || engine?.skillRunner;
  const skills = typeof runner?.getAll === 'function' ? runner.getAll() : [];
  return capabilityEntry({
    connected: skills.length > 0,
    configured: Boolean(runner),
    healthy: Boolean(runner),
    summary: runner
      ? `${skills.length} reusable skills are loaded.`
      : 'Skill runner is not available.',
    details: { count: skills.length },
  });
}

function getFileHealth(app, engine) {
  const workspaceManager = app?.locals?.workspaceManager || engine?.workspaceManager || null;
  return capabilityEntry({
    connected: Boolean(workspaceManager),
    configured: Boolean(workspaceManager),
    healthy: Boolean(workspaceManager),
    summary: workspaceManager
      ? 'Per-user workspace access is available.'
      : 'Per-user workspace service is not available.',
  });
}

function getCommandHealth(userId, app, engine) {
  const runtimeManager = app?.locals?.runtimeManager || engine?.runtimeManager || null;
  return capabilityEntry({
    connected: Boolean(runtimeManager),
    configured: Boolean(runtimeManager),
    healthy: Boolean(runtimeManager),
    summary: runtimeManager
      ? 'Shell command execution is available.'
      : 'Shell command execution is not available in this environment.',
  });
}

function getMemoryHealth(engine) {
  return capabilityEntry({
    connected: Boolean(engine?.memoryManager),
    configured: Boolean(engine?.memoryManager),
    healthy: Boolean(engine?.memoryManager),
    summary: engine?.memoryManager
      ? 'Conversation and long-term memory are available.'
      : 'Memory manager is not available.',
  });
}

function getTaskHealth(userId, agentId = null) {
  const taskCount = agentId
    ? db.prepare('SELECT COUNT(*) AS count FROM scheduled_tasks WHERE user_id = ? AND agent_id = ?').get(userId, agentId)?.count || 0
    : db.prepare('SELECT COUNT(*) AS count FROM scheduled_tasks WHERE user_id = ?').get(userId)?.count || 0;
  return capabilityEntry({
    connected: taskCount > 0,
    configured: true,
    healthy: true,
    summary: taskCount > 0
      ? `${taskCount} task(s) exist for this user.`
      : 'No tasks are configured.',
    details: { taskCount },
  });
}

async function getCapabilityHealth({ userId, agentId = null, app, engine, deviceTarget = null }) {
  const providers = await getProviderHealthCatalog(userId, agentId, {
    probeLocal: false,
  });

  return {
    providers,
    capabilities: {
      command: getCommandHealth(userId, app, engine),
      files: getFileHealth(app, engine),
      memory: getMemoryHealth(engine),
      search: getSearchHealth(),
      browser: await getBrowserHealth(userId, app, engine, deviceTarget),
      android: await getAndroidHealth(userId, app, engine, deviceTarget),
      messaging: getMessagingHealth(userId, app, engine, agentId),
      integrations: getIntegrationHealth(userId, app, agentId),
      mcp: getMcpHealth(userId, app, engine, agentId),
      skills: getSkillHealth(app, engine),
      tasks: getTaskHealth(userId, agentId),
    },
  };
}

module.exports = {
  getAndroidHealth,
  getBrowserHealth,
  getCapabilityHealth,
  summarizeCapabilityHealth,
};
