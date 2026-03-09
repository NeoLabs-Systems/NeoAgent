'use strict';

const db = require('../db/database');
const { MemoryManager } = require('./memory/manager');
const { MCPClient } = require('./mcp/client');
const { BrowserController } = require('./browser/controller');
const { AgentEngine } = require('./ai/engine');
const { MultiStepOrchestrator } = require('./ai/multiStep');
const { MessagingManager } = require('./messaging/manager');
const { Scheduler } = require('./scheduler/cron');
const { setupWebSocket } = require('./websocket');
const { detectPromptInjection } = require('../utils/security');
const { randomUUID } = require('crypto');

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

        const agentEngine = new AgentEngine(io, { memoryManager, mcpClient, browserController, messagingManager: null });
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

        const userQueues = {};
        app.locals.userQueues = userQueues;

        async function processMessage(userId, msg) {
            if (!userQueues[userId]) userQueues[userId] = { running: false, pending: [] };
            const q = userQueues[userId];

            if (q.running) {
                const last = q.pending[q.pending.length - 1];
                if (last && last.platform === msg.platform && last.chatId === msg.chatId) {
                    last.content += '\n' + msg.content;
                    last.messageId = msg.messageId;
                } else {
                    q.pending.push({ ...msg });
                }
                return;
            }

            q.running = true;
            try {
                await messagingManager.markRead(userId, msg.platform, msg.chatId, msg.messageId).catch(() => { });
                await messagingManager.sendTyping(userId, msg.platform, msg.chatId, true).catch(() => { });

                const mediaNote = msg.localMediaPath
                    ? `\nMedia attached at: ${msg.localMediaPath} (type: ${msg.mediaType}). You can reference or forward it with send_message media_path.`
                    : '';

                if (detectPromptInjection(msg.content)) {
                    console.warn(`[Security] Possible prompt injection attempt from ${msg.sender} on ${msg.platform}: ${msg.content.slice(0, 200)}`);
                }

                const isVoiceCall = msg.platform === 'telnyx' && msg.mediaType === 'voice';
                const isVoiceNote = !isVoiceCall && msg.mediaType === 'audio';
                const isDiscordGuild = msg.platform === 'discord' && msg.isGroup;

                const discordContext = (isDiscordGuild && Array.isArray(msg.channelContext) && msg.channelContext.length)
                    ? '\n\nRecent channel context (oldest → newest):\n' +
                    msg.channelContext.map(m => `[${m.author}]: ${m.content}`).join('\n')
                    : '';

                const sttNote = isVoiceNote
                    ? '\n[Note: This message was sent as a voice note and transcribed via speech-to-text. The transcription may not be perfectly accurate.]'
                    : '';

                const prompt = isVoiceCall
                    ? `You are on a live phone call. The caller (${msg.senderName || msg.sender}) said:\n<caller_speech>\n${msg.content}\n</caller_speech>\n\nRespond via send_message with platform="telnyx" and to="${msg.chatId}".`
                    : `You received a ${msg.platform} message from ${msg.senderName || msg.sender} (chat: ${msg.chatId}):\n<external_message>\n${msg.content}\n</external_message>${mediaNote}${discordContext}${sttNote}\n\nReply via send_message with platform="${msg.platform}" and to="${msg.chatId}".`;

                let convRow = db.prepare(
                    'SELECT id FROM conversations WHERE user_id = ? AND platform = ? AND platform_chat_id = ?'
                ).get(userId, msg.platform, msg.chatId);

                if (!convRow) {
                    const convId = randomUUID();
                    db.prepare(
                        'INSERT INTO conversations (id, user_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?)'
                    ).run(convId, userId, msg.platform, msg.chatId, `${msg.platform} — ${msg.senderName || msg.sender || msg.chatId}`);
                    convRow = { id: convId };
                }

                const runOpts = { triggerSource: 'messaging', conversationId: convRow.id, source: msg.platform, chatId: msg.chatId, context: { rawUserMessage: msg.content } };
                if (msg.localMediaPath) runOpts.mediaAttachments = [{ path: msg.localMediaPath, type: msg.mediaType }];

                await agentEngine.run(userId, prompt, runOpts);
            } finally {
                await messagingManager.sendTyping(userId, msg.platform, msg.chatId, false).catch(() => { });
                q.running = false;
                if (q.pending.length > 0) {
                    const next = q.pending.shift();
                    processMessage(userId, next);
                }
            }
        }

        messagingManager.registerHandler(async (userId, msg) => {
            if (msg.platform !== 'discord' && msg.platform !== 'telegram') {
                const whitelistRow = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
                    .get(userId, `platform_whitelist_${msg.platform}`);
                if (whitelistRow) {
                    try {
                        const whitelist = JSON.parse(whitelistRow.value);
                        if (Array.isArray(whitelist) && whitelist.length > 0) {
                            const normalize = (id) => {
                                const digits = (id || '').replace(/[^0-9]/g, '');
                                return digits.length > 10 ? digits.slice(-10) : digits;
                            };
                            const senderNorm = normalize(msg.sender || msg.chatId);
                            const allowed = whitelist.some(n => normalize(n) === senderNorm);
                            if (!allowed) {
                                console.log(`[Messaging] Blocked ${msg.platform} message from ${msg.sender} (not in whitelist)`);
                                io.to(`user:${userId}`).emit('messaging:blocked_sender', {
                                    platform: msg.platform,
                                    sender: msg.sender,
                                    chatId: msg.chatId,
                                    senderName: msg.senderName || null
                                });
                                return;
                            }
                        }
                    } catch { }
                }
            }

            const upsertSetting = db.prepare('INSERT OR REPLACE INTO user_settings (user_id, key, value) VALUES (?, ?, ?)');
            upsertSetting.run(userId, 'last_platform', msg.platform);
            upsertSetting.run(userId, 'last_chat_id', msg.chatId);

            await processMessage(userId, msg);
        });

        const scheduler = new Scheduler(io, agentEngine);
        app.locals.scheduler = scheduler;
        agentEngine.scheduler = scheduler;
        scheduler.start();

        setupWebSocket(io, { agentEngine, messagingManager, mcpClient, scheduler, memoryManager, app });
        app.locals.io = io;

        console.log('All services initialized');
    } catch (err) {
        console.error('Service init error:', err);
    }
}

module.exports = { startServices };
