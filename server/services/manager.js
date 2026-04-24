'use strict';

const db = require('../db/database');
const { MemoryManager } = require('./memory/manager');
const { MCPClient } = require('./mcp/client');
const { BrowserController } = require('./browser/controller');
const { AndroidController } = require('./android/controller');
const { AgentEngine } = require('./ai/engine');
const { MultiStepOrchestrator } = require('./ai/multiStep');
const { SkillRunner } = require('./ai/toolRunner');
const { CommandRouter } = require('./commands/router');
const { MessagingManager } = require('./messaging/manager');
const { TaskRuntime } = require('./tasks/runtime');
const { WidgetService } = require('./widgets/service');
const { setupWebSocket } = require('./websocket');
const { registerMessagingAutomation } = require('./messaging/automation');
const { RecordingManager } = require('./recordings/manager');
const { VoiceRuntimeManager } = require('./voice/runtimeManager');
const { CLIExecutor } = require('./cli/executor');
const { AuthProviderManager } = require('./account/auth_provider_manager');
const { IntegrationManager } = require('./integrations/manager');
const { ArtifactStore } = require('./artifacts/store');
const { RuntimeManager } = require('./runtime/manager');
const { BrowserExtensionRegistry } = require('./browser/extension/registry');
const { DesktopCompanionRegistry } = require('./desktop/registry');
const { DesktopProvider } = require('./desktop/provider');
const { assertRuntimeValidation, getRuntimeValidation } = require('./runtime/validation');
const {
  getErrorMessage,
  restoreBrowserHeadlessPreference,
  runBackgroundTask,
} = require('./bootstrap_helpers');

function registerLocal(app, key, value) {
  app.locals[key] = value;
  return value;
}

function logServiceReady(message) {
  console.log(`[Services] ${message}`);
}

function createCliExecutor(app) {
  const cliExecutor = registerLocal(app, 'cliExecutor', new CLIExecutor());
  logServiceReady('CLI executor ready');
  return cliExecutor;
}

function createArtifactStore(app) {
  const artifactStore = registerLocal(app, 'artifactStore', new ArtifactStore());
  logServiceReady('Artifact store ready');
  return artifactStore;
}

function createBrowserExtensionRegistry(app) {
  const registry = registerLocal(app, 'browserExtensionRegistry', new BrowserExtensionRegistry());
  logServiceReady('Browser extension registry ready');
  return registry;
}

function createDesktopCompanionRegistry(app) {
  const registry = registerLocal(app, 'desktopCompanionRegistry', new DesktopCompanionRegistry());
  registerLocal(
    app,
    'getDesktopProviderForUser',
    (userId) => new DesktopProvider({
      registry,
      artifactStore: app.locals.artifactStore,
      userId,
    }),
  );
  registerLocal(
    app,
    'desktopProvider',
    new DesktopProvider({
      registry,
      artifactStore: app.locals.artifactStore,
      userId: null,
    }),
  );
  logServiceReady('Desktop companion registry ready');
  return registry;
}

function createMemoryManager(app) {
  const memoryManager = registerLocal(app, 'memoryManager', new MemoryManager());
  logServiceReady('Memory manager ready');
  return memoryManager;
}

function createMcpClient(app) {
  const mcpClient = registerLocal(app, 'mcpClient', new MCPClient());
  logServiceReady('MCP client ready');
  return mcpClient;
}

function createIntegrationManager(app) {
  const integrationManager = registerLocal(
    app,
    'integrationManager',
    new IntegrationManager({ app }),
  );
  logServiceReady('Integration manager ready');
  return integrationManager;
}

function createAuthProviderManager(app) {
  const authProviderManager = registerLocal(
    app,
    'authProviderManager',
    new AuthProviderManager(),
  );
  logServiceReady('Auth provider manager ready');
  return authProviderManager;
}

