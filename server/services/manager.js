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
const { SocialVideoService } = require('./social_video');
const { SocialReachService } = require('./social_reach');
const { VoiceRuntimeManager } = require('./voice/runtimeManager');
const { AuthProviderManager } = require('./account/auth_provider_manager');
const { IntegrationManager } = require('./integrations/manager');
const { MemoryIngestionService } = require('./memory/ingestion');
const { ArtifactStore } = require('./artifacts/store');
const { RuntimeManager } = require('./runtime/manager');
const { WorkspaceManager } = require('./workspace/manager');
const { CodeNavigationService } = require('./workspace/code_navigation');
const { StructuredDataService } = require('./workspace/structured_data');
const { TaskWebhookService } = require('./tasks/webhooks');
const { LearningManager } = require('./ai/learning');
const { CapabilityAuditService } = require('./security/capability_audit');
const { ToolPolicyService } = require('./security/tool_policy_service');
const { ApprovalGateService } = require('./security/approval_gate_service');
const { registerToolSecurityHooks } = require('./security/tool_security_hook');
const { BrowserExtensionRegistry } = require('./browser/extension/registry');
const { DesktopCompanionRegistry } = require('./desktop/registry');
const { DesktopProvider } = require('./desktop/provider');
const { TimelineService } = require('./timeline/service');
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
  registerLocal(app, 'codeNavigationService', new CodeNavigationService({ workspaceManager }));
  registerLocal(app, 'structuredDataService', new StructuredDataService({ workspaceManager }));
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

function createTimelineService(app, io) {
  const timelineService = registerLocal(
    app,
    'timelineService',
    new TimelineService({ io }),
  );
  logServiceReady('Timeline service ready');
  return timelineService;
}

function createMemoryManager(app) {
  const memoryManager = registerLocal(app, 'memoryManager', new MemoryManager());
  memoryManager.startEmbeddingIndexBackfill();
  const reconcile = () => {
    const users = db.prepare('SELECT id FROM users').all();
    for (const user of users) {
      const agents = db.prepare("SELECT id FROM agents WHERE user_id = ? AND status = 'active'").all(user.id);
      for (const agent of agents) {
        try {
          memoryManager.reconcileFacts(user.id, { agentId: agent.id });
        } catch (err) {
          console.warn('[Memory] Fact reconciliation failed:', err.message);
        }
      }
    }
  };
  const timer = setInterval(reconcile, 6 * 60 * 60 * 1000);
  timer.unref?.();
  registerLocal(app, 'memoryReconciliationTimer', timer);
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
      intervalMs: process.env.NEOAGENT_MEMORY_INGESTION_INTERVAL_MS || undefined,
    }),
  );
  const status = memoryIngestionService.start();
  logServiceReady(`Memory ingestion service started (${status.intervalMs}ms interval)`);
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
  const { ShellWorkerPool } = require('./cli/shell_worker_pool');
  const shellWorkerPool = registerLocal(
    app,
    'shellWorkerPool',
    new ShellWorkerPool({ size: 4 }),
  );
  const runtimeManager = registerLocal(
    app,
    'runtimeManager',
    new RuntimeManager({
      artifactStore: app.locals.artifactStore,
      browserExtensionRegistry: app.locals.browserExtensionRegistry,
      desktopCompanionRegistry: app.locals.desktopCompanionRegistry,
      shellWorkerPool,
    }),
  );
  logServiceReady('Runtime manager + shell worker pool ready');
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

function createSocialReachService(app) {
  const socialReachService = registerLocal(
    app,
    'socialReachService',
    new SocialReachService({
      browserExtensionRegistry: app.locals.browserExtensionRegistry,
      socialVideoService: app.locals.socialVideoService,
    }),
  );
  logServiceReady('Social reach service ready');
  return socialReachService;
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
    memoryManager: services.memoryManager,
    voiceRuntimeManager: services.voiceRuntimeManager,
    streamHub: app.locals.streamHub || services.streamHub || null,
    app,
  });
  app.locals.io = io;
  logServiceReady('WebSocket handlers registered');
}

