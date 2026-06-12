'use strict';

const db = require('../../db/database');

function finiteToken(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0;
}

function normalizeUsage(usage = {}) {
  if (!usage || typeof usage !== 'object') return null;
  const inputTokens = finiteToken(
    usage.inputTokens
    ?? usage.promptTokens
    ?? usage.input_tokens
    ?? usage.prompt_tokens,
  );
  const outputTokens = finiteToken(
    usage.outputTokens
    ?? usage.completionTokens
    ?? usage.output_tokens
    ?? usage.completion_tokens,
  );
  const reasoningTokens = finiteToken(
    usage.reasoningTokens
    ?? usage.reasoning_tokens
    ?? usage.output_tokens_details?.reasoning_tokens
    ?? usage.completion_tokens_details?.reasoning_tokens,
  );
  const cachedReadTokens = finiteToken(
    usage.cachedReadTokens
    ?? usage.cached_read_tokens
    ?? usage.cache_read_input_tokens
    ?? usage.prompt_tokens_details?.cached_tokens
    ?? usage.input_tokens_details?.cached_tokens
    ?? usage.cachedContentTokenCount,
  );
  const cacheWriteTokens = finiteToken(
    usage.cacheWriteTokens
    ?? usage.cache_write_tokens
    ?? usage.cache_creation_input_tokens,
  );
  const explicitTotal = finiteToken(usage.totalTokens ?? usage.total_tokens);
  const totalTokens = explicitTotal || inputTokens + outputTokens;
  return {
    inputTokens,
    outputTokens,
    reasoningTokens,
    cachedReadTokens,
    cacheWriteTokens,
    totalTokens,
  };
}

function mergeUsage(left, right) {
  const a = normalizeUsage(left) || normalizeUsage({});
  const b = normalizeUsage(right) || normalizeUsage({});
  return {
    inputTokens: a.inputTokens + b.inputTokens,
    outputTokens: a.outputTokens + b.outputTokens,
    reasoningTokens: a.reasoningTokens + b.reasoningTokens,
    cachedReadTokens: a.cachedReadTokens + b.cachedReadTokens,
    cacheWriteTokens: a.cacheWriteTokens + b.cacheWriteTokens,
    totalTokens: a.totalTokens + b.totalTokens,
  };
}

function recordModelUsage({
  runId,
  stepId = null,
  userId,
  agentId = null,
  provider,
  model,
  phase = 'model_turn',
  usage,
  latencyMs = 0,
  estimatedCostUsd = null,
  metadata = {},
}) {
  const normalized = normalizeUsage(usage);
  if (!runId || !userId || !provider || !model || !normalized) return null;
  const result = db.prepare(
    `INSERT INTO agent_model_usage (
      run_id, step_id, user_id, agent_id, provider, model, phase,
      input_tokens, output_tokens, reasoning_tokens, cached_read_tokens,
      cache_write_tokens, total_tokens, estimated_cost_usd, latency_ms, metadata_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    runId,
    stepId,
    userId,
    agentId,
    String(provider),
    String(model),
    String(phase),
    normalized.inputTokens,
    normalized.outputTokens,
    normalized.reasoningTokens,
    normalized.cachedReadTokens,
    normalized.cacheWriteTokens,
    normalized.totalTokens,
    Number.isFinite(Number(estimatedCostUsd)) ? Number(estimatedCostUsd) : null,
    Math.max(0, Math.floor(Number(latencyMs) || 0)),
    JSON.stringify(metadata && typeof metadata === 'object' ? metadata : {}),
  );
  return Number(result.lastInsertRowid);
}

module.exports = {
  mergeUsage,
  normalizeUsage,
  recordModelUsage,
};
