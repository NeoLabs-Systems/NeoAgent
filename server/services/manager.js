'use strict';

const db = require('../db/database');
const { MemoryManager } = require('./memory/manager');
const { MCPClient } = require('./mcp/client');
const { BrowserController } = require('./browser/controller');
const { AndroidController } = require('./android/controller');
const { AgentEngine } = require('./ai/engine');
const { MultiStepOrchestrator } = require('./ai/multiStep');
const { SkillRunner } = require('./ai/toolRunner');
const { MessagingManager } = require('./messaging/manager');
const { Scheduler } = require('./scheduler/cron');
const { setupWebSocket } = require('./websocket');
const { registerMessagingAutomation } = require('./messaging/automation');
const { RecordingManager } = require('./recordings/manager');
const WearableManager = require('./wearables/manager');
const { CLIExecutor } = require('./cli/executor');
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

function createBrowserController(app) {
  const browserController = registerLocal(
    app,
    'browserController',
    new BrowserController(),
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

function createAndroidController(app) {
  const androidController = registerLocal(
    app,
    'androidController',
    new AndroidController(),
  );
  logServiceReady('Android controller ready');
  return androidController;
}

async function createSkillRunner(app, cliExecutor) {
  const skillRunner = registerLocal(
    app,
    'skillRunner',
    new SkillRunner({ executor: cliExecutor }),
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
    skillRunner,
  },
) {
  const agentEngine = registerLocal(
    app,
    'agentEngine',
    new AgentEngine(io, {
      cliExecutor,
      memoryManager,
      mcpClient,
      browserController,
      androidController,
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

function createMessagingManager(app, io, agentEngine) {
  const messagingManager = registerLocal(
    app,
    'messagingManager',
    new MessagingManager(io),
  );
  agentEngine.messagingManager = messagingManager;
  logServiceReady('Messaging manager ready');
  return messagingManager;
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

function createWearableManager(app, io, services) {
  const wearableManager = registerLocal(
    app,
    'wearableManager',
    new WearableManager(io, services),
  );
  logServiceReady('Wearable manager ready');
  return wearableManager;
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

function startScheduler(app, io, agentEngine) {
  const scheduler = registerLocal(app, 'scheduler', new Scheduler(io, agentEngine, app));
  agentEngine.scheduler = scheduler;
  scheduler.start();
  logServiceReady('Scheduler started');
  return scheduler;
}

function configureRealtime(app, io, services) {
  setupWebSocket(io, {
    agentEngine: services.agentEngine,
    messagingManager: services.messagingManager,
    mcpClient: services.mcpClient,
    scheduler: services.scheduler,
    recordingManager: services.recordingManager,
    memoryManager: services.memoryManager,
    wearableManager: services.wearableManager,
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
    const memoryManager = createMemoryManager(app);
    const mcpClient = createMcpClient(app);
    const browserController = createBrowserController(app);
    const androidController = createAndroidController(app);
    const skillRunner = await createSkillRunner(app, cliExecutor);
    const agentEngine = createAgentEngine(app, io, {
      cliExecutor,
      memoryManager,
      mcpClient,
      browserController,
      androidController,
      skillRunner,
    });

    createMultiStep(app, agentEngine, io);

    const messagingManager = createMessagingManager(app, io, agentEngine);
    const recordingManager = createRecordingManager(app, io);
    const wearableManager = createWearableManager(app, io, { recordingManager });

    restoreMessagingConnections(messagingManager);
    restoreMcpClients(mcpClient);

    registerMessagingAutomation({
      app,
      io,
      messagingManager,
      agentEngine,
    });

    const scheduler = startScheduler(app, io, agentEngine);

    configureRealtime(app, io, {
      agentEngine,
      messagingManager,
      mcpClient,
      scheduler,
      recordingManager,
      memoryManager,
      wearableManager,
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

  if (app.locals.scheduler) {
    try {
      app.locals.scheduler.stop();
      logServiceReady('Scheduler stopped');
    } catch (err) {
      console.error('[Scheduler] Stop error:', getErrorMessage(err));
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

  if (app.locals.androidController) {
    tasks.push(
      app.locals.androidController.close().catch((err) => {
        console.error('[Android] Shutdown error:', getErrorMessage(err));
      }),
    );
  }

  if (app.locals.messagingManager) {
    tasks.push(
      app.locals.messagingManager.shutdown().catch((err) => {
        console.error('[Messaging] Shutdown error:', getErrorMessage(err));
      }),
    );
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
