const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');
const { listRunEvents } = require('../services/ai/runEvents');
const { isInterimAssistantMetadata } = require('../services/ai/interim');
const { buildAgentRunContext } = require('./_helpers/agentRunContext');

router.use(requireAuth);

const CHAT_HISTORY_DEFAULT_LIMIT = 40;
const CHAT_HISTORY_MAX_LIMIT = 100;

function normalizedTimestampExpression(valueSql) {
  return `julianday(CASE WHEN instr(${valueSql}, 'T') > 0 THEN ${valueSql} ELSE replace(${valueSql}, ' ', 'T') || 'Z' END)`;
}

function normalizeChatHistoryLimit(rawLimit) {
  const parsed = Number.parseInt(rawLimit, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return CHAT_HISTORY_DEFAULT_LIMIT;
  }
  return Math.min(parsed, CHAT_HISTORY_MAX_LIMIT);
}

function parseChatHistoryCursor(query) {
  const createdAt = query.beforeCreatedAt?.toString().trim() || '';
  const source = query.beforeSource?.toString().trim() || '';
  const id = query.beforeId?.toString().trim() || '';
  if (!createdAt || !source || !id) {
    return null;
  }
  return { createdAt, source, id };
}

function chatHistoryTimestampMs(value) {
  if (!value) return 0;
  const normalized = value.includes('T') ? value : `${value.replace(' ', 'T')}Z`;
  const parsed = new Date(normalized).getTime();
  return Number.isFinite(parsed) ? parsed : 0;
}

function compareChatHistoryDesc(left, right) {
  const timestampDiff =
    chatHistoryTimestampMs(right.created_at) - chatHistoryTimestampMs(left.created_at);
  if (timestampDiff !== 0) {
    return timestampDiff;
  }
  const sourceDiff = String(right.history_source || '').localeCompare(
    String(left.history_source || '')
  );
  if (sourceDiff !== 0) {
    return sourceDiff;
  }
  return String(right.id || '').localeCompare(String(left.id || ''));
}

function buildRunUsageSummary(runId) {
  const rows = db.prepare(`
    SELECT
      provider,
      model,
      phase,
      input_tokens,
      output_tokens,
      reasoning_tokens,
      cached_read_tokens,
      cache_write_tokens,
      total_tokens,
      estimated_cost_usd,
      latency_ms
    FROM agent_model_usage
    WHERE run_id = ?
    ORDER BY id ASC
  `).all(runId);
  const totals = {
    inputTokens: 0,
    outputTokens: 0,
    reasoningTokens: 0,
    cachedReadTokens: 0,
    cacheWriteTokens: 0,
    totalTokens: 0,
    estimatedCostUsd: 0,
    pricedCallCount: 0,
    latencyMs: 0,
  };
  const models = new Map();

  for (const row of rows) {
    const inputTokens = Number(row.input_tokens || 0);
    const outputTokens = Number(row.output_tokens || 0);
    const reasoningTokens = Number(row.reasoning_tokens || 0);
    const cachedReadTokens = Number(row.cached_read_tokens || 0);
    const cacheWriteTokens = Number(row.cache_write_tokens || 0);
    const totalTokens = Number(row.total_tokens || 0);
    const latencyMs = Number(row.latency_ms || 0);
    const estimatedCostUsd = Number(row.estimated_cost_usd);
    const key = `${row.provider}:${row.model}`;

    totals.inputTokens += inputTokens;
    totals.outputTokens += outputTokens;
    totals.reasoningTokens += reasoningTokens;
    totals.cachedReadTokens += cachedReadTokens;
    totals.cacheWriteTokens += cacheWriteTokens;
    totals.totalTokens += totalTokens;
    totals.latencyMs += latencyMs;
    if (Number.isFinite(estimatedCostUsd)) {
      totals.estimatedCostUsd += estimatedCostUsd;
      totals.pricedCallCount += 1;
    }

    if (!models.has(key)) {
      models.set(key, {
        provider: row.provider,
        model: row.model,
        callCount: 0,
        inputTokens: 0,
        outputTokens: 0,
        reasoningTokens: 0,
        cachedReadTokens: 0,
        cacheWriteTokens: 0,
        totalTokens: 0,
        estimatedCostUsd: 0,
        pricedCallCount: 0,
        latencyMs: 0,
        phases: new Set(),
      });
    }

    const aggregate = models.get(key);
    aggregate.callCount += 1;
    aggregate.inputTokens += inputTokens;
    aggregate.outputTokens += outputTokens;
    aggregate.reasoningTokens += reasoningTokens;
    aggregate.cachedReadTokens += cachedReadTokens;
    aggregate.cacheWriteTokens += cacheWriteTokens;
    aggregate.totalTokens += totalTokens;
    aggregate.latencyMs += latencyMs;
    aggregate.phases.add(String(row.phase || '').trim() || 'model_turn');
    if (Number.isFinite(estimatedCostUsd)) {
      aggregate.estimatedCostUsd += estimatedCostUsd;
      aggregate.pricedCallCount += 1;
    }
  }

  return {
    totals: {
      ...totals,
      estimatedCostUsd: totals.pricedCallCount > 0 ? totals.estimatedCostUsd : null,
    },
    models: [...models.values()].map((entry) => ({
      ...entry,
      estimatedCostUsd: entry.pricedCallCount > 0 ? entry.estimatedCostUsd : null,
      phases: [...entry.phases],
    })),
  };
}

