'use strict';

const db = require('../db/database');
const { MemoryManager } = require('./memory/manager');
const { MCPClient } = require('./mcp/client');
const { BrowserController } = require('./browser/controller');
const { AgentEngine } = require('./ai/engine');
const { LearningManager } = require('./ai/learning');
const { MultiStepOrchestrator } = require('./ai/multiStep');
const { SkillRunner } = require('./ai/toolRunner');
const { MessagingManager } = require('./messaging/manager');
const { Scheduler } = require('./scheduler/cron');
const { setupWebSocket } = require('./websocket');
const { registerMessagingAutomation } = require('./messaging/automation');

async function startServices(app, io) {
    try {
        const memoryManager = new MemoryManager();
        app.locals.memoryManager = memoryManager;

        const mcpClient = new MCPClient();
        app.locals.mcpClient = mcpClient;

        const browserController = new BrowserController();
        const headlessSetting = db.prepare('SELECT value FROM user_settings WHERE key = ? ORDER BY user_id LIMIT 1').get('headless_browser');
        if (headlessSetting) {
            const val = headlessSetting.value;
            browserController.headless = val !== 'false' && val !== false && val !== '0';
        }
        app.locals.browserController = browserController;

        const skillRunner = new SkillRunner();
        await skillRunner.loadSkills();
        app.locals.skillRunner = skillRunner;

        const learningManager = new LearningManager(skillRunner, io);
        app.locals.learningManager = learningManager;

        const agentEngine = new AgentEngine(io, {
            memoryManager,
            mcpClient,
            browserController,
            messagingManager: null,
            skillRunner,
            learningManager
        });
        app.locals.agentEngine = agentEngine;

        const multiStep = new MultiStepOrchestrator(agentEngine, io);
        app.locals.multiStep = multiStep;

        const messagingManager = new MessagingManager(io);
        app.locals.messagingManager = messagingManager;
        agentEngine.messagingManager = messagingManager;

        messagingManager.restoreConnections().catch(err => console.error('[Messaging] Restore error:', err.message));

        const users = db.prepare('SELECT id FROM users').all();
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

        setupWebSocket(io, {
            agentEngine,
            messagingManager,
            mcpClient,
            scheduler,
            memoryManager,
            app
        });
        app.locals.io = io;

        console.log('All services initialized');
    } catch (err) {
        console.error('Service init error:', err);
    }
}

async function stopServices(app) {
    const tasks = [];

    if (app.locals.scheduler) {
        try {
            app.locals.scheduler.stop();
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

    if (app.locals.messagingManager?.platforms instanceof Map) {
        for (const platform of app.locals.messagingManager.platforms.values()) {
            if (typeof platform.disconnect === 'function') {
                tasks.push(
                    platform.disconnect().catch((err) => {
                        console.error('[Messaging] Disconnect error:', err.message);
                    }),
                );
            }
        }
    }

    await Promise.allSettled(tasks);
}

module.exports = { startServices, stopServices };
