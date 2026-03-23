const db = require('../db/database');
const { sanitizeError } = require('../utils/security');
const { getProviderForUser } = require('./ai/engine');
const { ensureDefaultAiSettings, getAiSettings } = require('./ai/settings');
const { getWebChatContext, refreshWebChatSummary, clearWebChatSummary } = require('./ai/history');

function setupWebSocket(io, services) {
  const { agentEngine, messagingManager, mcpClient, scheduler, memoryManager } = services;
  io.on('connection', (socket) => {
    const session = socket.request.session;
    if (!session?.userId) {
      console.warn(`[WS] Rejecting unauthenticated socket ${socket.id}`);
      socket.disconnect(true);
      return;
    }

    const userId = session.userId;
    socket.join(`user:${userId}`);

    console.log(`[WS] User ${userId} connected (${socket.id})`);

    // ── Agent Events ──

    socket.on('agent:run', async (data) => {
      try {
        const { task, options } = data;
        console.log(`[WS] agent:run received from user ${userId}`, {
          socketId: socket.id,
          hasOptions: Boolean(options),
          taskLength: typeof task === 'string' ? task.length : null
        });
        if (!task || typeof task !== 'string') {
          console.warn(`[WS] agent:run rejected for user ${userId}: invalid task payload`);
          return socket.emit('error', { message: 'Task must be a non-empty string' });
        }
        if (task.length > 50000) {
          console.warn(`[WS] agent:run rejected for user ${userId}: task too long (${task.length})`);
          return socket.emit('error', { message: 'Message too long (max 50,000 characters)' });
        }

        if (task.startsWith('/')) {
          const [rawCmd] = task.trim().split(/\s+/);
          const cmd = rawCmd.slice(1).toLowerCase();

          switch (cmd) {
            case 'new':
            case 'clear':
              db.prepare('DELETE FROM conversation_history WHERE user_id = ?').run(userId);
              clearWebChatSummary(userId);
              console.log(`[WS] Conversation cleared for user ${userId}`);
              socket.emit('chat:cleared');
              {
                const resetResult = await agentEngine.run(userId, 'context was just cleared. say something very brief (1-2 sentences max) acknowledging the fresh start, in your own style. no tools needed.', {});
                socket.emit('run:complete', { content: resetResult?.content || 'fresh start.' });
              }
              return;

            case 'stop': {
              console.warn(`[WS] Stop requested by user ${userId}`);
              agentEngine.abortAll(userId);
              const q = services.app?.locals?.userQueues;
              if (q && q[userId]) { q[userId].pending = []; q[userId].running = false; }
              socket.emit('run:complete', { content: 'Stopped.' });
              return;
            }

            case 'help':
              socket.emit('run:complete', {
                content: '**Available commands**\n- `/new` or `/clear` — clear conversation context\n- `/stop` — abort all running tasks immediately\n- `/help` — show this message'
              });
              return;

            default:
              socket.emit('run:complete', { content: `Unknown command: \`/${cmd}\`. Type \`/help\` for available commands.` });
              return;
          }
        }

        const activeRun = agentEngine.findSteerableRunForUser(userId, 'web');
        if (activeRun) {
          const queued = agentEngine.enqueueSteering(activeRun.runId, task, {
            platform: 'web',
            socketId: socket.id
          });
          if (queued) {
            db.prepare('INSERT INTO conversation_history (user_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
              .run(
                userId,
                activeRun.runId,
                'user',
                task,
                JSON.stringify({ platform: 'web', steering: true })
              );
            return;
          }
        }

        db.prepare('INSERT INTO conversation_history (user_id, role, content, metadata) VALUES (?, ?, ?, ?)')
          .run(userId, 'user', task, JSON.stringify({ platform: 'web' }));

        ensureDefaultAiSettings(userId);
        const aiSettings = getAiSettings(userId);
        const webContext = getWebChatContext(userId, aiSettings.chat_history_window);
        const prior = webContext.recentMessages.filter((m) => !(m.role === 'user' && m.content === task)).slice(-aiSettings.chat_history_window);

        const result = await agentEngine.run(userId, task, {
          ...options,
          priorMessages: prior,
          priorSummary: webContext.summary
        });
        console.log(`[WS] agent:run completed for user ${userId}`, {
          socketId: socket.id,
          runId: result?.runId || null,
          hasContent: Boolean(result?.content),
          totalTokens: result?.totalTokens || null
        });

        if (result?.content) {
          db.prepare('INSERT INTO conversation_history (user_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
            .run(userId, result.runId, 'assistant', result.content, JSON.stringify({ tokens: result.totalTokens }));
        }

        const { provider, model } = await getProviderForUser(userId, task, false, options?.model || null);
        refreshWebChatSummary(userId, provider, model, aiSettings.chat_history_window).catch((summaryErr) => {
          console.error('[WS] Web summary refresh failed:', summaryErr.message);
        });
      } catch (err) {
        console.error(`[WS] agent:run failed for user ${userId}:`, err);
        socket.emit('run:error', { error: sanitizeError(err) });
      }
    });

    socket.on('agent:abort', (data) => {
      try {
        console.warn(`[WS] agent:abort received from user ${userId} for run ${data?.runId || 'unknown'}`);
        agentEngine.abort(data?.runId);
        socket.emit('agent:aborted', { runId: data?.runId });
      } catch (err) {
        console.error(`[WS] agent:abort failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Conversation ──

    socket.on('agent:history', (data) => {
      try {
        console.log(`[WS] agent:history requested by user ${userId} limit=${data?.limit || 20}`);
        const runs = db.prepare(
          'SELECT * FROM agent_runs WHERE user_id = ? ORDER BY created_at DESC LIMIT ?'
        ).all(userId, data?.limit || 20);
        socket.emit('agent:history', runs);
      } catch (err) {
        console.error(`[WS] agent:history failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    socket.on('agent:run_detail', (data) => {
      try {
        console.log(`[WS] agent:run_detail requested by user ${userId} run=${data?.runId || 'unknown'}`);
        const run = db.prepare('SELECT * FROM agent_runs WHERE id = ? AND user_id = ?').get(data.runId, userId);
        const steps = db.prepare('SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC').all(data.runId);
        const history = db.prepare('SELECT * FROM conversation_history WHERE agent_run_id = ? ORDER BY created_at ASC').all(data.runId);
        socket.emit('agent:run_detail', { run, steps, history });
      } catch (err) {
        console.error(`[WS] agent:run_detail failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Messaging ──

    socket.on('messaging:connect', async (data) => {
      try {
        console.log(`[WS] messaging:connect requested by user ${userId} platform=${data?.platform || 'unknown'}`);
        const result = await messagingManager.connectPlatform(userId, data.platform, data.config || {});
        socket.emit('messaging:connect_result', result);
      } catch (err) {
        console.error(`[WS] messaging:connect failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:disconnect', async (data) => {
      try {
        console.log(`[WS] messaging:disconnect requested by user ${userId} platform=${data?.platform || 'unknown'}`);
        const result = await messagingManager.disconnectPlatform(userId, data.platform);
        socket.emit('messaging:disconnect_result', result);
      } catch (err) {
        console.error(`[WS] messaging:disconnect failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:send', async (data) => {
      try {
        console.log(`[WS] messaging:send requested by user ${userId}`, {
          platform: data?.platform || 'unknown',
          to: data?.to || null,
          contentLength: typeof data?.content === 'string' ? data.content.length : null,
          hasMediaPath: Boolean(data?.mediaPath)
        });
        const result = await messagingManager.sendMessage(userId, data.platform, data.to, data.content, data.mediaPath);
        socket.emit('messaging:sent', result);
      } catch (err) {
        console.error(`[WS] messaging:send failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:status', () => {
      try {
        console.log(`[WS] messaging:status requested by user ${userId}`);
        const statuses = messagingManager.getAllStatuses(userId);
        socket.emit('messaging:status', statuses);
      } catch (err) {
        console.error(`[WS] messaging:status failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    // ── MCP ──

    socket.on('mcp:status', () => {
      console.log(`[WS] mcp:status requested by user ${userId}`);
      socket.emit('mcp:status', mcpClient.getStatus(userId));
    });

    socket.on('mcp:tools', async (data) => {
      try {
        console.log(`[WS] mcp:tools requested by user ${userId} server=${data?.serverId || 'all'}`);
        const tools = data?.serverId
          ? await mcpClient.listTools(data.serverId, userId)
          : mcpClient.getAllTools(userId);
        socket.emit('mcp:tools', tools);
      } catch (err) {
        console.error(`[WS] mcp:tools failed for user ${userId}:`, err);
        socket.emit('mcp:error', { error: sanitizeError(err) });
      }
    });

    // ── Memory ──

    socket.on('memory:read', () => {
      console.log(`[WS] memory:read requested by user ${userId}`);
      socket.emit('memory:data', {
        memory: memoryManager.readMemory(userId),
        soul: memoryManager.readSoul(userId),
        dailyLogs: memoryManager.listDailyLogs(3, userId)
      });
    });

    socket.on('memory:search', async (data) => {
      try {
        console.log(`[WS] memory:search requested by user ${userId}`, {
          queryLength: typeof data?.query === 'string' ? data.query.length : null
        });
        const results = await memoryManager.searchMemory(data?.query, userId);
        socket.emit('memory:search_results', results);
      } catch (err) {
        console.error(`[WS] memory:search failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Disconnect ──

    socket.on('disconnect', () => {
      console.log(`[WS] User ${userId} disconnected (${socket.id})`);
    });
  });
}

module.exports = { setupWebSocket };