// List agent runs
router.get('/', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200);
  const offset = parseInt(req.query.offset) || 0;
  const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
  const runs = db.prepare('SELECT * FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?')
    .all(req.session.userId, agentId, limit, offset);
  const total = db.prepare('SELECT COUNT(*) as count FROM agent_runs WHERE user_id = ? AND agent_id = ?').get(req.session.userId, agentId).count;
  res.json({ runs, total, limit, offset, agentId });
});

// Chat history (web + social messages merged)
router.get('/chat-history', (req, res) => {
  const limit = normalizeChatHistoryLimit(req.query.limit);
  const queryLimit = limit + 1;
  const userId = req.session.userId;
  const agentId = resolveAgentId(userId, getAgentIdFromRequest(req));
  const cursor = parseChatHistoryCursor(req.query);
  const cursorTimestampSql = normalizedTimestampExpression('@beforeCreatedAt');
  const historyTimestampSql = normalizedTimestampExpression('created_at');
  const cursorClause = (sourceName) =>
    cursor
      ? `AND (
        ${historyTimestampSql} < ${cursorTimestampSql}
        OR (${historyTimestampSql} = ${cursorTimestampSql} AND '${sourceName}' < @beforeSource)
        OR (${historyTimestampSql} = ${cursorTimestampSql} AND '${sourceName}' = @beforeSource AND CAST(id AS TEXT) < @beforeId)
      )`
      : '';
  const queryParams = cursor
    ? {
        userId,
        agentId,
        limit: queryLimit,
        beforeCreatedAt: cursor.createdAt,
        beforeSource: cursor.source,
        beforeId: cursor.id,
      }
    : { userId, agentId, limit: queryLimit };

  const webMsgs = db.prepare(`
    SELECT
      id,
      role,
      content,
      COALESCE(json_extract(metadata, '$.platform'), 'web') AS platform,
      NULL AS sender_name,
      created_at,
      agent_run_id AS run_id,
      metadata,
      NULL AS tool_calls,
      'conversation' AS history_source
    FROM conversation_history
    WHERE user_id = @userId AND agent_id = @agentId
    ${cursorClause('conversation')}
    ORDER BY ${historyTimestampSql} DESC, CAST(id AS TEXT) DESC
    LIMIT @limit
  `).all(queryParams);

  const socialMsgs = db.prepare(`
    SELECT
      id,
      role,
      content,
      platform,
      json_extract(metadata, '$.senderName') AS sender_name,
      created_at,
      run_id,
      metadata,
      tool_calls,
      'message' AS history_source
    FROM messages
    WHERE user_id = @userId AND agent_id = @agentId AND platform != 'web'
    ${cursorClause('message')}
    ORDER BY ${historyTimestampSql} DESC, CAST(id AS TEXT) DESC
    LIMIT @limit
  `).all(queryParams);

  const merged = [...webMsgs, ...socialMsgs].sort(compareChatHistoryDesc);
  const page = merged.slice(0, limit);
  const oldest = page.length > 0 ? page[page.length - 1] : null;

  res.json({
    messages: [...page].reverse(),
    agentId,
    hasMore: merged.length > limit,
    nextBeforeCreatedAt: oldest?.created_at || null,
    nextBeforeSource: oldest?.history_source || null,
    nextBeforeId: oldest?.id?.toString() || null,
  });
});

