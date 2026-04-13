const db = require('../db/database');
const { sanitizeError } = require('../utils/security');
const { resolveAgentId } = require('./agents/manager');

function setupWebSocket(io, services) {
  const { agentEngine, messagingManager, mcpClient, scheduler, memoryManager, wearableManager } = services;
  const integrationManager =
    services.integrationManager || services.app?.locals?.integrationManager || null;
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
        const agentId = resolveAgentId(userId, options?.agentId || data?.agentId || null);
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

        const commandRouter = services.app?.locals?.commandRouter;
        if (commandRouter) {
          const commandResult = await commandRouter.dispatch(task, {
            userId,
            agentId,
            source: 'web',
            socketId: socket.id
          });
          if (commandResult?.handled) {
            if (Array.isArray(commandResult.events)) {
              for (const evt of commandResult.events) {
                socket.emit(evt.name, evt.payload || {});
              }
            }
            socket.emit('run:complete', { content: commandResult.content || 'Done.' });
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
            db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
              .run(
                userId,
                activeRun.agentId || agentId,
                activeRun.runId,
                'user',
                task,
                JSON.stringify({ platform: 'web', steering: true, agentId })
              );
            return;
          }
        }

        db.prepare('INSERT INTO conversation_history (user_id, agent_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
          .run(userId, agentId, 'user', task, JSON.stringify({ platform: 'web' }));

        const { ensureDefaultAiSettings, getAiSettings } = require('./ai/settings');
        const { getWebChatContext } = require('./ai/history');
        ensureDefaultAiSettings(userId, agentId);
        const aiSettings = getAiSettings(userId, agentId);
        const conversationId = options?.conversationId || memoryManager.getDefaultWebConversationId(userId, { agentId });
        const webContext = getWebChatContext(userId, aiSettings.chat_history_window, { agentId });
        const prior = webContext.recentMessages
          .filter((m) => !(m.role === 'user' && m.content === task))
          .slice(-aiSettings.chat_history_window);

        const result = await agentEngine.run(userId, task, {
          ...options,
          agentId,
          conversationId,
          priorMessages: prior,
          priorSummary: webContext.summary
        });
        console.log(`[WS] agent:run completed for user ${userId}`, {
          socketId: socket.id,
          runId: result?.runId || null,
          hasContent: Boolean(result?.content),
          totalTokens: result?.totalTokens || null
        });

        if (result?.status === 'completed' && result?.content) {
          db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
            .run(userId, agentId, result.runId, 'assistant', result.content, JSON.stringify({ tokens: result.totalTokens }));
        }
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
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] agent:history requested by user ${userId} limit=${data?.limit || 20}`);
        const runs = db.prepare(
          'SELECT * FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ?'
        ).all(userId, agentId, data?.limit || 20);
        socket.emit('agent:history', { agentId, runs });
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
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] messaging:connect requested by user ${userId} platform=${data?.platform || 'unknown'}`);
        const result = await messagingManager.connectPlatform(userId, data.platform, data.config || {}, { agentId });
        socket.emit('messaging:connect_result', result);
      } catch (err) {
        console.error(`[WS] messaging:connect failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:disconnect', async (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] messaging:disconnect requested by user ${userId} platform=${data?.platform || 'unknown'}`);
        const result = await messagingManager.disconnectPlatform(userId, data.platform, { agentId });
        socket.emit('messaging:disconnect_result', result);
      } catch (err) {
        console.error(`[WS] messaging:disconnect failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:send', async (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] messaging:send requested by user ${userId}`, {
          platform: data?.platform || 'unknown',
          to: data?.to || null,
          contentLength: typeof data?.content === 'string' ? data.content.length : null,
          hasMediaPath: Boolean(data?.mediaPath)
        });
        const result = await messagingManager.sendMessage(userId, data.platform, data.to, data.content, {
          agentId,
          mediaPath: data.mediaPath,
        });
        socket.emit('messaging:sent', result);
      } catch (err) {
        console.error(`[WS] messaging:send failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:status', (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] messaging:status requested by user ${userId}`);
        const statuses = messagingManager.getAllStatuses(userId, { agentId });
        socket.emit('messaging:status', statuses);
      } catch (err) {
        console.error(`[WS] messaging:status failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    // ── MCP ──

    socket.on('mcp:status', async (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] mcp:status requested by user ${userId}`);
        const status = await mcpClient.getStatus(userId, { agentId });
        socket.emit('mcp:status', status);
      } catch (err) {
        console.error(`[WS] mcp:status failed for user ${userId}:`, err);
        socket.emit('mcp:error', {
          message: 'Unable to fetch MCP status.',
          error: sanitizeError(err)
        });
      }
    });

    socket.on('mcp:tools', async (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] mcp:tools requested by user ${userId} server=${data?.serverId || 'all'}`);
        const tools = data?.serverId
          ? await mcpClient.listTools(data.serverId, userId)
          : mcpClient.getAllTools(userId, { agentId });
        socket.emit('mcp:tools', tools);
      } catch (err) {
        console.error(`[WS] mcp:tools failed for user ${userId}:`, err);
        socket.emit('mcp:error', { error: sanitizeError(err) });
      }
    });

    socket.on('integrations:status', (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] integrations:status requested by user ${userId}`);
        if (!integrationManager || typeof integrationManager.listProviders !== 'function') {
          throw new Error('Official integration manager is not available.');
        }
        socket.emit('integrations:status', integrationManager.listProviders(userId, agentId));
      } catch (err) {
        console.error(`[WS] integrations:status failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Memory ──

    socket.on('memory:read', (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] memory:read requested by user ${userId}`);
        socket.emit('memory:data', {
          agentId,
          // readMemory/listDailyLogs return user-scoped shared data (not agent-specific).
          memory: memoryManager.readMemory(userId),
          assistantBehaviorNotes: memoryManager.getAssistantBehaviorNotes(userId, { agentId }),
          dailyLogs: memoryManager.listDailyLogs(3, userId)
        });
      } catch (err) {
        console.error(`[WS] memory:read failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    socket.on('memory:search', async (data) => {
      try {
        const agentId = resolveAgentId(userId, data?.agentId || data?.agent_id || null);
        console.log(`[WS] memory:search requested by user ${userId}`, {
          queryLength: typeof data?.query === 'string' ? data.query.length : null
        });
        const results = await memoryManager.searchMemory(data?.query, userId, { agentId });
        socket.emit('memory:search_results', results);
      } catch (err) {
        console.error(`[WS] memory:search failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Wearables ──

    socket.on('wearables:list', async () => {
      try {
        console.log(`[WS] wearables:list requested by user ${userId}`);
        const devices = await wearableManager.listDevices(userId);
        socket.emit('wearables:list', devices);
      } catch (err) {
        console.error(`[WS] wearables:list failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    socket.on('wearables:protocols', () => {
      try {
        console.log(`[WS] wearables:protocols requested by user ${userId}`);
        const protocols = wearableManager.getProtocols();
        socket.emit('wearables:protocols', protocols);
      } catch (err) {
        console.error(`[WS] wearables:protocols failed for user ${userId}:`, err);
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
