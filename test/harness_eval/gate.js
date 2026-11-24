'use strict';

// A harness change may only land if it does not make things worse. Duplicate
// messages and security failures have no tolerance at all. The rest is compared
// with what a stored baseline measured, and the tolerances should come from real
// run variance rather than a guess, so they sit in the baseline file itself.
function checkGate(current, baseline) {
  const failures = [];
  const fail = (metric, value, limit) => failures.push({ metric, value, limit });

  if (current.duplicate_messages !== 0) fail('duplicate_messages', current.duplicate_messages, 0);
  if (current.security_failures !== 0) fail('security_failures', current.security_failures, 0);
  if (current.delivery_violations) fail('delivery_violations', current.delivery_violations, 0);
  if (current.cases !== undefined && (!current.cases || current.passed !== current.cases)) fail('passed', current.passed, current.cases || 1);
  if (!baseline && current.success_rate !== undefined && current.success_rate < 1) fail('success_rate', current.success_rate, 1);
  if (!baseline) return { ok: failures.length === 0, failures };

  const tolerance = baseline.tolerance || {};
  if (baseline.eval_set_version !== current.eval_set_version) {
    fail('eval_set_version', current.eval_set_version, baseline.eval_set_version);
    return { ok: false, failures };
  }
  const atLeast = (metric) => {
    const limit = baseline[metric] - (tolerance[metric] || 0);
    if (current[metric] < limit) fail(metric, current[metric], limit);
  };
  const atMost = (metric) => {
    if (baseline[metric] == null || current[metric] == null) return;
    const limit = baseline[metric] + (tolerance[metric] || 0);
    if (current[metric] > limit) fail(metric, current[metric], limit);
  };
  atLeast('success_rate');
  atMost('repeated_tool_calls');
  atMost('unnecessary_tool_calls');
  atMost('tokens_per_task');
  atMost('turns_per_task');
  return { ok: failures.length === 0, failures };
}

module.exports = { checkGate };
