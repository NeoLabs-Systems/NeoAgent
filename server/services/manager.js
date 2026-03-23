'use strict';

const db = require('../db/database');
const { MemoryManager } = require('./memory/manager');
const { MCPClient } = require('./mcp/client');
const { BrowserController } = require('./browser/controller');
const { AndroidController } = require('./android/controller');
const { AgentEngine } = require('./ai/engine');
const { LearningManager } = require('./ai/learning');
const { MultiStepOrchestrator } = require('./ai/multiStep');
const { SkillRunner } = require('./ai/toolRunner');
const { MessagingManager } = require('./messaging/manager');
const { Scheduler } = require('./scheduler/cron');
const { setupWebSocket } = require('./websocket');
const { registerMessagingAutomation } = require('./messaging/automation');
const { RecordingManager } = require('./recordings/manager');
const { CLIExecutor } = require('./cli/executor');

async function startServices(app, io) {
    try {
        console.log('[Services] Starting service initialization');
        const cliExecutor = new CLIExecutor();
        app.locals.cliExecutor = cliExecutor;
        console.log('[Services] CLI executor ready');

        const memoryManager = new MemoryManager();
        app.locals.memoryManager = memoryManager;
        console.log('[Services] Memory manager ready');

        const mcpClient = new MCPClient();
        app.locals.mcpClient = mcpClient;
        console.log('[Services] MCP client ready');

        const browserController = new BrowserController();
        const userCount = db.prepare('SELECT COUNT(*) AS count FROM users').get()?.count || 0;
        const headlessSetting = userCount === 1
          ? db.prepare('SELECT value FROM user_settings WHERE user_id = (SELECT id FROM users LIMIT 1) AND key = ?').get('headless_browser')
          : null;
        if (headlessSetting) {
            const val = headlessSetting.value;
            browserController.headless = val !== 'false' && val !== false && val !== '0';
            console.log(`[Services] Browser headless setting restored to ${browserController.headless}`);
        }
        app.locals.browserController = browserController;
        console.log(`[Services] Browser controller ready for ${userCount} user(s)`);

        const androidController = new AndroidController();
        app.locals.androidController = androidController;
        console.log('[Services] Android controller ready');

        const skillRunner = new SkillRunner({ executor: cliExecutor });
        await skillRunner.loadSkills();
        app.locals.skillRunner = skillRunner;
        console.log('[Services] Skills loaded');

        const learningManager = new LearningManager(skillRunner, io);
        app.locals.learningManager = learningManager;
        console.log('[Services] Learning manager ready');

        const agentEngine = new AgentEngine(io, {
            cliExecutor,
            memoryManager,
            mcpClient,
            browserController,
            androidController,
            messagingManager: null,
            skillRunner,
            learningManager
        });
        app.locals.agentEngine = agentEngine;
        console.log('[Services] Agent engine ready');

        const multiStep = new MultiStepOrchestrator(agentEngine, io);
        app.locals.multiStep = multiStep;
        console.log('[Services] Multi-step orchestrator ready');

        const messagingManager = new MessagingManager(io);
        app.locals.messagingManager = messagingManager;
        agentEngine.messagingManager = messagingManager;
        console.log('[Services] Messaging manager ready');

        messagingManager.restoreConnections().catch(err => console.error('[Messaging] Restore error:', err.message));

        const recordingManager = new RecordingManager(io);
        app.locals.recordingManager = recordingManager;
        console.log('[Services] Recording manager ready');

        const users = db.prepare('SELECT id FROM users').all();
        console.log(`[Services] Restoring MCP clients for ${users.length} user(s)`);
        for (const u of users) {
            mcpClient.loadFromDB(u.id).catch(err => console.error('[MCP] Auto-start error:', err.message));
        }

        registerMessagingAutomation({
            app,
            io,
            messagingManager,
            agentEngine,
        });

        const scheduler = new Scheduler(io, agentEngine, app);
        app.locals.scheduler = scheduler;
        agentEngine.scheduler = scheduler;
        scheduler.start();
        console.log('[Services] Scheduler started');

        setupWebSocket(io, {
            agentEngine,
            messagingManager,
            mcpClient,
            scheduler,
            recordingManager,
            memoryManager,
            app
        });
        app.locals.io = io;
        console.log('[Services] WebSocket handlers registered');

        recordingManager.resumePendingSessions().catch((err) => {
            console.error('[Recordings] Resume error:', err.message);
        });

        console.log('All services initialized');
    } catch (err) {
        console.error('Service init error:', err);
    }
}

async function stopServices(app) {
    const tasks = [];
    console.log('[Services] Stopping services');

    if (app.locals.scheduler) {
        try {
            app.locals.scheduler.stop();
            console.log('[Services] Scheduler stopped');
        } catch (err) {
            console.error('[Scheduler] Stop error:', err.message);
        }
    }

    if (app.locals.mcpClient) {
        tasks.push(
            app.locals.mcpClient.shutdown().catch((err) => {
                console.error('[MCP] Shutdown error:', err.message);
            }),
        );
    }

    if (app.locals.browserController) {
        tasks.push(
            app.locals.browserController.closeBrowser().catch((err) => {
                console.error('[Browser] Shutdown error:', err.message);
            }),
        );
    }

    if (app.locals.androidController) {
        tasks.push(
            app.locals.androidController.close().catch((err) => {
                console.error('[Android] Shutdown error:', err.message);
            }),
        );
    }

    if (app.locals.messagingManager) {
        tasks.push(
            app.locals.messagingManager.shutdown().catch((err) => {
                console.error('[Messaging] Shutdown error:', err.message);
            }),
        );
    }

    if (app.locals.cliExecutor) {
        try {
            app.locals.cliExecutor.killAll('shutdown');
            console.log('[Services] CLI executor processes terminated');
        } catch (err) {
            console.error('[CLI] Shutdown error:', err.message);
        }
    }

    await Promise.allSettled(tasks);
    console.log('[Services] Shutdown tasks settled');
}

module.exports = { startServices, stopServices };