function createUserScopedControllerPool(app, {
  controllersKey,
  creationPromisesKey,
  lastAccessKey,
  resolverKey,
  defaultControllerKey,
  maxControllers = 24,
  createController,
  closeController,
  closeErrorLabel,
}) {
  const controllers = registerLocal(app, controllersKey, new Map());
  const creationPromises = registerLocal(app, creationPromisesKey, new Map());
  const lastAccess = registerLocal(app, lastAccessKey, new Map());

  function touch(key) {
    lastAccess.set(key, Date.now());
  }

  async function evictStaleControllers() {
    if (controllers.size <= maxControllers) {
      return;
    }

    const entries = Array.from(lastAccess.entries())
      .sort((left, right) => left[1] - right[1]);

    while (controllers.size > maxControllers && entries.length > 0) {
      const [staleKey] = entries.shift();
      const controller = controllers.get(staleKey);
      if (controller) {
        try {
          await closeController(controller);
        } catch (err) {
          console.warn(`${closeErrorLabel}:`, getErrorMessage(err));
        }
      }
      controllers.delete(staleKey);
      lastAccess.delete(staleKey);
      creationPromises.delete(staleKey);
    }
  }

  async function getControllerForUser(userId) {
    const key = String(userId || '').trim();
    if (!key) {
      return app.locals[defaultControllerKey];
    }

    if (controllers.has(key)) {
      touch(key);
      return controllers.get(key);
    }

    if (creationPromises.has(key)) {
      return creationPromises.get(key);
    }

    const creationPromise = Promise.resolve().then(async () => {
      const controller = await createController(key);
      controllers.set(key, controller);
      touch(key);
      await evictStaleControllers();
      return controller;
    }).finally(() => {
      creationPromises.delete(key);
    });

    creationPromises.set(key, creationPromise);
    return creationPromise;
  }

  registerLocal(app, resolverKey, getControllerForUser);

  return {
    controllers,
    creationPromises,
    lastAccess,
    getControllerForUser,
  };
}

function createBrowserController(app, artifactStore) {
  function getUserHeadlessPreference(userId) {
    try {
      const row = db
        .prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
        .get(userId, 'headless_browser');
      if (!row) return true;
      return row.value !== 'false' && row.value !== false && row.value !== '0';
    } catch (err) {
      console.warn('[Services] Failed to read user headless_browser setting, defaulting to true:', getErrorMessage(err));
      return true;
    }
  }

  createUserScopedControllerPool(app, {
    controllersKey: 'browserControllers',
    creationPromisesKey: 'browserControllerCreationPromises',
    lastAccessKey: 'browserControllerLastAccess',
    resolverKey: 'getBrowserControllerForUser',
    defaultControllerKey: 'browserController',
    createController: async (userId) => {
      const controller = new BrowserController({
        userId,
        artifactStore,
        runtimeBackend: 'host',
      });
      controller.headless = getUserHeadlessPreference(userId);
      return controller;
    },
    closeController: async (controller) => {
      if (typeof controller.closeBrowser === 'function') {
        await controller.closeBrowser();
      }
    },
    closeErrorLabel: '[Browser] Failed to close stale browser controller',
  });

  const browserController = registerLocal(
    app,
    'browserController',
    new BrowserController({
      artifactStore,
      runtimeBackend: 'host',
    }),
  );
  const { restored, userCount, headless } = restoreBrowserHeadlessPreference(
    browserController,
    db,
  );

  if (restored) {
    logServiceReady(`Browser headless setting restored to ${headless}`);
  }

  logServiceReady(`Browser controller ready for ${userCount} user(s)`);
  return browserController;
}

function createAndroidController(app, artifactStore) {
  createUserScopedControllerPool(app, {
    controllersKey: 'androidControllers',
    creationPromisesKey: 'androidControllerCreationPromises',
    lastAccessKey: 'androidControllerLastAccess',
    resolverKey: 'getAndroidControllerForUser',
    defaultControllerKey: 'androidController',
    createController: async (userId) => {
      const controller = new AndroidController({
        userId,
        artifactStore,
        runtimeBackend: 'host',
      });
      return controller;
    },
    closeController: async (controller) => {
      if (typeof controller.close === 'function') {
        await controller.close();
      }
    },
    closeErrorLabel: '[Android] Failed to close stale Android controller',
  });

  const androidController = registerLocal(
    app,
    'androidController',
    new AndroidController({
      artifactStore,
      runtimeBackend: 'host',
    }),
  );
  logServiceReady('Android controller ready');
  return androidController;
}

function createRuntimeManager(app, cliExecutor) {
  const runtimeManager = registerLocal(
    app,
    'runtimeManager',
    new RuntimeManager({
      cliExecutor,
      artifactStore: app.locals.artifactStore,
      browserExtensionRegistry: app.locals.browserExtensionRegistry,
      getHostBrowserProvider: (userId) => {
        const resolver = app.locals.getBrowserControllerForUser;
        if (typeof resolver === 'function') {
          return resolver(userId);
        }
        return app.locals.browserController;
      },
      getHostAndroidProvider: (userId) => {
        const resolver = app.locals.getAndroidControllerForUser;
        if (typeof resolver === 'function') {
          return resolver(userId);
        }
        return app.locals.androidController;
      },
    }),
  );
  logServiceReady('Runtime manager ready');
  return runtimeManager;
}

async function createSkillRunner(app, cliExecutor, runtimeManager) {
  const skillRunner = registerLocal(
    app,
    'skillRunner',
    new SkillRunner({ executor: cliExecutor, runtimeManager }),
  );
  await skillRunner.loadSkills();
  logServiceReady('Skills loaded');
  return skillRunner;
}

