'use strict';

const { globalHooks } = require('../ai/hooks');
const { SAFE_TOOLS } = require('./tool_categories');

/**
 * Registers two before_tool_call hooks:
 *   Priority 5  — policy check: block tools whose category is set to 'deny';
 *                 respect the user's global security_mode override.
 *   Priority 10 — approval gate: suspend the run until the user approves/denies.
 *
 * Both hooks skip SAFE_TOOLS with a fast Set.has() check.
 *
 * Reasons returned in { block: true, reason, blocked_by } are surfaced to the
 * model by engine.js so the AI can communicate them to the user naturally.
 */
function registerToolSecurityHooks(toolPolicyService, approvalGateService) {
  // ── Hook 1: global mode + deny check (synchronous) ────────────────────────
  globalHooks.register('before_tool_call', async ({ toolName, toolArgs, userId }) => {
    if (SAFE_TOOLS.has(toolName)) return;

    const mode = toolPolicyService.getSecurityMode(userId);

    if (mode === 'allow_all') return; // user opted into full bypass

    const policy = toolPolicyService.getPolicy(userId, toolName, toolArgs ?? {});

    if (policy === 'deny') {
      console.info(`[ToolPolicy] Blocked tool=${toolName} user=${userId} mode=${mode} policy=deny`);
      return {
        block: true,
        blocked_by: 'policy',
        reason:
          `The tool "${toolName}" is disabled by your security policy. ` +
          `To use it, go to Settings → Tool Permissions and set the category to "Allow" or "Ask me".`,
      };
    }
  }, { priority: 5, id: 'tool-policy-check' });

  // ── Hook 2: approval gate (async, may suspend up to 30 s) ─────────────────
  globalHooks.register('before_tool_call', async ({ toolName, toolArgs, userId, runId }) => {
    if (SAFE_TOOLS.has(toolName)) return;

    const mode = toolPolicyService.getSecurityMode(userId);
    if (mode === 'allow_all') return;

    const policy = toolPolicyService.getPolicy(userId, toolName, toolArgs ?? {});

    // 'allow_always' and 'allow' are green-light with no interruption
    if (policy === 'allow' || policy === 'allow_always') return;

    // 'always_ask' mode forces approval even for categories set to 'allow'
    const needsApproval = policy === 'require_approval' || mode === 'always_ask';
    if (!needsApproval) return;

    if (approvalGateService.hasSessionGrant(userId, runId, toolName)) return;

    console.info(`[ToolPolicy] Requesting approval tool=${toolName} run=${runId}`);
    const decision = await approvalGateService.requestApproval(
      userId, runId, toolName, toolArgs ?? {}
    );

    if (decision === 'approved') return;

    const isTimeout = decision === 'timeout';
    return {
      block: true,
      blocked_by: isTimeout ? 'approval_timeout' : 'user_denied',
      reason: isTimeout
        ? `Approval for "${toolName}" timed out — the user did not respond within 30 seconds. ` +
          `Do not retry unless the user explicitly asks you to try again.`
        : `The user denied the use of "${toolName}". Do not retry this tool call in this run.`,
    };
  }, { priority: 10, id: 'tool-approval-gate' });
}

module.exports = { registerToolSecurityHooks };
