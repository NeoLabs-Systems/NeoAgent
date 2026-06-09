const db = require('../db/database');
const { sanitizeError } = require('../utils/security');
const { listRunEvents } = require('./ai/runEvents');
const { resolveAgentId } = require('./agents/manager');

const MAX_VOICE_SCREENSHOT_BYTES = 3 * 1024 * 1024;
const MAX_VOICE_SCREENSHOT_BASE64_CHARS =
  Math.ceil((MAX_VOICE_SCREENSHOT_BYTES * 4) / 3) + 8;
const MAX_VOICE_AUDIO_CHUNK_BYTES = 512 * 1024;
const MAX_VOICE_AUDIO_CHUNK_BASE64_CHARS =
  Math.ceil((MAX_VOICE_AUDIO_CHUNK_BYTES * 4) / 3) + 8;
const MAX_AGENT_TASK_CHARS = 50000;
const MAX_MESSAGE_CHARS = 12000;
const MAX_QUERY_CHARS = 2000;
const DEFAULT_RATE_LIMIT_WINDOW_MS = 10 * 1000;
const DEFAULT_RATE_LIMIT_MAX = 30;
const RATE_LIMIT_OBSERVER_ENTRY_TTL_MS = 10 * 60 * 1000;
const EVENT_RATE_LIMITS = Object.freeze({
  'agent:run': { windowMs: 15 * 1000, max: 4 },
  'agent:abort': { windowMs: 10 * 1000, max: 20 },
  'agent:history': { windowMs: 10 * 1000, max: 30 },
  'agent:run_detail': { windowMs: 10 * 1000, max: 30 },
  'messaging:connect': { windowMs: 10 * 1000, max: 10 },
  'messaging:disconnect': { windowMs: 10 * 1000, max: 10 },
  'messaging:send': { windowMs: 10 * 1000, max: 20 },
  'messaging:status': { windowMs: 10 * 1000, max: 40 },
  'voice:session_open': { windowMs: 10 * 1000, max: 10 },
  'voice:input_start': { windowMs: 10 * 1000, max: 20 },
  'voice:audio_chunk': { windowMs: 1000, max: 40 },
  'voice:input_commit': { windowMs: 10 * 1000, max: 10 },
  'voice:interrupt': { windowMs: 10 * 1000, max: 20 },
  'voice:session_close': { windowMs: 10 * 1000, max: 20 },
  'mcp:status': { windowMs: 10 * 1000, max: 20 },
  'mcp:tools': { windowMs: 10 * 1000, max: 20 },
  'integrations:status': { windowMs: 10 * 1000, max: 20 },
  'memory:read': { windowMs: 10 * 1000, max: 20 },
  'memory:search': { windowMs: 10 * 1000, max: 20 },
  'stream:subscribe': { windowMs: 10 * 1000, max: 40 },
  'stream:unsubscribe': { windowMs: 10 * 1000, max: 40 },
});

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function toOptionalString(value, maxLength = 512) {
  if (value == null) return '';
  const normalized = String(value).trim();
  if (!normalized) return '';
  return normalized.slice(0, maxLength);
}

