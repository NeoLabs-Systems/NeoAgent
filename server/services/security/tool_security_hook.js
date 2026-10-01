'use strict';

const { globalHooks } = require('../ai/hooks');
const { SAFE_TOOLS, getCategoryForTool } = require('./tool_categories');
const { isPermitted } = require('../access/permissions');
const { reviewToolCall } = require('./trust_policy');

// The hook runner skips a handler that throws. A security check that cannot
// decide must block instead, or every error becomes a bypass.
function failClosed(id, handler) {
  return async (ctx) => {
    try {
      return await handler(ctx);
    } catch (err) {
      console.error(`[ToolPolicy] ${id} failed for tool=${ctx?.toolName}: ${err.message}`);
      return {
        block: true,
        blocked_by: id,
        reason: `The tool "${ctx?.toolName}" could not be checked against the security policy, so it was not run.`,
      };
    }
  };
}

/**
 * Registers three before_tool_call hooks:
 *   Priority 1  — delegation check: block categories a manager has taken away
 *                 from this account. Ignores the user's own security mode, so
 *                 'allow_all' cannot bypass it.
 *   Priority 5  — policy check: block tools whose category is set to 'deny'.
 *   Priority 10 — approval gate: suspend the run until the owner decides. Asks
 *                 when the category policy says so, and when trust_policy
 *                 flags the call from the run's audience or taint.
 *
 * Reasons returned in { block: true, reason, blocked_by } are surfaced to the
 * model by engine.js so the AI can communicate them to the user naturally.
 */
function registerToolSecurityHooks(toolPolicyService, approvalGateService) {
  globalHooks.register('before_tool_call', failClosed('delegation', async ({ toolName, toolArgs, userId }) => {
    if (SAFE_TOOLS.has(toolName)) return;
    const category = getCategoryForTool(toolName, toolArgs ?? {});
    if (!category || isPermitted(userId, category)) return;
    console.info(`[ToolPolicy] Blocked tool=${toolName} user=${userId} category=${category} by delegation`);
    return {
      block: true,
      blocked_by: 'delegation',
      reason:
        `The tool "${toolName}" is turned off for this account by the person who manages it. ` +
        'The user cannot change this in their own settings; only their manager can.',
    };
  }), { priority: 1, id: 'tool-delegation-check' });

  globalHooks.register('before_tool_call', failClosed('policy', async ({ toolName, toolArgs, userId }) => {
    if (SAFE_TOOLS.has(toolName)) return;
    const mode = toolPolicyService.getSecurityMode(userId);
    if (mode === 'allow_all') return;
    if (toolPolicyService.getPolicy(userId, toolName, toolArgs ?? {}) !== 'deny') return;
    console.info(`[ToolPolicy] Blocked tool=${toolName} user=${userId} mode=${mode} policy=deny`);
    return {
      block: true,
      blocked_by: 'policy',
      reason:
        `The tool "${toolName}" is disabled by your security policy. ` +
        `To use it, go to Settings → Tool Permissions and set the category to "Allow" or "Ask me".`,
    };
  }), { priority: 5, id: 'tool-policy-check' });

  globalHooks.register('before_tool_call', failClosed('approval', async ({ toolName, toolArgs, userId, runId, trust }) => {
    const args = toolArgs ?? {};
    const mode = toolPolicyService.getSecurityMode(userId);
    const category = getCategoryForTool(toolName, args);
    const review = reviewToolCall({ toolName, toolArgs: args, category, trust });
    const escalation = review && (review.kind === 'audience' || mode !== 'allow_all') ? review : null;

    if (!escalation) {
      if (SAFE_TOOLS.has(toolName) || mode === 'allow_all') return;
      const policy = toolPolicyService.getPolicy(userId, toolName, args);
      const askAnyway = mode === 'always_ask' && Boolean(category);
      if (policy !== 'require_approval' && !askAnyway) return;
    }

    if (approvalGateService.hasSessionGrant(userId, runId, toolName)) return;

    console.info(`[ToolPolicy] Requesting approval tool=${toolName} run=${runId}${escalation ? ` (${escalation.kind})` : ''}`);
    const decision = await approvalGateService.requestApproval(
      userId, runId, toolName, args, { reason: escalation?.reason || null },
    );
    if (decision === 'approved') return;

    const isTimeout = decision === 'timeout';
    const isExpired = decision === 'expired';
    return {
      block: true,
      blocked_by: isExpired
        ? 'approval_expired'
        : (isTimeout ? 'approval_timeout' : 'user_denied'),
      reason: isExpired
        ? `Approval for "${toolName}" expired because the server restarted or the run was interrupted. Do not retry unless the user explicitly asks you to try again.`
        : isTimeout
        ? `Approval for "${toolName}" timed out — the user did not respond within 30 seconds. ` +
          `Do not retry unless the user explicitly asks you to try again.`
        : `The user denied the use of "${toolName}". Do not retry this tool call in this run.`,
    };
  }), { priority: 10, id: 'tool-approval-gate' });
}

module.exports = { registerToolSecurityHooks };
