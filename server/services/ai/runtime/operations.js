'use strict';

const db = require('../../../db/database');
const { stableHash } = require('../repetitionGuard');
const { isReadOnlyCall, isShellCall, resolveToolMeta } = require('../tools/metadata');

// A resumed run must not blindly do again what its interrupted run may already have
// done. A call the run before it finished is not repeated. While a call was still in
// flight when the process died its outcome is unknown, so the resumed run makes no
// more calls of that tool and only the owner can decide. The agent_steps rows are the
// record.
//
// Appends, edits and arbitrary commands can all be non-idempotent. Only reads
// and run-local control/navigation are repeatable without reconciliation.
const REPEATABLE_EFFECTS = new Set(['none', 'navigation']);

function operationKey(name, args) {
  return stableHash({ name, args: args || {} });
}

// Anything that may reach outside the workspace, or a command that could do anything.
function canRepeat(meta, args) {
  if (isShellCall(meta)) return false;
  if (isReadOnlyCall(meta, args)) return true;
  return REPEATABLE_EFFECTS.has(meta.sideEffect) && !isShellCall(meta);
}

function parsedArgs(step) {
  try {
    return JSON.parse(step.tool_input || '{}');
  } catch {
    return {};
  }
}

function loadPriorOperations(runId) {
  const steps = db.prepare(
    `SELECT tool_name, tool_input, result, status FROM agent_steps
     WHERE run_id = ? AND tool_name IS NOT NULL AND status IN ('completed', 'interrupted', 'running', 'failed')`,
  ).all(runId);
  const completed = new Set();
  const uncertain = new Map();
  for (const step of steps) {
    if (step.tool_input == null) {
      uncertain.set(step.tool_name, { receipt: 'expired' });
      continue;
    }
    // Refused calls never crossed the dispatch boundary. A failure after dispatch
    // may still have changed something, so its outcome remains uncertain.
    try { if (JSON.parse(step.result || '{}')?.blocked === true) continue; } catch { /* Missing receipts are uncertain. */ }
    const args = parsedArgs(step);
    if (canRepeat(resolveToolMeta(step.tool_name), args)) continue;
    if (step.status === 'completed') completed.add(operationKey(step.tool_name, args));
    else uncertain.set(step.tool_name, args);
  }
  return { completed, uncertain };
}

function reviewOperation(session, planned) {
  const resumedFrom = session.options?.resumedFromRunId;
  if (!resumedFrom) return null;
  const { call, meta } = planned;
  session.priorOperations ||= loadPriorOperations(resumedFrom);
  const { completed, uncertain } = session.priorOperations;
  // Changed arguments can be the same action: another URL for one refund, a reworded
  // message. Nothing here can tell, so the tool waits until the owner has looked.
  if (uncertain.has(call.name)) {
    return {
      reason: 'outcome_unknown',
      completed: false,
      message: `A ${call.name} call was in flight when the previous run was interrupted, so it may already have taken effect: ${JSON.stringify(uncertain.get(call.name)).slice(0, 300)}. This resumed run will not make more ${call.name} calls. Tell the owner what is uncertain so they can check it and ask again.`,
    };
  }
  if (canRepeat(meta, call.arguments)) return null;
  if (completed.has(operationKey(call.name, call.arguments))) {
    return {
      reason: 'already_done',
      completed: true,
      message: `This exact ${call.name} call already succeeded before the run was interrupted. It was not repeated.`,
    };
  }
  return null;
}

module.exports = {
  canRepeat,
  operationKey,
  reviewOperation,
};
