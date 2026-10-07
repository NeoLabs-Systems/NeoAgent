'use strict';

const { randomUUID } = require('crypto');
const { createServiceLogger } = require('../../../utils/logger');
const { sanitizeError } = require('../../../utils/security');
const { resolveAgentId } = require('../../agents/manager');
const { MESSAGE_KINDS } = require('../../ai/runtime/constants');
const { applyBackgroundAction, listBackgroundRuns } = require('../../ai/loop/background_runs');

const logger = createServiceLogger('LiveVoiceTasks');
const SPOKEN_LIVENESS = new Set(['blocked', 'waiting']);

// Everything the live model hands off runs as an ordinary agent run: same
// orchestrator, tools, memory, approvals, verification, and outbox delivery as
// a chat or WhatsApp message. This bridge maps runs to the live model's
// hand-off handles and feeds their progress and results back into the call.
//
// Each hand-off is a run of its own, so the owner can start more work while
// earlier work is running. The live model checks on, changes, or stops tasks
// with its task tools, which reach every task the owner has running with this
// agent: this call's, an earlier call's, and the chat's.
//
// Only runs this call started report into it. The run that placed an
// agent-initiated call is not its work: it finishes on its own, so treating it
// as the call's task showed the call as busy and fed what the owner said into
// a run that was already wrapping up, where nothing answered it.
class LiveTaskBridge {
  constructor({ agentEngine, session }) {
    this.agentEngine = agentEngine;
    this.session = session;
    this.runs = new Map();
    // Short ids the live model can repeat back, by run id.
    this.taskIds = new Map();
  }

  // This call's tasks that are still running, oldest first.
  get runningTasks() {
    const tasks = [];
    for (const [runId, record] of this.runs) {
      const meta = this.agentEngine.getRunMeta(runId);
      if (meta && !meta.aborted && meta.status === 'running') {
        tasks.push({ runId, taskId: this.#taskId(runId), request: record.request });
      }
    }
    return tasks;
  }

  get activeRunId() {
    return this.runningTasks.at(-1)?.runId || null;
  }

  get hasRunningWork() {
    return this.runningTasks.length > 0;
  }

  // Starts a new task and returns its id, or null when there was no request.
  delegate({ handle, request }) {
    const text = String(request || '').trim();
    if (!text) return null;
    return this.#start(handle, text);
  }

  // Every task the owner has running with this agent.
  checkTasks() {
    const tasks = this.#ownerRuns().map((run) => this.#describe(run));
    return tasks.length ? { tasks } : { tasks, note: 'No task is running.' };
  }

  // The live model's task tools.
  runTool(name, args = {}) {
    if (name === 'check_tasks') return this.checkTasks();
    if (name === 'update_task') return this.#act('instruct', args.task_id, { instruction: args.instruction });
    if (name === 'cancel_task') return this.#act('cancel', args.task_id);
    return { error: `There is no tool named ${name}.` };
  }

  // Outbox deliveries for runs this session started arrive here instead of a
  // chat channel.
  present(entry) {
    const content = String(entry?.payload?.content || '').trim();
    if (!content) return;
    const record = this.runs.get(entry.runId);
    const handle = record?.handle || null;
    const task = this.#label(entry.runId, record);
    if (entry.messageKind === MESSAGE_KINDS.FINAL) {
      if (record) record.delivered = true;
      this.session.tell(handle, `${task} finished. Its outcome:\n${content}`);
      return;
    }
    const metadata = entry.payload?.metadata || {};
    // The live model already acknowledged the hand-off in its own words.
    if (entry.messageKind === MESSAGE_KINDS.ACK || metadata.kind === 'ack') {
      this.session.inform(handle, `${task} started: ${content}`);
      return;
    }
    const needsOwner = metadata.expectsReply === true
      || SPOKEN_LIVENESS.has(String(metadata.liveness?.status || ''));
    if (needsOwner) {
      this.session.tell(handle, `${task} needs the owner:\n${content}`);
      return;
    }
    this.session.offerProgress(handle, `Progress on ${task}:\n${content}`);
  }

  // The call screen's stop button; without a run id it stops this call's
  // newest task. The live model is told, since it did not do this itself.
  cancelFromScreen(runId = null) {
    const target = runId && this.runs.has(runId) ? runId : this.activeRunId;
    if (!target) return { cancelled: false };
    const cancelled = this.agentEngine.abort(target, {
      userId: this.session.userId,
      reason: 'voice_user_cancelled',
    });
    if (cancelled) {
      const record = this.runs.get(target);
      record.cancelled = true;
      this.session.inform(record.handle, `The owner stopped ${this.#label(target, record)} from the call screen.`);
    }
    return { cancelled, runId: target };
  }

  abortAll(reason) {
    for (const runId of this.runs.keys()) {
      this.agentEngine.abort(runId, { userId: this.session.userId, reason });
    }
  }

  #owner() {
    return {
      userId: this.session.userId,
      agentId: resolveAgentId(this.session.userId, this.session.agentId),
    };
  }

  #ownerRuns() {
    return listBackgroundRuns(this.agentEngine, { ...this.#owner(), includeForeground: true });
  }

  #describe(run) {
    const startedMs = Date.parse(run.started_at || '');
    return {
      task_id: this.#taskId(run.run_id),
      request: run.request,
      status: run.status,
      started_in: this.#origin(run),
      running_for_seconds: Number.isFinite(startedMs) ? Math.round((Date.now() - startedMs) / 1000) : null,
      recent_steps: run.recent_steps,
    };
  }

  #origin(run) {
    if (this.runs.has(run.run_id)) return 'this call';
    if (run.channel === 'voice_live') return 'an earlier call';
    return run.channel === 'web' ? 'the chat' : run.channel;
  }

