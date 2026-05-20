'use strict';

const db = require('../db/database');
const { MemoryManager } = require('./memory/manager');
const { MCPClient } = require('./mcp/client');
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
const { SocialVideoService } = require('./social_video');
const { VoiceRuntimeManager } = require('./voice/runtimeManager');
const { AuthProviderManager } = require('./account/auth_provider_manager');
const { IntegrationManager } = require('./integrations/manager');
const { MemoryIngestionService } = require('./memory/ingestion');
const { ArtifactStore } = require('./artifacts/store');
const { RuntimeManager } = require('./runtime/manager');
const { WorkspaceManager } = require('./workspace/manager');
const { BrowserExtensionRegistry } = require('./browser/extension/registry');
const { DesktopCompanionRegistry } = require('./desktop/registry');
const { DesktopProvider } = require('./desktop/provider');
const { ScreenRecorder } = require('./desktop/screenRecorder');
const { WearableService } = require('./wearable/service');
const { getRuntimeValidation } = require('./runtime/validation');
const {
  getErrorMessage,
  runBackgroundTask,
} = require('./bootstrap_helpers');

function registerLocal(app, key, value) {
  app.locals[key] = value;
  return value;
}

function logServiceReady(message) {
  console.log(`[Services] ${message}`);
}

function createArtifactStore(app) {
  const artifactStore = registerLocal(app, 'artifactStore', new ArtifactStore());
  logServiceReady('Artifact store ready');
  return artifactStore;
}

