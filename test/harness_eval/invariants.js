'use strict';

function normalized(payloadJson) {
  try {
    return String(JSON.parse(payloadJson || '{}').content || '').replace(/\s+/g, ' ').trim();
  } catch {
    return '';
  }
}

/**
 * What must hold for every message any run ever sent, whatever the case was
 * testing: one final answer per conversation scope and recipient, nothing that
 * may already have arrived is sent again, a progress line is never also the
 * final answer, and a resumed run keeps its original scope.
 */
function deliveryViolations(rows, { resumedRuns = new Map() } = {}) {
  const violations = [];
  const scopes = new Map();
  for (const row of rows) {
    const key = `${row.scope_id || row.run_id}\u0000${row.recipient || ''}`;
    if (!scopes.has(key)) scopes.set(key, []);
    scopes.get(key).push({ ...row, text: normalized(row.payload_json) });

    const origin = resumedRuns.get(row.run_id);
    if (origin && row.scope_id !== origin) {
      violations.push({ rule: 'resumed_run_keeps_scope', run: row.run_id, scope: row.scope_id, expected: origin });
    }
  }
  for (const entries of scopes.values()) {
    const delivered = entries.filter((row) => row.status === 'delivered');
    const finals = delivered.filter((row) => row.purpose === 'final');
    if (finals.length > 1) violations.push({ rule: 'one_final_per_scope', count: finals.length, run: finals[0].run_id });

    for (const uncertain of entries.filter((row) => row.status === 'ambiguous' && row.text)) {
      const resent = delivered.find((row) => row.id !== uncertain.id && row.text === uncertain.text);
      if (resent) violations.push({ rule: 'ambiguous_not_resent', run: uncertain.run_id, text: uncertain.text });
    }
    const finalTexts = new Set(finals.map((row) => row.text).filter(Boolean));
    for (const row of delivered) {
      if (row.purpose !== 'final' && finalTexts.has(row.text)) {
        violations.push({ rule: 'interim_is_not_final', run: row.run_id, purpose: row.purpose, text: row.text });
      }
    }
  }
  return violations;
}

// Every outbox row the eval's database holds for the runs of one case.
function caseDeliveryViolations(db, afterRowId) {
  const rows = db.prepare(
    `SELECT rowid AS row_id, id, run_id, scope_id, recipient, purpose, status, payload_json
     FROM agent_outbox WHERE rowid > ? ORDER BY rowid`,
  ).all(afterRowId);
  const resumedRuns = new Map();
  for (const runId of new Set(rows.map((row) => row.run_id))) {
    const run = db.prepare('SELECT metadata_json FROM agent_runs WHERE id = ?').get(runId);
    const origin = JSON.parse(run?.metadata_json || '{}').resumedFromRunId;
    if (origin) resumedRuns.set(runId, origin);
  }
  return {
    violations: deliveryViolations(rows, { resumedRuns }),
    lastRowId: rows.at(-1)?.row_id ?? afterRowId,
  };
}

module.exports = {
  caseDeliveryViolations,
  deliveryViolations,
};