function createAgentEngine(
  app,
  io,
  {
    cliExecutor,
    memoryManager,
    mcpClient,
    browserController,
    androidController,
    runtimeManager,
    skillRunner,
  },
) {
  const agentEngine = registerLocal(
    app,
    'agentEngine',
    new AgentEngine(io, {
      app,
      cliExecutor,
      memoryManager,
      mcpClient,
      browserController,
      androidController,
      runtimeManager,
      messagingManager: null,
      skillRunner,
    }),
  );
  logServiceReady('Agent engine ready');
  return agentEngine;
}

function createMultiStep(app, agentEngine, io) {
  const multiStep = registerLocal(
    app,
    'multiStep',
    new MultiStepOrchestrator(agentEngine, io),
  );
  logServiceReady('Multi-step orchestrator ready');
  return multiStep;
}

function createCommandRouter(app) {
  const commandRouter = registerLocal(
    app,
    'commandRouter',
    new CommandRouter(app),
  );
  logServiceReady('Command router ready');
  return commandRouter;
}

function createMessagingManager(app, io, agentEngine) {
  const messagingManager = registerLocal(
    app,
    'messagingManager',
    new MessagingManager(io, {
      voiceRuntimeManager: app.locals.voiceRuntimeManager || null,
    }),
  );
  agentEngine.messagingManager = messagingManager;
  logServiceReady('Messaging manager ready');
  return messagingManager;
}

function createVoiceRuntimeManager(app, io, { agentEngine, memoryManager }) {
  const voiceRuntimeManager = registerLocal(
    app,
    'voiceRuntimeManager',
    new VoiceRuntimeManager({
      io,
      agentEngine,
      memoryManager,
    }),
  );
  agentEngine.voiceRuntimeManager = voiceRuntimeManager;
  logServiceReady('Voice runtime manager ready');
  return voiceRuntimeManager;
}

function createRecordingManager(app, io) {
  const recordingManager = registerLocal(
    app,
    'recordingManager',
    new RecordingManager(io),
  );
  logServiceReady('Recording manager ready');
  return recordingManager;
}

function createWidgetService(app) {
  const widgetService = registerLocal(
    app,
    'widgetService',
    new WidgetService({ app }),
  );
  logServiceReady('Widget service ready');
  return widgetService;
}

function restoreMessagingConnections(messagingManager) {
  void runBackgroundTask('[Messaging] Restore error:', () =>
    messagingManager.restoreConnections(),
  );
}

function restoreMcpClients(mcpClient) {
  const users = db.prepare('SELECT id FROM users').all();
  logServiceReady(`Restoring MCP clients for ${users.length} user(s)`);

  for (const user of users) {
    void runBackgroundTask('[MCP] Auto-start error:', () =>
      mcpClient.loadFromDB(user.id),
    );
  }
}

function startTaskRuntime(app, io, agentEngine) {
  const taskRuntime = registerLocal(app, 'taskRuntime', new TaskRuntime(io, agentEngine, app));
  agentEngine.taskRuntime = taskRuntime;
  taskRuntime.start();
  logServiceReady('Task runtime started');
  return taskRuntime;
}

function configureRealtime(app, io, services) {
  setupWebSocket(io, {
    agentEngine: services.agentEngine,
    messagingManager: services.messagingManager,
    mcpClient: services.mcpClient,
    integrationManager: services.integrationManager,
    taskRuntime: services.taskRuntime,
    recordingManager: services.recordingManager,
    memoryManager: services.memoryManager,
    voiceRuntimeManager: services.voiceRuntimeManager,
    app,
  });
  app.locals.io = io;
  logServiceReady('WebSocket handlers registered');
}

function resumePendingRecordingSessions(recordingManager) {
  void runBackgroundTask('[Recordings] Resume error:', () =>
    recordingManager.resumePendingSessions(),
  );
}