function createWorkspaceManager(app) {
  const workspaceManager = registerLocal(app, 'workspaceManager', new WorkspaceManager());
  logServiceReady('Workspace manager ready');
  return workspaceManager;
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

function createMemoryIngestionService(app, { memoryManager, integrationManager }) {
  const memoryIngestionService = registerLocal(
    app,
    'memoryIngestionService',
    new MemoryIngestionService({
      memoryManager,
      integrationManager,
    }),
  );
  memoryIngestionService.start();
  logServiceReady('Memory ingestion service started');
  return memoryIngestionService;
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
  registerLocal(app, 'getBrowserControllerForUser', async () => {
    throw new Error('Host browser controller is disabled. Use the VM browser backend or a paired extension.');
  });
  registerLocal(app, 'browserController', null);
  logServiceReady('Browser controller disabled in VM-only mode');
  return null;
}

function createRuntimeManager(app) {
  const runtimeManager = registerLocal(
    app,
    'runtimeManager',
    new RuntimeManager({
      artifactStore: app.locals.artifactStore,
      browserExtensionRegistry: app.locals.browserExtensionRegistry,
    }),
  );
  logServiceReady('Runtime manager ready');
  return runtimeManager;
}

async function createSkillRunner(app, runtimeManager) {
  const skillRunner = registerLocal(
    app,
    'skillRunner',
    new SkillRunner({ runtimeManager }),
  );
  await skillRunner.loadSkills();
  logServiceReady('Skills loaded');
  return skillRunner;
}

function createAgentEngine(
  app,
  io,
  {
    memoryManager,
    mcpClient,
    browserController,
    androidController,
    runtimeManager,
    skillRunner,
    workspaceManager,
  },
) {
  const agentEngine = registerLocal(
    app,
    'agentEngine',
    new AgentEngine(io, {
      app,
      memoryManager,
      mcpClient,
      browserController,
      androidController,
      runtimeManager,
      workspaceManager,
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

function createSocialVideoService(app) {
  const socialVideoService = registerLocal(
    app,
    'socialVideoService',
    new SocialVideoService({
      artifactStore: app.locals.artifactStore,
      runtimeManager: app.locals.runtimeManager,
    }),
  );
  logServiceReady('Social video service ready');
  return socialVideoService;
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

function createWearableService(app) {
  const wearableService = registerLocal(
    app,
    'wearableService',
    new WearableService({ app }),
  );
  logServiceReady('Wearable service ready');
  return wearableService;
}

function createScreenRecorder(app) {
  const hasActiveRemoteCaptureSession = () => {
    const desktopRegistry = app.locals.desktopCompanionRegistry;
    if (desktopRegistry?.connectionsByUser instanceof Map) {
      for (const userMap of desktopRegistry.connectionsByUser.values()) {
        if (!(userMap instanceof Map)) continue;
        for (const connection of userMap.values()) {
          if (typeof connection?.isOpen === 'function' && connection.isOpen()) {
            return true;
          }
        }
      }
    }

    const extensionRegistry = app.locals.browserExtensionRegistry;
    if (extensionRegistry?.connectionsByUser instanceof Map) {
      for (const value of extensionRegistry.connectionsByUser.values()) {
        if (value instanceof Map) {
          for (const connection of value.values()) {
            if (typeof connection?.isOpen === 'function' && connection.isOpen()) {
              return true;
            }
          }
        } else if (typeof value?.isOpen === 'function' && value.isOpen()) {
          return true;
        }
      }
    }

    return false;
  };

  const screenRecorder = registerLocal(
    app,
    'screenRecorder',
    new ScreenRecorder({ hasActiveRemoteCaptureSession }),
  );
  screenRecorder.start();
  logServiceReady('Screen recorder started');
  return screenRecorder;
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
    streamHub: app.locals.streamHub || services.streamHub || null,
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
    const artifactStore = createArtifactStore(app);
    createWorkspaceManager(app);
    createBrowserExtensionRegistry(app);
    createDesktopCompanionRegistry(app);
    const memoryManager = createMemoryManager(app);
    const mcpClient = createMcpClient(app);
    createAuthProviderManager(app);
    const integrationManager = createIntegrationManager(app);
    createMemoryIngestionService(app, { memoryManager, integrationManager });
    const browserController = createBrowserController(app, artifactStore);
    const runtimeManager = createRuntimeManager(app);
    const runtimeValidation = getRuntimeValidation(runtimeManager);
    registerLocal(app, 'runtimeValidation', runtimeValidation);
    if (!runtimeValidation.ready) {
      console.warn('[Services] Runtime validation is degraded:', runtimeValidation.issues.join(' '));
    }
    const skillRunner = await createSkillRunner(app, runtimeManager);
    const agentEngine = createAgentEngine(app, io, {
      memoryManager,
      mcpClient,
      browserController,
      androidController: null,
      runtimeManager,
      skillRunner,
      workspaceManager: app.locals.workspaceManager,
    });

    createMultiStep(app, agentEngine, io);
    createCommandRouter(app);
    const voiceRuntimeManager = createVoiceRuntimeManager(app, io, {
      agentEngine,
      memoryManager,
    });

    const messagingManager = createMessagingManager(app, io, agentEngine);
    const recordingManager = createRecordingManager(app, io);
    createSocialVideoService(app);
    createWidgetService(app);
    createWearableService(app);
    createScreenRecorder(app);

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
      streamHub: app.locals.streamHub || null,
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

  if (app.locals.streamHub) {
    try {
      await app.locals.streamHub.shutdown();
      logServiceReady('Stream hub stopped');
    } catch (err) {
      console.error('[StreamHub] Shutdown error:', getErrorMessage(err));
    }
  }

  if (app.locals.memoryIngestionService) {
    try {
      app.locals.memoryIngestionService.stop();
      logServiceReady('Memory ingestion service stopped');
    } catch (err) {
      console.error('[MemoryIngestion] Stop error:', getErrorMessage(err));
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

  if (app.locals.wearableGateway?.close) {
    tasks.push(
      app.locals.wearableGateway.close().catch((err) => {
        console.error('[WearableGateway] Shutdown error:', getErrorMessage(err));
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

  if (app.locals.screenRecorder) {
    try {
      app.locals.screenRecorder.stop();
      logServiceReady('Screen recorder stopped');
    } catch (err) {
      console.error('[ScreenRecorder] Stop error:', getErrorMessage(err));
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

  await Promise.allSettled(tasks);
  logServiceReady('Shutdown tasks settled');
}

module.exports = { startServices, stopServices };