function toBoundedInt(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

function normalizeStreamPayload(raw) {
  const data = asObject(raw);
  const platform = toOptionalString(data?.platform, 32).toLowerCase() || 'desktop';
  if (!['desktop', 'android', 'browser'].includes(platform)) {
    throw new Error('platform must be desktop, android, or browser.');
  }
  const deviceId = toOptionalString(data?.deviceId || data?.device_id, 256);
  return {
    platform,
    deviceId: deviceId || (platform === 'browser' ? 'browser' : ''),
  };
}

function resolveAgentFromPayload(userId, value) {
  const data = asObject(value);
  return resolveAgentId(userId, data?.agentId || data?.agent_id || null);
}

function createSocketRateLimiter() {
  const state = new Map();
  return (eventName) => {
    const config = EVENT_RATE_LIMITS[eventName] || {
      windowMs: DEFAULT_RATE_LIMIT_WINDOW_MS,
      max: DEFAULT_RATE_LIMIT_MAX,
    };
    const now = Date.now();
    const current = state.get(eventName);
    if (!current || now - current.windowStart >= config.windowMs) {
      state.set(eventName, { windowStart: now, count: 1 });
      return { allowed: true, retryAfterMs: 0 };
    }
    if (current.count >= config.max) {
      return {
        allowed: false,
        retryAfterMs: Math.max(1, config.windowMs - (now - current.windowStart)),
      };
    }
    current.count += 1;
    return { allowed: true, retryAfterMs: 0 };
  };
}

function createRateLimitObserver() {
  const byEvent = new Map();
  const byUserEvent = new Map();

  function record({ userId, socketId, eventName, retryAfterMs }) {
    const now = Date.now();
    const event = String(eventName || 'unknown');
    const user = String(userId || 'unknown');
    const key = `${user}:${event}`;

    const eventStats = byEvent.get(event) || { count: 0, lastAt: 0 };
    eventStats.count += 1;
    eventStats.lastAt = now;
    byEvent.set(event, eventStats);

    const userStats = byUserEvent.get(key) || {
      userId: user,
      eventName: event,
      count: 0,
      lastAt: 0,
      lastRetryAfterMs: 0,
      socketId: null,
    };
    userStats.count += 1;
    userStats.lastAt = now;
    userStats.lastRetryAfterMs = Number(retryAfterMs) || 0;
    userStats.socketId = socketId || null;
    byUserEvent.set(key, userStats);

    // Opportunistic cleanup to keep memory bounded over long uptime.
    if (byUserEvent.size > 500) {
      const cutoff = now - RATE_LIMIT_OBSERVER_ENTRY_TTL_MS;
      for (const [entryKey, stats] of byUserEvent.entries()) {
        if (!stats.lastAt || stats.lastAt < cutoff) {
          byUserEvent.delete(entryKey);
        }
      }
    }

    console.warn('[WS] rate_limit_exceeded', {
      userId: user,
      socketId: socketId || null,
      eventName: event,
      retryAfterMs: Number(retryAfterMs) || 0,
      occurredAt: new Date(now).toISOString(),
    });
  }

  function snapshot() {
    return {
      generatedAt: new Date().toISOString(),
      totalsByEvent: Array.from(byEvent.entries()).map(([eventName, stats]) => ({
        eventName,
        count: stats.count,
        lastAt: stats.lastAt ? new Date(stats.lastAt).toISOString() : null,
      })),
      recentByUserEvent: Array.from(byUserEvent.values())
        .sort((a, b) => b.lastAt - a.lastAt)
        .slice(0, 200)
        .map((entry) => ({
          userId: entry.userId,
          eventName: entry.eventName,
          count: entry.count,
          lastRetryAfterMs: entry.lastRetryAfterMs,
          socketId: entry.socketId,
          lastAt: entry.lastAt ? new Date(entry.lastAt).toISOString() : null,
        })),
    };
  }

  return { record, snapshot };
}

function recordRateLimitHit(observer, userId, socketId, eventName, retryAfterMs) {
  observer.record({ userId, socketId, eventName, retryAfterMs });
}

function setupWebSocket(io, services) {
  const { agentEngine, messagingManager, mcpClient, taskRuntime, memoryManager, voiceRuntimeManager } = services;
  const rateLimitObserver = createRateLimitObserver();
  const integrationManager =
    services.integrationManager || services.app?.locals?.integrationManager || null;
  if (services.app?.locals) {
    services.app.locals.getWebsocketRateLimitSnapshot = () => rateLimitObserver.snapshot();
  }
  io.on('connection', (socket) => {
    const allowEvent = createSocketRateLimiter();
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

    socket.on('agent:run', async (raw) => {
      const limit = allowEvent('agent:run');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'agent:run', limit.retryAfterMs);
        return socket.emit('run:error', {
          error: `Rate limit exceeded for agent:run. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const options = asObject(data.options);
        const task = typeof data.task === 'string' ? data.task : '';
        const agentId = resolveAgentFromPayload(userId, {
          ...options,
          agentId: data?.agentId,
        });
        console.log(`[WS] agent:run received from user ${userId}`, {
          socketId: socket.id,
          hasOptions: Boolean(options),
          taskLength: typeof task === 'string' ? task.length : null
        });
        if (!task || typeof task !== 'string') {
          console.warn(`[WS] agent:run rejected for user ${userId}: invalid task payload`);
          return socket.emit('error', { message: 'Task must be a non-empty string' });
        }
        if (task.length > MAX_AGENT_TASK_CHARS) {
          console.warn(`[WS] agent:run rejected for user ${userId}: task too long (${task.length})`);
          return socket.emit('error', { message: `Message too long (max ${MAX_AGENT_TASK_CHARS.toLocaleString()} characters)` });
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

    socket.on('agent:abort', (raw) => {
      const limit = allowEvent('agent:abort');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'agent:abort', limit.retryAfterMs);
        return socket.emit('error', {
          message: `Rate limit exceeded for agent:abort. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const runId = toOptionalString(data?.runId, 128);
        console.warn(`[WS] agent:abort received from user ${userId} for run ${runId || 'unknown'}`);
        agentEngine.abort(runId || null, { userId });
        socket.emit('agent:aborted', { runId: runId || null });
      } catch (err) {
        console.error(`[WS] agent:abort failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Conversation ──

    socket.on('agent:history', (raw) => {
      const limit = allowEvent('agent:history');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'agent:history', limit.retryAfterMs);
        return socket.emit('error', {
          message: `Rate limit exceeded for agent:history. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
        const queryLimit = toBoundedInt(data?.limit, 20, 1, 100);
        console.log(`[WS] agent:history requested by user ${userId} limit=${queryLimit}`);
        const runs = db.prepare(
          'SELECT * FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ?'
        ).all(userId, agentId, queryLimit);
        socket.emit('agent:history', { agentId, runs });
      } catch (err) {
        console.error(`[WS] agent:history failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    socket.on('agent:run_detail', (raw) => {
      const limit = allowEvent('agent:run_detail');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'agent:run_detail', limit.retryAfterMs);
        return socket.emit('error', {
          message: `Rate limit exceeded for agent:run_detail. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const runId = toOptionalString(data?.runId, 128);
        if (!runId) {
          return socket.emit('error', { message: 'runId is required' });
        }
        console.log(`[WS] agent:run_detail requested by user ${userId} run=${runId}`);
        const run = db.prepare('SELECT * FROM agent_runs WHERE id = ? AND user_id = ?').get(runId, userId);
        if (!run) {
          // Don't leak steps/history/events for a run the user doesn't own:
          // agent_steps and run events are keyed only by run_id, so the run
          // ownership check is the sole authorization gate.
          return socket.emit('agent:run_detail', { run: null, steps: [], history: [], events: [] });
        }
        const steps = db.prepare('SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC').all(runId);
        const history = db.prepare('SELECT * FROM conversation_history WHERE agent_run_id = ? AND user_id = ? ORDER BY created_at ASC').all(runId, userId);
        const events = listRunEvents(runId);
        socket.emit('agent:run_detail', { run, steps, history, events });
      } catch (err) {
        console.error(`[WS] agent:run_detail failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Messaging ──

    socket.on('messaging:connect', async (raw) => {
      const limit = allowEvent('messaging:connect');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'messaging:connect', limit.retryAfterMs);
        return socket.emit('messaging:error', {
          error: `Rate limit exceeded for messaging:connect. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const platform = toOptionalString(data.platform, 64).toLowerCase();
        if (!platform) {
          return socket.emit('messaging:error', { error: 'platform is required' });
        }
        const agentId = resolveAgentFromPayload(userId, data);
        console.log(`[WS] messaging:connect requested by user ${userId} platform=${platform || 'unknown'}`);
        const result = await messagingManager.connectPlatform(userId, platform, asObject(data.config), { agentId });
        socket.emit('messaging:connect_result', result);
      } catch (err) {
        console.error(`[WS] messaging:connect failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:disconnect', async (raw) => {
      const limit = allowEvent('messaging:disconnect');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'messaging:disconnect', limit.retryAfterMs);
        return socket.emit('messaging:error', {
          error: `Rate limit exceeded for messaging:disconnect. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const platform = toOptionalString(data.platform, 64).toLowerCase();
        if (!platform) {
          return socket.emit('messaging:error', { error: 'platform is required' });
        }
        const agentId = resolveAgentFromPayload(userId, data);
        console.log(`[WS] messaging:disconnect requested by user ${userId} platform=${platform || 'unknown'}`);
        const result = await messagingManager.disconnectPlatform(userId, platform, { agentId });
        socket.emit('messaging:disconnect_result', result);
      } catch (err) {
        console.error(`[WS] messaging:disconnect failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:send', async (raw) => {
      const limit = allowEvent('messaging:send');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'messaging:send', limit.retryAfterMs);
        return socket.emit('messaging:error', {
          error: `Rate limit exceeded for messaging:send. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const platform = toOptionalString(data.platform, 64).toLowerCase();
        const to = toOptionalString(data.to, 512);
        const content = typeof data.content === 'string' ? data.content : '';
        if (!platform) {
          return socket.emit('messaging:error', { error: 'platform is required' });
        }
        if (!to) {
          return socket.emit('messaging:error', { error: 'recipient is required' });
        }
        if (!content || content.length > MAX_MESSAGE_CHARS) {
          return socket.emit('messaging:error', {
            error: `content must be 1-${MAX_MESSAGE_CHARS} characters`,
          });
        }
        const agentId = resolveAgentFromPayload(userId, data);
        console.log(`[WS] messaging:send requested by user ${userId}`, {
          platform,
          to,
          contentLength: content.length,
          hasMediaPath: Boolean(data?.mediaPath)
        });
        const result = await messagingManager.sendMessage(userId, platform, to, content, {
          agentId,
          mediaPath: toOptionalString(data.mediaPath, 1024),
        });
        socket.emit('messaging:sent', result);
      } catch (err) {
        console.error(`[WS] messaging:send failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    socket.on('messaging:status', (raw) => {
      const limit = allowEvent('messaging:status');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'messaging:status', limit.retryAfterMs);
        return socket.emit('messaging:error', {
          error: `Rate limit exceeded for messaging:status. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
        console.log(`[WS] messaging:status requested by user ${userId}`);
        const statuses = messagingManager.getAllStatuses(userId, { agentId });
        socket.emit('messaging:status', statuses);
      } catch (err) {
        console.error(`[WS] messaging:status failed for user ${userId}:`, err);
        socket.emit('messaging:error', { error: sanitizeError(err) });
      }
    });

    // ── Live Voice ──

    socket.on('voice:session_open', async (raw) => {
      const limit = allowEvent('voice:session_open');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'voice:session_open', limit.retryAfterMs);
        return socket.emit('voice:error', {
          error: `Rate limit exceeded for voice:session_open. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
        const sessionId = toOptionalString(data?.sessionId, 128);
        const session = await voiceRuntimeManager.openFlutterSession({
          userId,
          agentId,
          socket,
          sessionId: sessionId || null,
        });
        if (!socket.data.voiceSessionIds) {
          socket.data.voiceSessionIds = new Set();
        }
        socket.data.voiceSessionIds.add(session.id);
      } catch (err) {
        socket.emit('voice:error', { error: sanitizeError(err) });
      }
    });

    socket.on('voice:input_start', async (raw) => {
      const limit = allowEvent('voice:input_start');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'voice:input_start', limit.retryAfterMs);
        return socket.emit('voice:error', {
          error: `Rate limit exceeded for voice:input_start. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const sessionId = toOptionalString(data?.sessionId, 128);
        if (!sessionId) {
          return socket.emit('voice:error', { error: 'sessionId is required' });
        }
        await voiceRuntimeManager.beginInput(sessionId, {
          mimeType: toOptionalString(data?.mimeType, 128),
          turnId: toOptionalString(data?.turnId, 128),
        });
      } catch (err) {
        console.error(`[WS] voice:input_start failed for user ${userId}:`, err);
        socket.emit('voice:error', {
          sessionId: null,
          error: sanitizeError(err),
        });
      }
    });

    socket.on('voice:audio_chunk', async (raw) => {
      const limit = allowEvent('voice:audio_chunk');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'voice:audio_chunk', limit.retryAfterMs);
        return socket.emit('voice:error', {
          error: `Rate limit exceeded for voice:audio_chunk. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const sessionId = toOptionalString(data?.sessionId, 128);
        if (!sessionId) {
          return socket.emit('voice:error', { error: 'sessionId is required' });
        }
        const audioBase64 = toOptionalString(data?.audioBase64, MAX_VOICE_AUDIO_CHUNK_BASE64_CHARS + 16);
        if (!audioBase64 || audioBase64.length > MAX_VOICE_AUDIO_CHUNK_BASE64_CHARS) {
          return socket.emit('voice:error', {
            sessionId,
            error: `audio chunk is too large (max ${MAX_VOICE_AUDIO_CHUNK_BYTES} bytes)`,
          });
        }
        const audioBytes = Buffer.from(audioBase64, 'base64');
        if (!audioBytes.length || audioBytes.length > MAX_VOICE_AUDIO_CHUNK_BYTES) {
          return socket.emit('voice:error', {
            sessionId,
            error: `audio chunk is too large (max ${MAX_VOICE_AUDIO_CHUNK_BYTES} bytes)`,
          });
        }
        const turnId = toOptionalString(data?.turnId, 128);
        const sequence = toBoundedInt(data?.sequence, -1, -1, 1_000_000);
        if (!turnId) {
          return socket.emit('voice:error', {
            sessionId,
            error: 'turnId is required',
          });
        }
        if (sequence < 0) {
          return socket.emit('voice:error', {
            sessionId,
            error: 'sequence is required',
          });
        }
        const appendResult = await voiceRuntimeManager.appendInputAudio(sessionId, audioBytes, {
          mimeType: toOptionalString(data?.mimeType, 128),
          turnId,
          sequence,
        });
        socket.emit('voice:chunk_ack', {
          sessionId,
          turnId,
          sequence,
          receivedThrough: appendResult?.receivedThrough ?? sequence,
        });
      } catch (err) {
        console.error(`[WS] voice:audio_chunk failed for user ${userId}:`, err);
        socket.emit('voice:error', {
          sessionId: null,
          error: sanitizeError(err),
        });
      }
    });

    socket.on('voice:input_commit', async (raw) => {
      const limit = allowEvent('voice:input_commit');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'voice:input_commit', limit.retryAfterMs);
        return socket.emit('voice:error', {
          error: `Rate limit exceeded for voice:input_commit. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const sessionId = toOptionalString(data?.sessionId, 128);
        if (!sessionId) {
          return socket.emit('voice:error', { error: 'sessionId is required' });
        }
        const metadata = {};
        const screenshotBase64 = typeof data?.screenshotBase64 === 'string'
          ? data.screenshotBase64.trim()
          : '';
        if (screenshotBase64) {
          if (screenshotBase64.length > MAX_VOICE_SCREENSHOT_BASE64_CHARS) {
            console.warn(
              `[WS] voice:input_commit rejected oversized screenshot for user ${userId}: base64 length ${screenshotBase64.length}`
            );
            socket.emit('voice:error', {
                sessionId,
              error: 'Attached screenshot is too large (max 3 MB).',
            });
            return;
          }

          const screenshotBytes = Buffer.from(screenshotBase64, 'base64');
          if (!screenshotBytes.length || screenshotBytes.length > MAX_VOICE_SCREENSHOT_BYTES) {
            console.warn(
              `[WS] voice:input_commit rejected oversized screenshot for user ${userId}: decoded bytes ${screenshotBytes.length}`
            );
            socket.emit('voice:error', {
                sessionId,
              error: 'Attached screenshot is too large (max 3 MB).',
            });
            return;
          }

          metadata.screenshotBase64 = screenshotBase64;
          const screenshotMimeType = typeof data?.screenshotMimeType === 'string'
            ? data.screenshotMimeType.trim()
            : '';
          if (screenshotMimeType) {
            metadata.screenshotMimeType = screenshotMimeType;
          }
        }

        await voiceRuntimeManager.commitInput(sessionId, {
          turnId: toOptionalString(data?.turnId, 128),
          finalSequence: toBoundedInt(data?.finalSequence, -1, -1, 1_000_000),
          promptHint: toOptionalString(data?.promptHint, 2000),
          metadata,
        });
      } catch (err) {
        console.error(`[WS] voice:input_commit failed for user ${userId}:`, err);
        socket.emit('voice:error', {
          sessionId: null,
          error: sanitizeError(err),
        });
      }
    });

    socket.on('voice:interrupt', async (raw) => {
      const limit = allowEvent('voice:interrupt');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'voice:interrupt', limit.retryAfterMs);
        return socket.emit('voice:error', {
          error: `Rate limit exceeded for voice:interrupt. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const sessionId = toOptionalString(data?.sessionId, 128);
        if (!sessionId) {
          return socket.emit('voice:error', { error: 'sessionId is required' });
        }
        await voiceRuntimeManager.interruptSession(sessionId);
      } catch (err) {
        console.error(`[WS] voice:interrupt failed for user ${userId}:`, err);
        socket.emit('voice:error', {
          sessionId: null,
          error: sanitizeError(err),
        });
      }
    });

    socket.on('voice:session_close', async (raw) => {
      const limit = allowEvent('voice:session_close');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'voice:session_close', limit.retryAfterMs);
        return socket.emit('voice:error', {
          error: `Rate limit exceeded for voice:session_close. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const sessionId = toOptionalString(data?.sessionId, 128);
        if (!sessionId) {
          return socket.emit('voice:error', { error: 'sessionId is required' });
        }
        await voiceRuntimeManager.closeSession(sessionId, 'client_closed');
        socket.data.voiceSessionIds?.delete(sessionId);
      } catch (err) {
        console.error(`[WS] voice:session_close failed for user ${userId}:`, err);
        socket.emit('voice:error', {
          sessionId: null,
          error: sanitizeError(err),
        });
      }
    });

    // ── MCP ──

    socket.on('mcp:status', async (raw) => {
      const limit = allowEvent('mcp:status');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'mcp:status', limit.retryAfterMs);
        return socket.emit('mcp:error', {
          error: `Rate limit exceeded for mcp:status. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
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

    socket.on('mcp:tools', async (raw) => {
      const limit = allowEvent('mcp:tools');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'mcp:tools', limit.retryAfterMs);
        return socket.emit('mcp:error', {
          error: `Rate limit exceeded for mcp:tools. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
        const serverId = toOptionalString(data?.serverId, 256);
        console.log(`[WS] mcp:tools requested by user ${userId} server=${serverId || 'all'}`);
        const tools = serverId
          ? await mcpClient.listTools(serverId, userId)
          : mcpClient.getAllTools(userId, { agentId });
        socket.emit('mcp:tools', tools);
      } catch (err) {
        console.error(`[WS] mcp:tools failed for user ${userId}:`, err);
        socket.emit('mcp:error', { error: sanitizeError(err) });
      }
    });

    socket.on('integrations:status', (raw) => {
      const limit = allowEvent('integrations:status');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'integrations:status', limit.retryAfterMs);
        return socket.emit('error', {
          message: `Rate limit exceeded for integrations:status. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
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

    socket.on('memory:read', (raw) => {
      const limit = allowEvent('memory:read');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'memory:read', limit.retryAfterMs);
        return socket.emit('error', {
          message: `Rate limit exceeded for memory:read. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const agentId = resolveAgentFromPayload(userId, data);
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

    socket.on('memory:search', async (raw) => {
      const limit = allowEvent('memory:search');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'memory:search', limit.retryAfterMs);
        return socket.emit('error', {
          message: `Rate limit exceeded for memory:search. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const data = asObject(raw);
        const query = typeof data?.query === 'string' ? data.query.trim() : '';
        if (!query || query.length > MAX_QUERY_CHARS) {
          return socket.emit('error', {
            message: `query must be 1-${MAX_QUERY_CHARS} characters`,
          });
        }
        const agentId = resolveAgentFromPayload(userId, data);
        console.log(`[WS] memory:search requested by user ${userId}`, {
          queryLength: query.length
        });
        const results = await memoryManager.searchMemory(query, userId, { agentId });
        socket.emit('memory:search_results', results);
      } catch (err) {
        console.error(`[WS] memory:search failed for user ${userId}:`, err);
        socket.emit('error', { message: sanitizeError(err) });
      }
    });

    // ── Remote Control Streams ──

    socket.on('stream:subscribe', (raw) => {
      const limit = allowEvent('stream:subscribe');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'stream:subscribe', limit.retryAfterMs);
        return socket.emit('stream:error', {
          error: `Rate limit exceeded for stream:subscribe. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const streamHub = services.streamHub || services.app?.locals?.streamHub;
        if (!streamHub) throw new Error('Stream hub is unavailable.');
        const data = normalizeStreamPayload(raw);
        if (!data.deviceId) throw new Error('deviceId is required.');
        const subscriberCount = streamHub.subscribe(userId, data.deviceId, data.platform, socket.id);
        socket.emit('stream:subscribed', {
          platform: data.platform,
          deviceId: data.deviceId,
          subscriberCount,
        });
      } catch (err) {
        console.error(`[WS] stream:subscribe failed for user ${userId}:`, err);
        socket.emit('stream:error', { error: sanitizeError(err) });
      }
    });

    socket.on('stream:unsubscribe', async (raw) => {
      const limit = allowEvent('stream:unsubscribe');
      if (!limit.allowed) {
        recordRateLimitHit(rateLimitObserver, userId, socket.id, 'stream:unsubscribe', limit.retryAfterMs);
        return socket.emit('stream:error', {
          error: `Rate limit exceeded for stream:unsubscribe. Retry in ${Math.ceil(limit.retryAfterMs / 1000)}s.`,
        });
      }
      try {
        const streamHub = services.streamHub || services.app?.locals?.streamHub;
        if (!streamHub) throw new Error('Stream hub is unavailable.');
        const data = normalizeStreamPayload(raw);
        if (!data.deviceId) throw new Error('deviceId is required.');
        const subscriberCount = await streamHub.unsubscribe(userId, data.platform, data.deviceId, socket.id);
        socket.emit('stream:unsubscribed', {
          platform: data.platform,
          deviceId: data.deviceId,
          subscriberCount,
        });
      } catch (err) {
        console.error(`[WS] stream:unsubscribe failed for user ${userId}:`, err);
        socket.emit('stream:error', { error: sanitizeError(err) });
      }
    });

    // ── Disconnect ──

    socket.on('disconnect', () => {
      const streamHub = services.streamHub || services.app?.locals?.streamHub;
      if (streamHub && typeof streamHub.unsubscribeAll === 'function') {
        void streamHub.unsubscribeAll(socket.id).catch((err) => {
          console.error(`[WS] Failed to unsubscribe streams for socket ${socket.id}:`, err);
        });
      }
      if (!voiceRuntimeManager || typeof voiceRuntimeManager.closeSession !== 'function') {
        socket.data.voiceSessionIds?.clear?.();
        console.log(`[WS] User ${userId} disconnected (${socket.id})`);
        return;
      }
      const activeVoiceSessionIds = Array.from(socket.data.voiceSessionIds || []);
      for (const sessionId of activeVoiceSessionIds) {
        void voiceRuntimeManager.closeSession(sessionId, 'socket_disconnected').catch((err) => {
          console.error(`[WS] Failed to close voice session ${sessionId} after socket disconnect:`, err);
        });
      }
      socket.data.voiceSessionIds?.clear?.();
      console.log(`[WS] User ${userId} disconnected (${socket.id})`);
    });
  });
}

module.exports = { setupWebSocket };