// Create new agent run
router.post('/', async (req, res) => {
  try {
    const { task, options } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    if (!task || typeof task !== 'string') return res.status(400).json({ error: 'Task must be a non-empty string' });
    if (task.length > 50000) return res.status(400).json({ error: 'Task exceeds maximum length of 50,000 characters' });

    const commandRouter = req.app?.locals?.commandRouter;
    if (commandRouter) {
      const commandResult = await commandRouter.dispatch(task, {
        userId: req.session.userId,
        agentId,
        source: 'http'
      });
      if (commandResult?.handled) {
        return res.json({
          command: true,
          content: commandResult.content || 'Done.',
          events: commandResult.events || []
        });
      }
    }

    db.prepare('INSERT INTO conversation_history (user_id, agent_id, role, content, metadata) VALUES (?, ?, ?, ?, ?)')
      .run(req.session.userId, agentId, 'user', task, JSON.stringify({ platform: 'flutter' }));

    const engine = req.app?.locals?.agentEngine;
    const memoryManager = req.app?.locals?.memoryManager;
    if (!engine || !memoryManager) {
      return res.status(500).json({ error: 'Agent engine or memory manager is not initialized.' });
    }
    const conversationId = options?.conversationId || memoryManager.getDefaultWebConversationId(req.session.userId, { agentId });
    const { priorMessages, priorSummary } = buildAgentRunContext({
      userId: req.session.userId,
      agentId,
      task,
    });
    const result = await engine.run(req.session.userId, task, {
      ...(options || {}),
      agentId,
      conversationId,
      priorMessages,
      priorSummary,
    });

    if (result?.status === 'completed' && result?.content) {
      db.prepare('INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, ?, ?, ?)')
        .run(
          req.session.userId,
          agentId,
          result.runId,
          'assistant',
          result.content,
          JSON.stringify({ tokens: result.totalTokens, platform: 'flutter' })
        );
    }

    res.json(result);
  } catch (err) {
    console.error('[Agents] Run failed:', err?.stack || err);
    res.status(err?.statusCode || err?.status || 500).json({
      error: sanitizeError(err),
      code: err?.code,
      rateLimit: err?.rateLimit,
    });
  }
});

// Get specific run
router.get('/:id', (req, res) => {
  const run = db.prepare('SELECT * FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!run) return res.status(404).json({ error: 'Run not found' });

  const steps = db.prepare('SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC').all(run.id);
  const history = db.prepare('SELECT * FROM conversation_history WHERE agent_run_id = ? ORDER BY created_at ASC').all(run.id);
  const usage = buildRunUsageSummary(run.id);

  res.json({ run, steps, history, usage });
});

// Get detailed steps for a run (for activity history replay)
router.get('/:id/steps', (req, res) => {
  const run = db.prepare('SELECT * FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!run) return res.status(404).json({ error: 'Run not found' });

  const steps = db.prepare('SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC').all(run.id);
  const historyRows = db.prepare(
    `SELECT content, metadata FROM conversation_history WHERE user_id = ? AND agent_run_id = ? AND role = 'assistant' ORDER BY created_at ASC`
  ).all(req.session.userId, run.id);
  const latestHistoryAssistant = [...historyRows].reverse().find((row) => String(row?.content || '').trim());
  const historyResponse = [...historyRows]
    .reverse()
    .find((row) => !isInterimAssistantMetadata(row?.metadata));
  const sentMessages = db.prepare(
    `SELECT content, metadata FROM messages WHERE user_id = ? AND run_id = ? AND role = 'assistant' ORDER BY created_at ASC, id ASC`
  ).all(req.session.userId, run.id);
  const latestSentAssistant = [...sentMessages]
    .reverse()
    .find((row) => String(row?.content || '').trim());
  const sentResponse = sentMessages
    .filter((row) => !isInterimAssistantMetadata(row?.metadata))
    .map((row) => row?.content?.toString().trim() || '')
    .filter(Boolean)
    .join('\n\n');
  const response =
    sentResponse
    || historyResponse?.content
    || latestSentAssistant?.content
    || latestHistoryAssistant?.content
    || run.final_response
    || null;
  const usage = buildRunUsageSummary(run.id);

  res.json({ run, steps, events: listRunEvents(run.id), response, usage });
});

// Abort a run
router.post('/:id/abort', (req, res) => {
  try {
    const run = db.prepare('SELECT id FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!run) return res.status(404).json({ error: 'Run not found' });
    const engine = req.app.locals.agentEngine;
    engine.abort(req.params.id, { userId: req.session.userId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Delete a run
router.delete('/:id', (req, res) => {
  const run = db.prepare('SELECT id FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!run) return res.status(404).json({ error: 'Run not found' });

  db.prepare('DELETE FROM agent_steps WHERE run_id = ?').run(run.id);
  db.prepare('DELETE FROM conversation_history WHERE agent_run_id = ?').run(run.id);
  db.prepare('DELETE FROM agent_runs WHERE id = ?').run(run.id);
  res.json({ success: true });
});

// Multi-step task
router.post('/multi-step', async (req, res) => {
  try {
    const { task, steps, options } = req.body;
    const agentId = resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    if (!task || typeof task !== 'string') return res.status(400).json({ error: 'Task must be a non-empty string' });
    if (task.length > 50000) return res.status(400).json({ error: 'Task exceeds maximum length of 50,000 characters' });

    const multiStep = req.app.locals.multiStep;
    if (!multiStep || typeof multiStep.planAndExecute !== 'function') {
      return res.status(500).json({ error: 'Multi-step orchestrator is not initialized.' });
    }
    const result = await multiStep.planAndExecute(req.session.userId, task, {
      ...(options || {}),
      agentId,
      requestedSteps: Array.isArray(steps) ? steps : [],
      forceMode: 'plan_execute',
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
