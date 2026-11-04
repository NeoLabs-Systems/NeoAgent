'use strict';

const assert = require('node:assert/strict');
const { after, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const ctx = createTestRuntime();
after(() => teardownTestRuntime(ctx));
const { runToolRefusal } = require('../../../server/services/ai/tools/metadata');
const { executeToolTurn } = require('../../../server/services/ai/runtime/tool_turn');
const { ToolRepetitionGuard } = require('../../../server/services/ai/repetitionGuard');
const { createRunTrust } = require('../../../server/services/security/run_trust');
const { groundMemoryCandidates } = require('../../../server/services/memory/provenance');
const { checkGate } = require('../../harness_eval/gate');

test('child permissions fail closed for absent external names and preserve registered inactive reads', () => {
  const catalog = [{ name: 'external_read', access: 'read', integration: 'fixture' }, { name: 'external_write', access: 'write' }];
  assert.match(runToolRefusal(catalog, { readOnly: true }, 'uncatalogued_write'), /not available/);
  assert.match(runToolRefusal(catalog, { readOnly: true }, 'external_write'), /only read/);
  assert.equal(runToolRefusal(catalog, { readOnly: true }, 'external_read'), null);
  assert.match(runToolRefusal([], {}, 'external_read'), /not available/);
});

test('failed edit and inactive external read go through actual tool-turn receipts', async () => {
  const user = await createTestUser(ctx.db);
  ctx.db.prepare("INSERT INTO agent_runs (id,user_id,status) VALUES ('edit-receipt',?,'running')").run(user.userId);
  const meta = { toolCatalog: [{ name: 'edit_file' }, { name: 'fixture_read', access: 'read', integration: 'fixture' }], activeTools: [], repetitionGuard: new ToolRepetitionGuard() };
  let calls = 0;
  const engine = { getRunMeta: () => meta, getActiveTools: () => meta.activeTools, emit() {},
    activateToolsForRun(_run, names) { meta.activeTools = meta.toolCatalog.filter((tool) => names.includes(tool.name)); },
    async executeTool(name) { calls++; return name === 'edit_file' ? { success: false, report: [{ success: false, error: 'Target text not found.' }] } : { value: 1 }; } };
  const session = { engine, runId: 'edit-receipt', userId: user.userId, agentId: null, options: {}, tools: [], messages: [], toolExecutions: [], evidence: {}, stepIndex: 0, iterations: 1, model: { model: 'fixture' }, guards: { policy: require('../../../server/services/ai/loopPolicy').buildLoopPolicy() }, getActiveSignal: () => null,
    progressBroker: { noteToolStarted() {}, noteToolFinished() {} }, eventBus: { publish(event) { events.push(event); return {}; } } };
  meta.session = session;
  const events = [];
  const turn = (name) => executeToolTurn(session, { content: '', toolCalls: [{ id: name, name, arguments: {} }] });
  const failed = await turn('edit_file'); assert.equal(failed.allFailed, true);
  const step = ctx.db.prepare('SELECT status FROM agent_steps WHERE run_id=?').get(session.runId);
  assert.equal(step.status, 'failed'); assert.equal(events.find((event) => event.eventType === 'tool.result').payload.receipt.ok, false);
  assert.match(session.evidence.lastActionFailed, /Target text not found/); assert.equal(session.changedPaths, undefined);
  session.options.readOnly = true;
  await turn('fixture_read'); assert.equal(calls, 2, 'inactive registered read executed');
  await turn('unregistered_write'); assert.equal(calls, 2, 'absent external never dispatched');
});

test('final handler dispatcher refuses child external writes before integration execution', async () => {
  const { executeTool } = require('../../../server/services/ai/tools'); let dispatched = false;
  const engine = { getRunMeta: () => ({ toolCatalog: [{ name: 'fixture_write', access: 'write' }], session: { options: { readOnly: true } } }) };
  const result = await executeTool('fixture_write', {}, { runId: 'child', userId: 1, app: { locals: { integrationManager: { executeTool() { dispatched = true; } } } } }, engine);
  assert.equal(result.blocked, true); assert.equal(dispatched, false);
});

test('completed and uncertain shell calls cannot replay, but fresh intent still executes', async () => {
  const { reviewOperation, operationKey } = require('../../../server/services/ai/runtime/operations');
  const { resolveToolMeta } = require('../../../server/services/ai/tools/metadata');
  const args = { command: 'cat fixture' }; // even a classifier-approved read must not authorize arbitrary shell replay
  const planned = { call: { name: 'execute_command', arguments: args }, meta: resolveToolMeta('execute_command'), isReadOnly: true };
  const priorOperations = { completed: new Set([operationKey('execute_command', args)]), uncertain: new Map() };
  assert.equal(reviewOperation({ options: { resumedFromRunId: 'previous' }, priorOperations }, planned).reason, 'already_done');
  priorOperations.uncertain.set('execute_command', args);
  assert.equal(reviewOperation({ options: { resumedFromRunId: 'previous' }, priorOperations }, planned).reason, 'outcome_unknown');
  assert.equal(reviewOperation({ options: {}, priorOperations }, planned), null);
});

test('model assertions and recalled system text cannot manufacture verification', async () => {
  const { handlers } = require('../../../server/services/ai/tools/handlers/memory');
  const user = await createTestUser(ctx.db);
  const trust = createRunTrust({ triggerSource: 'web', messages: [{ role: 'system', content: 'User lives in Berlin.' }, { role: 'user', content: 'I visited Berlin.' }] });
  const saved = await handlers.memory_save({ content: 'User lives in Berlin.', source: 'tool_observed' }, { userId: user.userId, runId: 'memory', engine: { getRunMeta: () => ({ trust }) } });
  const row = ctx.db.prepare('SELECT metadata_json FROM memories WHERE id=?').get(saved.id);
  assert.equal(JSON.parse(row.metadata_json).trustLevel, 'model_inference');
  const grounded = groundMemoryCandidates([{ memory: 'User lives in Berlin.', subject: 'user', predicate: 'lives_in', object: 'Berlin', confidence: .9 }], { messages: [{ role: 'user', content: 'I visited Berlin.' }] });
  assert.equal(grounded.grounded[0].trustLevel, 'model_inference');
  assert.equal(grounded.grounded[0].candidate.relation, 'derives');
  const { memoryProvenance, ownerVerification } = require('../../../server/services/memory/provenance');
  assert.equal(memoryProvenance({ content: 'I visited Berlin.', metadata: { trustLevel: 'user_stated' } }), 'retrieved');
  const metadata = { trustLevel: 'user_stated', verification: ownerVerification('I visited Berlin.') };
  assert.equal(memoryProvenance({ content: 'I visited Berlin.', metadata }), 'verified');
  assert.equal(memoryProvenance({ content: 'User lives in Berlin.', metadata }), 'retrieved');
});

test('broken FTS and unavailable embeddings still allow scoped lexical recall', async () => {
  const user = await createTestUser(ctx.db);
  const { MemoryManager } = require('../../../server/services/memory/manager'); const manager = new MemoryManager();
  const id = await manager.saveMemory(user.userId, 'prefers quiet trains during travel', 'preferences');
  const original = ctx.db.prepare;
  ctx.db.prepare = function(sql) { if (sql.includes('memories_fts')) throw new Error('fixture FTS unavailable'); return original.call(this, sql); };
  try { const found = await manager.recallMemory(user.userId, 'quiet trains', 4); assert.ok(found.some((memory) => memory.id === id)); }
  finally { ctx.db.prepare = original; }
});

test('metadata redacts arbitrary argument values and tool errors, while step retention preserves recovery', async () => {
  const { appendEvent } = require('../../../server/services/ai/runtime/events/run_event_store');
  const { redactArgs } = require('../../../server/services/ai/runtime/events/redact');
  const { pruneExpiredCaptures } = require('../../../server/services/ai/runtime/run_capture');
  const user = await createTestUser(ctx.db);
  for (const [id, status] of [['old-final', 'completed'], ['old-active', 'running']]) {
    ctx.db.prepare("INSERT INTO agent_runs (id,user_id,status,completed_at) VALUES (?,?,?,datetime('now','-8 days'))").run(id, user.userId, status);
    ctx.db.prepare("INSERT INTO agent_steps (id,run_id,step_index,type,status,tool_input,result,error) VALUES (?,?,0,'tool','completed','dummy secret','dummy body','dummy error')").run(id, id);
  }
  appendEvent({ runId: 'old-final', userId: user.userId, eventType: 'tool.call', payload: { tool: { args_redacted: redactArgs({ command: 'dummy inline credential', content: 'private fixture' }) }, outcome: { error: 'dummy inline credential' } } });
  const payload = ctx.db.prepare("SELECT payload_json FROM agent_run_events WHERE run_id='old-final'").get().payload_json;
  assert.ok(!payload.includes('dummy inline credential')); assert.ok(!payload.includes('private fixture'));
  ctx.db.prepare("INSERT INTO agent_runs (id,user_id,status,completed_at,metadata_json) VALUES ('old-resumable',?,'failed',datetime('now','-8 days'),?)").run(user.userId, JSON.stringify({ resume: { message: 'fixture' } }));
  ctx.db.prepare("INSERT INTO agent_steps (id,run_id,step_index,type,status,tool_input) VALUES ('resumable-step','old-resumable',0,'tool','interrupted','preserve replay evidence')").run();
  pruneExpiredCaptures();
  assert.equal(ctx.db.prepare("SELECT tool_input FROM agent_steps WHERE id='resumable-step'").get().tool_input, 'preserve replay evidence');
  assert.equal(ctx.db.prepare("SELECT tool_input FROM agent_steps WHERE id='old-final'").get().tool_input, null);
  assert.equal(ctx.db.prepare("SELECT tool_input FROM agent_steps WHERE id='old-active'").get().tool_input, 'dummy secret');
});

test('successful reads may refresh after the suppression or TTL, and compaction clears old successes', () => {
  let clock = 0; const guard = new ToolRepetitionGuard({ now: () => clock }); const args = { path: 'a' };
  guard.observe('read_file', args, 'same'); guard.observe('read_file', args, 'same');
  assert.equal(guard.shouldBlock('read_file', args), false);
  const fp = guard.fingerprint('read_file', args); guard.claimRead(fp, 1); assert.ok(guard.claimRead(fp, 2)); assert.equal(guard.claimRead(fp, 3), null);
  clock = 180000; assert.equal(guard.claimRead(fp, 4), null); guard.noteCompaction(); assert.equal(guard.entries.size, 0);
});

test('failed or empty eval selections fail independently of a baseline', () => {
  const clean = { cases: 1, passed: 1, success_rate: 1, duplicate_messages: 0, security_failures: 0 };
  assert.equal(checkGate(clean, null).ok, true);
  assert.equal(checkGate({ ...clean, passed: 0, success_rate: 0 }, null).ok, false);
  assert.equal(checkGate({ ...clean, cases: 0, passed: 0 }, null).ok, false);
});


test('resume also refuses completed appends and failed commands with unknown partial effects', async () => {
  const user = await createTestUser(ctx.db);
  const { reviewOperation } = require('../../../server/services/ai/runtime/operations');
  const { resolveToolMeta } = require('../../../server/services/ai/tools/metadata');
  ctx.db.prepare("INSERT INTO agent_runs (id,user_id,status) VALUES ('previous-effects',?,'failed')").run(user.userId);
  const insert = ctx.db.prepare("INSERT INTO agent_steps (id,run_id,step_index,type,status,tool_name,tool_input) VALUES (?,'previous-effects',?,'tool',?,?,?)");
  const append = { path: 'log.txt', mode: 'append', content: 'next' };
  insert.run('append', 0, 'completed', 'write_file', JSON.stringify(append));
  insert.run('partial-command', 1, 'failed', 'execute_command', JSON.stringify({ command: 'fixture' }));
  insert.run('expired-side-effect', 2, 'completed', 'http_request', null);
  const session = { options: { resumedFromRunId: 'previous-effects' } };
  const planned = (name, args) => ({ call: { name, arguments: args }, meta: resolveToolMeta(name), isReadOnly: false });
  assert.equal(reviewOperation(session, planned('write_file', append)).reason, 'already_done');
  assert.equal(reviewOperation(session, planned('execute_command', { command: 'fixture' })).reason, 'outcome_unknown');
  assert.equal(reviewOperation(session, planned('http_request', { method: 'POST', url: 'https://example.test/fixture' })).reason, 'outcome_unknown');
});