async function startServices(app, io) {
  console.log('[Services] Starting service initialization');

  try {
    const artifactStore = createArtifactStore(app);
    createWorkspaceManager(app);
    createBrowserExtensionRegistry(app);
    createDesktopCompanionRegistry(app);
    createTimelineService(app, io);
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
    registerLocal(app, 'learningManager', new LearningManager(skillRunner, io));
    registerLocal(app, 'capabilityAuditService', new CapabilityAuditService({
      mcpClient,
      skillRunner,
    }));
    const toolPolicyService = registerLocal(app, 'toolPolicyService', new ToolPolicyService());
    const approvalGateService = registerLocal(app, 'approvalGateService', new ApprovalGateService({ io }));
    registerToolSecurityHooks(toolPolicyService, approvalGateService);
    logServiceReady('Tool security hooks registered');
    agentEngine.learningManager = app.locals.learningManager;

    createMultiStep(app, agentEngine, io);
    createCommandRouter(app);
    const voiceRuntimeManager = createVoiceRuntimeManager(app, io, {
      agentEngine,
      memoryManager,
    });

    const messagingManager = createMessagingManager(app, io, agentEngine);
    createSocialVideoService(app);
    createSocialReachService(app);
    createWidgetService(app);
    createWearableService(app);

    restoreMessagingConnections(messagingManager);
    restoreMcpClients(mcpClient);

    registerMessagingAutomation({
      app,
      io,
      messagingManager,
      agentEngine,
    });

    const taskRuntime = startTaskRuntime(app, io, agentEngine);
    registerLocal(app, 'taskWebhookService', new TaskWebhookService({ taskRuntime }));

    configureRealtime(app, io, {
      agentEngine,
      messagingManager,
      integrationManager,
      mcpClient,
      taskRuntime,
      memoryManager,
      voiceRuntimeManager,
      streamHub: app.locals.streamHub || null,
    });

    // Sync billing rate limits for all active subscribers in case any
    // Stripe webhooks were delivered while the server was offline.
    try {
      const { isBillingEnabled } = require('./billing/config');
      if (isBillingEnabled()) {
        require('./billing/subscriptions').syncAllSubscriberRateLimits();
      }
    } catch {
      // Best-effort; never block startup.
    }

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
  if (app.locals.approvalGateService && typeof app.locals.approvalGateService.shutdown === 'function') {
    try {
      app.locals.approvalGateService.shutdown();
      logServiceReady('Pending approvals expired');
    } catch (err) {
      console.error('[ApprovalGate] Shutdown error:', getErrorMessage(err));
    }
  }
  if (app.locals.agentEngine && typeof app.locals.agentEngine.interruptAllActiveRuns === 'function') {
    try {
      app.locals.agentEngine.interruptAllActiveRuns();
      logServiceReady('Active runs marked interrupted');
    } catch (err) {
      console.error('[AgentEngine] Interrupt error:', getErrorMessage(err));
    }
  }
  if (app.locals.memoryManager) {
    app.locals.memoryManager.stopEmbeddingIndexBackfill();
  }
  if (app.locals.memoryReconciliationTimer) {
    clearInterval(app.locals.memoryReconciliationTimer);
    app.locals.memoryReconciliationTimer = null;
  }

  if (app.locals.taskRuntime) {
    tasks.push(
      Promise.resolve()
        .then(() => app.locals.taskRuntime.stop())
        .then((status) => {
          logServiceReady(`Task runtime shutdown complete (${status.state})`);
        })
        .catch((err) => {
          console.error('[Tasks] Stop error:', getErrorMessage(err));
        }),
    );
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
    tasks.push(
      Promise.resolve()
        .then(() => app.locals.memoryIngestionService.stop())
        .then((status) => {
          logServiceReady(`Memory ingestion shutdown complete (${status.state})`);
        })
        .catch((err) => {
          console.error('[MemoryIngestion] Stop error:', getErrorMessage(err));
        }),
    );
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