async function startServices(app, io) {
  console.log('[Services] Starting service initialization');

  try {
    const cliExecutor = createCliExecutor(app);
    const artifactStore = createArtifactStore(app);
    createBrowserExtensionRegistry(app);
    createDesktopCompanionRegistry(app);
    const memoryManager = createMemoryManager(app);
    const mcpClient = createMcpClient(app);
    createAuthProviderManager(app);
    const integrationManager = createIntegrationManager(app);
    const browserController = createBrowserController(app, artifactStore);
    const androidController = createAndroidController(app, artifactStore);
    const runtimeManager = createRuntimeManager(app, cliExecutor);
    registerLocal(app, 'runtimeValidation', getRuntimeValidation(runtimeManager));
    assertRuntimeValidation(runtimeManager);
    const skillRunner = await createSkillRunner(app, cliExecutor, runtimeManager);
    const agentEngine = createAgentEngine(app, io, {
      cliExecutor,
      memoryManager,
      mcpClient,
      browserController,
      androidController,
      runtimeManager,
      skillRunner,
    });

    createMultiStep(app, agentEngine, io);
    createCommandRouter(app);
    const voiceRuntimeManager = createVoiceRuntimeManager(app, io, {
      agentEngine,
      memoryManager,
    });

    const messagingManager = createMessagingManager(app, io, agentEngine);
    const recordingManager = createRecordingManager(app, io);
    createWidgetService(app);

    restoreMessagingConnections(messagingManager);
    restoreMcpClients(mcpClient);

    registerMessagingAutomation({
      app,
      io,
      messagingManager,
      agentEngine,
    });

    const taskRuntime = startTaskRuntime(app, io, agentEngine);

    configureRealtime(app, io, {
      agentEngine,
      messagingManager,
      integrationManager,
      mcpClient,
      taskRuntime,
      recordingManager,
      memoryManager,
      voiceRuntimeManager,
    });

    resumePendingRecordingSessions(recordingManager);

    console.log('All services initialized');
  } catch (err) {
    console.error('Service init error:', err);
    await stopServices(app);
    throw err;
  }
}

async function stopServices(app) {
  const tasks = [];
  console.log('[Services] Stopping services');

  if (app.locals.taskRuntime) {
    try {
      app.locals.taskRuntime.stop();
      logServiceReady('Task runtime stopped');
    } catch (err) {
      console.error('[Tasks] Stop error:', getErrorMessage(err));
    }
  }

  if (app.locals.mcpClient) {
    tasks.push(
      app.locals.mcpClient.shutdown().catch((err) => {
        console.error('[MCP] Shutdown error:', getErrorMessage(err));
      }),
    );
  }

  if (app.locals.browserController) {
    tasks.push(
      app.locals.browserController.closeBrowser().catch((err) => {
        console.error('[Browser] Shutdown error:', getErrorMessage(err));
      }),
    );
  }

  if (app.locals.browserControllers instanceof Map) {
    for (const controller of app.locals.browserControllers.values()) {
      tasks.push(
        controller.closeBrowser().catch((err) => {
          console.error('[Browser] User-scoped shutdown error:', getErrorMessage(err));
        }),
      );
    }
  }

  if (app.locals.androidController) {
    tasks.push(
      app.locals.androidController.close().catch((err) => {
        console.error('[Android] Shutdown error:', getErrorMessage(err));
      }),
    );
  }

  if (app.locals.androidControllers instanceof Map) {
    for (const controller of app.locals.androidControllers.values()) {
      tasks.push(
        controller.close().catch((err) => {
          console.error('[Android] User-scoped shutdown error:', getErrorMessage(err));
        }),
      );
    }
  }

  if (app.locals.messagingManager) {
    tasks.push(
      app.locals.messagingManager.shutdown().catch((err) => {
        console.error('[Messaging] Shutdown error:', getErrorMessage(err));
      }),
    );
  }

  if (app.locals.runtimeManager) {
    tasks.push(
      app.locals.runtimeManager.shutdown().catch((err) => {
        console.error('[Runtime] Shutdown error:', getErrorMessage(err));
      }),
    );
  }

  if (app.locals.widgetService) {
    const widgetService = app.locals.widgetService;
    const cleanupMethod = ['shutdown', 'close', 'stop', 'dispose'].find(
      (method) => typeof widgetService[method] === 'function',
    );
    if (cleanupMethod) {
      tasks.push(
        Promise.resolve()
          .then(() => widgetService[cleanupMethod]())
          .then(() => {
            logServiceReady(`Widget service ${cleanupMethod} completed`);
          })
          .catch((err) => {
            console.error('[Widget] Shutdown error:', getErrorMessage(err));
          }),
      );
    }
  }

  if (app.locals.browserExtensionRegistry) {
    try {
      app.locals.browserExtensionRegistry.closeAll();
      logServiceReady('Browser extension connections closed');
    } catch (err) {
      console.error('[BrowserExtension] Shutdown error:', getErrorMessage(err));
    }
  }

  if (app.locals.desktopCompanionRegistry) {
    try {
      app.locals.desktopCompanionRegistry.closeAll();
      logServiceReady('Desktop companion connections closed');
    } catch (err) {
      console.error('[DesktopCompanion] Shutdown error:', getErrorMessage(err));
    }
  }

  if (app.locals.cliExecutor) {
    try {
      app.locals.cliExecutor.killAll('shutdown');
      logServiceReady('CLI executor processes terminated');
    } catch (err) {
      console.error('[CLI] Shutdown error:', getErrorMessage(err));
    }
  }

  await Promise.allSettled(tasks);
  logServiceReady('Shutdown tasks settled');
}

module.exports = { startServices, stopServices };
