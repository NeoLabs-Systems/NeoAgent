const db = require('../../db/database');
const { getProviderHealthCatalog } = require('./models');
const { resolveBrowserExecutablePath } = require('../browser/controller');
const { deriveCloudBrowserBackend } = require('../runtime/settings');

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

async function getBrowserHealth(userId, app, engine) {
  const runtimeManager = app?.locals?.runtimeManager || engine?.runtimeManager || null;
  const executablePath = resolveBrowserExecutablePath();
  const runtimeSettings = typeof runtimeManager?.getSettings === 'function'
    ? runtimeManager.getSettings(userId)
    : null;
  const extensionStatus = runtimeSettings?.browser_backend === 'extension'
    ? app?.locals?.browserExtensionRegistry?.getStatus(userId)
    : null;
  if (runtimeSettings?.browser_backend === 'extension') {
    const activeTokens = Array.isArray(extensionStatus?.tokens)
      ? extensionStatus.tokens.filter((token) => token.status === 'active')
      : [];
    const connected = extensionStatus?.connected === true;
    const configured = connected || activeTokens.length > 0;
    if (connected) {
      return capabilityEntry({
        connected,
        configured,
        healthy: connected,
        degraded: false,
        summary: 'Browser extension is connected.',
        details: {
          backend: 'extension',
          activeTokenCount: activeTokens.length,
          activeTokenId: extensionStatus?.activeTokenId || null,
        },
      });
    }
  }
  let controller = null;
  let resolutionError = null;

  if (runtimeManager && typeof runtimeManager.getBrowserProviderForUser === 'function') {
    try {
      controller = await runtimeManager.getBrowserProviderForUser(userId);
    } catch (err) {
      resolutionError = err;
    }
  }

  if (!controller) {
    resolutionError = resolutionError || new Error('Browser provider is unavailable. VM runtime is required.');
  }

  if (!controller && resolutionError) {
    return capabilityEntry({
      configured: Boolean(executablePath),
      healthy: false,
      degraded: true,
      summary: `Browser controller resolution failed: ${resolutionError.message}`,
      details: {
        executablePath: executablePath || null,
        error: resolutionError.message,
      },
    });
  }
  let pageInfo = null;
  let launched = false;
  let error = null;

  try {
    launched = typeof controller?.isLaunched === 'function'
      ? await Promise.resolve(controller.isLaunched())
      : false;
    pageInfo = typeof controller?.getPageInfo === 'function' ? await controller.getPageInfo() : null;
  } catch (err) {
    error = err.message;
  }

  return capabilityEntry({
    connected: launched,
    configured: Boolean(executablePath),
    healthy: Boolean(executablePath) && !error,
    degraded: Boolean(error) || runtimeSettings?.browser_backend === 'extension',
    summary: error
      ? `Browser runtime error: ${error}`
      : runtimeSettings?.browser_backend === 'extension'
        ? executablePath
          ? `No extension device is active. Falling back to the ${deriveCloudBrowserBackend(runtimeSettings)} browser runtime.`
          : 'No extension device is active and no browser executable was found for Puppeteer.'
        : executablePath
          ? (launched ? 'Browser runtime is ready.' : 'Browser executable is available but not launched.')
          : 'No browser executable was found for Puppeteer.',
    details: {
      executablePath: executablePath || null,
      preferredBackend: runtimeSettings?.browser_backend || null,
      backend: runtimeSettings?.browser_backend === 'extension'
        ? deriveCloudBrowserBackend(runtimeSettings)
        : runtimeSettings?.browser_backend || null,
      extensionConnected: extensionStatus?.connected === true,
      activeTokenCount: Array.isArray(extensionStatus?.tokens)
        ? extensionStatus.tokens.filter((token) => token.status === 'active').length
        : 0,
      launched,
      pageInfo,
    },
  });
}

async function getAndroidHealth(userId, app, engine) {
  const runtimeManager = app?.locals?.runtimeManager || engine?.runtimeManager || null;
  let controller = null;
  let resolutionError = null;

  if (runtimeManager && typeof runtimeManager.getAndroidProviderForUser === 'function') {
    try {
      controller = await runtimeManager.getAndroidProviderForUser(userId);
    } catch (err) {
      resolutionError = err;
    }
  }

  if (!controller) {
    resolutionError = resolutionError || new Error('Android provider is unavailable. VM runtime is required.');
  }

  if (!controller || typeof controller.getStatus !== 'function') {
    return capabilityEntry({
      degraded: Boolean(resolutionError),
      summary: resolutionError
        ? `Android controller resolution failed: ${resolutionError.message}`
        : 'Android controller is not available.',
      details: resolutionError ? { error: resolutionError.message } : {},
    });
  }

  try {
    const status = await controller.getStatus();
    const bootstrapped = status.bootstrapped === true;
    const canBootstrap = status.canBootstrap === true;
    return capabilityEntry({
      connected: Array.isArray(status.devices) && status.devices.some((device) => device.status === 'device'),
      configured: canBootstrap || bootstrapped,
      healthy: canBootstrap || bootstrapped,
      degraded: Boolean(status.lastStartError),
      summary: status.lastStartError
        ? `Android tooling reported: ${status.lastStartError}`
        : bootstrapped
          ? 'Android environment is bootstrapped.'
          : (canBootstrap ? 'Android environment can be bootstrapped on this host.' : 'Android tooling cannot bootstrap on this host.'),
      details: status,
    });
  } catch (err) {
    return capabilityEntry({
      configured: true,
      healthy: false,
      degraded: true,
      summary: `Android status check failed: ${err.message}`,
      details: { error: err.message },
    });
  }
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
      ? 'Shell command execution is available through the per-user runtime capsule.'
      : 'Shell executor is not available.',
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

async function getCapabilityHealth({ userId, agentId = null, app, engine }) {
  const providers = await getProviderHealthCatalog(userId, agentId);

  return {
    providers,
    capabilities: {
      command: getCommandHealth(userId, app, engine),
      files: getFileHealth(app, engine),
      memory: getMemoryHealth(engine),
      search: getSearchHealth(),
      browser: await getBrowserHealth(userId, app, engine),
      android: await getAndroidHealth(userId, app, engine),
      messaging: getMessagingHealth(userId, app, engine, agentId),
      integrations: getIntegrationHealth(userId, app, agentId),
      mcp: getMcpHealth(userId, app, engine, agentId),
      skills: getSkillHealth(app, engine),
      tasks: getTaskHealth(userId, agentId),
    },
  };
}

module.exports = {
  getCapabilityHealth,
  summarizeCapabilityHealth,
};
