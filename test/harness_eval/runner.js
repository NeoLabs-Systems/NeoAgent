'use strict';

const { createEvalEngine, createEvalRuntime } = require('./harness');
const {
  CANNED_TOOL_RESULTS,
  EVAL_SET_VERSION,
  LIVE_CASES,
  SCRIPTED_CASES,
} = require('./cases');
const { caseDeliveryViolations } = require('./invariants');

function summarize(results, extra = {}) {
  const runs = results.filter((entry) => entry.metrics);
  const total = (pick) => runs.reduce((sum, entry) => sum + (Number(pick(entry)) || 0), 0);
  const count = results.length;
  return {
    eval_set_version: EVAL_SET_VERSION,
    cases: count,
    passed: results.filter((entry) => entry.ok).length,
    success_rate: count ? Number((results.filter((entry) => entry.ok).length / count).toFixed(4)) : 0,
    duplicate_messages: results.reduce((sum, entry) => sum + (entry.duplicates || 0), 0),
    security_failures: results.reduce((sum, entry) => sum + (entry.securityFailures || 0), 0),
    delivery_violations: results.reduce((sum, entry) => sum + (entry.deliveryViolations?.length || 0), 0),
    repeated_tool_calls: results.reduce((sum, entry) => sum + (entry.repeatedCalls || 0), 0),
    unnecessary_tool_calls: results.reduce((sum, entry) => sum + (entry.unnecessaryCalls || 0), 0),
    turns_per_task: runs.length ? Number((total((entry) => entry.metrics.turns) / runs.length).toFixed(2)) : null,
    tokens_per_task: runs.length ? Math.round(total((entry) => entry.metrics.tokens?.total) / runs.length) : null,
    ...extra,
  };
}

function runMetricsFor(runtime, runId) {
  if (!runId) return null;
  const row = runtime.ctx.db.prepare('SELECT metrics_json FROM agent_runs WHERE id = ?').get(runId);
  return row?.metrics_json ? JSON.parse(row.metrics_json) : null;
}

// Security hooks are process-wide, so they are on for the eval and off after it.
function installPolicyGate({ approval = 'denied' } = {}) {
  const { globalHooks } = require('../../server/services/ai/hooks');
  const { registerToolSecurityHooks } = require('../../server/services/security/tool_security_hook');
  registerToolSecurityHooks(
    { getSecurityMode: () => 'default', getPolicy: () => 'allow' },
    { hasSessionGrant: () => false, requestApproval: async () => approval },
  );
  return () => {
    for (const id of ['tool-delegation-check', 'tool-policy-check', 'tool-approval-gate']) {
      globalHooks.deregister('before_tool_call', id);
    }
  };
}

async function runScriptedCases({ only = null } = {}) {
  const runtime = createEvalRuntime();
  const removeGate = installPolicyGate();
  const results = [];
  let lastOutboxRow = 0;
  try {
    for (const evalCase of SCRIPTED_CASES) {
      if (only && !only(evalCase)) continue;
      const user = await runtime.user();
      try {
        const outcome = await evalCase.run({ runtime, user });
        const { violations, lastRowId } = caseDeliveryViolations(runtime.ctx.db, lastOutboxRow);
        lastOutboxRow = lastRowId;
        results.push({
          id: evalCase.id,
          category: evalCase.category,
          ok: outcome.ok === true && violations.length === 0,
          deliveryViolations: violations,
          duplicates: outcome.duplicates || 0,
          securityFailures: outcome.securityFailures || 0,
          repeatedCalls: outcome.repeatedCalls || 0,
          detail: [outcome.detail, ...violations.map((entry) => entry.rule)].filter(Boolean).join(' '),
          metrics: runMetricsFor(runtime, outcome.result?.runId),
        });
      } catch (error) {
        results.push({ id: evalCase.id, category: evalCase.category, ok: false, detail: error?.message || String(error) });
      }
    }
  } finally {
    removeGate();
    runtime.teardown();
  }
  return { results, summary: summarize(results, { mode: 'scripted' }) };
}

function judgeLive(evalCase, { toolNames, content, status }) {
  // Keeping notes and asking for tools are how a run works, not what it chose to do.
  const chosen = toolNames.filter((name) => !['activate_tools', 'search_tools', 'task_ledger', 'send_interim_update'].includes(name));
  const { expect } = evalCase;
  if (status !== 'completed') return { ok: false, detail: `run ${status}` };
  if (expect.noTools && chosen.length) return { ok: false, unnecessaryCalls: chosen.length, detail: `called ${chosen.join(',')}` };
  if (expect.anyOf && !chosen.some((name) => expect.anyOf.includes(name))) return { ok: false, detail: `called ${chosen.join(',') || 'nothing'}` };
  const forbidden = (expect.forbid || []).filter((name) => toolNames.includes(name));
  if (forbidden.length) return { ok: false, securityFailures: forbidden.length, detail: `called ${forbidden.join(',')}` };
  if (expect.answerMatches && !expect.answerMatches.test(String(content || ''))) return { ok: false, detail: 'answer did not match' };
  return { ok: true, unnecessaryCalls: 0 };
}

/**
 * The same situations for a real model. `repeat` runs each case k times and the
 * case only passes if every run does: a harness that mostly works still feels
 * broken in daily use. Compare harness versions on the same model and settings,
 * or this measures the model instead.
 */
async function runLiveCases({ modelId = null, repeat = 1, only = null, env = {} } = {}) {
  const runtime = createEvalRuntime();
  Object.assign(process.env, env);
  const removeGate = installPolicyGate();
  const user = await runtime.user();
  const results = [];
  try {
    for (const evalCase of LIVE_CASES) {
      if (only && !only(evalCase)) continue;
      const attempts = [];
      for (let attempt = 0; attempt < repeat; attempt += 1) {
        const engine = createEvalEngine({ toolResults: { ...CANNED_TOOL_RESULTS, ...(evalCase.toolResults || {}) } });
        let run = null;
        try {
          run = await engine.run(user.userId, evalCase.request, {
            stream: false,
            skipGlobalRecall: true,
            skipConversationHistory: true,
            bypassUserRateLimits: true,
            triggerSource: 'web',
            maxIterations: 6,
            ...(modelId ? { model: modelId } : {}),
          });
          const verdict = judgeLive(evalCase, {
            toolNames: engine.toolCalls.map((call) => call.name),
            content: run.content,
            status: run.status,
          });
          attempts.push({ ...verdict, metrics: runMetricsFor(runtime, run.runId), tools: engine.toolCalls.map((call) => call.name) });
        } catch (error) {
          attempts.push({ ok: false, detail: error?.message || String(error), tools: engine.toolCalls.map((call) => call.name) });
        }
      }
      results.push({
        id: evalCase.id,
        category: evalCase.category,
        ok: attempts.every((entry) => entry.ok),
        passes: attempts.filter((entry) => entry.ok).length,
        attempts: attempts.length,
        securityFailures: attempts.reduce((sum, entry) => sum + (entry.securityFailures || 0), 0),
        unnecessaryCalls: attempts.reduce((sum, entry) => sum + (entry.unnecessaryCalls || 0), 0),
        detail: attempts.find((entry) => !entry.ok)?.detail || '',
        tools: attempts.map((entry) => entry.tools),
        metrics: attempts.find((entry) => entry.metrics)?.metrics || null,
      });
    }
  } finally {
    removeGate();
    runtime.teardown();
  }
  return {
    results,
    summary: summarize(results, {
      mode: 'live',
      model: modelId,
      pass_k: repeat,
    }),
  };
}

module.exports = {
  runLiveCases,
  runScriptedCases,
};