  #act(action, taskId, extra = {}) {
    const runs = this.#ownerRuns();
    const runId = this.#runIdFor(taskId, runs);
    if (!runId) {
      return {
        error: runs.length
          ? `No running task has task_id "${taskId || ''}". Use one of these.`
          : 'No task is running.',
        tasks: runs.map((run) => this.#describe(run)),
      };
    }
    const result = applyBackgroundAction(this.agentEngine, {
      ...this.#owner(),
      runs,
      origin: { fromVoiceSessionId: this.session.id },
    }, { action, run_id: runId, ...extra });
    // The live model stopped it and has already said so.
    if (action === 'cancel' && result.cancelled && this.runs.has(runId)) {
      this.runs.get(runId).cancelled = true;
    }
    const { run_id: _runId, background_tasks: _tasks, ...rest } = result;
    return { task_id: this.#taskId(runId), ...rest };
  }

  // A single running task needs no id.
  #runIdFor(taskId, runs) {
    const wanted = String(taskId || '').trim();
    if (!wanted) return runs.length === 1 ? runs[0].run_id : null;
    const match = runs.find((run) => run.run_id === wanted || this.taskIds.get(run.run_id) === wanted);
    return match?.run_id || null;
  }

  #taskId(runId) {
    if (!this.taskIds.has(runId)) this.taskIds.set(runId, String(this.taskIds.size + 1));
    return this.taskIds.get(runId);
  }

  #label(runId, record = this.runs.get(runId)) {
    const request = record?.request || this.agentEngine.getRunMeta(runId)?.request || '';
    return request ? `task ${this.#taskId(runId)} ("${request}")` : `task ${this.#taskId(runId)}`;
  }

  #start(handle, request) {
    const session = this.session;
    const runId = randomUUID();
    this.runs.set(runId, { handle, request, delivered: false, cancelled: false });
    const taskId = this.#taskId(runId);
    session.publishTask({ runId, status: 'running', request });
    this.agentEngine.run(session.userId, request, {
      runId,
      agentId: session.agentId,
      conversationId: session.conversationId,
      triggerSource: 'voice_live',
      source: 'voice_live',
      chatId: session.id,
      voiceSessionId: session.id,
      latencyPriority: 'interactive',
      context: { rawUserMessage: request },
    }).then((result) => {
      this.#settle(runId, result?.status || 'completed', result?.content, null);
    }).catch((error) => {
      logger.warn('Voice task failed', { runId, error: error?.message || String(error) });
      this.#settle(runId, 'failed', '', error);
    });
    return taskId;
  }

  #settle(runId, status, content, error) {
    const record = this.runs.get(runId);
    this.runs.delete(runId);
    this.session.publishTask({ runId, status });
    if (!record || record.delivered || record.cancelled) {
      this.session.releaseIfIdle();
      return;
    }
    const reply = status === 'completed' ? String(content || '').trim() : '';
    const outcome = reply
      ? `${this.#label(runId, record)} finished. Its outcome:\n${reply}`
      : [
        `${this.#label(runId, record)} ended with status "${status}" and produced no result for the owner.`,
        error ? `Reported error: ${sanitizeError(error)}` : '',
        content ? `Partial output: ${String(content).trim()}` : '',
      ].filter(Boolean).join('\n');
    this.session.deliverTaskOutcome({ handle: record.handle, runId, outcome, reply });
  }
}

module.exports = {
  LiveTaskBridge,
};
