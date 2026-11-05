'use strict';

const { randomUUID } = require('crypto');
const { EventEmitter } = require('events');
const db = require('../../../db/database');
const agents = require('../../agents/manager');
const tasks = require('../../agents/tasks');
const { mergeToolRestrictions } = require('../../agents/tool_restrictions');
const { renderFragment } = require('../prompts/registry');
const { fenceUntrusted } = require('../../../utils/untrusted_text');
const { clampRunContext } = require('../messagingFallback');
const { EVENT_TYPES } = require('../runtime/events/event_types');
const { routeOfRun, startRunOnRoute } = require('../runtime/restart_resume');
const { createServiceLogger } = require('../../../utils/logger');

const logger = createServiceLogger('AgentTasks');

// Agent tasks run in the background and never block the run that asked: the
// owner works the task in its own run, and the requester hears back through a
// note in its run when it is still going, or a new run on the user's surface
// when it is not. State lives in the task row, so a restart picks work up again.

const WORKING_RUNS_PER_USER = 2;
const MAX_WAIT_SECONDS = 120;
const RESULT_IN_UPDATE_CHARS = 4000;

const changes = new EventEmitter();
changes.setMaxListeners(0);

function parseJson(text) {
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

function agentName(userId, agentId) {
  return agents.getAgentById(userId, agentId)?.display_name || 'another agent';
}

function findAgent(userId, reference) {
  const text = String(reference || '').trim();
  if (!text) return null;
  return agents.getAgentById(userId, text)
    || agents.getAgentBySlug(userId, text)
    || db.prepare('SELECT * FROM agents WHERE user_id = ? AND lower(display_name) = lower(?)').get(userId, text)
    || null;
}

function recordTaskEvent(engine, task, action) {
  // The asking run's ledger shows the hand-off; the owner's own runs show the work.
  const runId = task.parent_run_id || task.child_run_id;
  if (runId) {
    engine.recordRunEvent(task.user_id, runId, EVENT_TYPES.AGENT_TASK, {
      action,
      task_id: task.id,
      mode: task.mode,
      status: task.status,
      requester_agent_id: task.parent_agent_id,
      owner_agent_id: task.target_agent_id,
    }, { agentId: task.target_agent_id });
  }
  engine.emit(task.user_id, 'agent_task:update', { task: tasks.serializeTask(task) });
  changes.emit(task.id);
}

// ── Asking ──────────────────────────────────────────────────────────────────

// Plain counts and identities only: whether the work should go to another
// agent at all is the model's call.
function delegationRefusal(userId, runId, parentTask, owner) {
  if (!runId) return 'Agent tasks can only be created from a run.';
  if (parentTask && parentTask.depth + 1 > tasks.LIMITS.depth) {
    return 'This work has already been passed along as far as it may go. Finish it yourself.';
  }
  if (parentTask && tasks.agentsOnChain(parentTask.id).has(owner.id)) {
    return `${owner.display_name} is already part of this task. Passing work back would go in circles; finish it yourself.`;
  }
  if (tasks.countTasksRequestedByRun(runId) >= tasks.LIMITS.tasksPerRun) {
    return `One run may start at most ${tasks.LIMITS.tasksPerRun} agent tasks. Wait for those, or do the rest yourself.`;
  }
  if (tasks.countOpenTasks(userId) >= tasks.LIMITS.openTasksPerUser) {
    return 'Too many agent tasks are still open on this account. Do the work yourself.';
  }
  return null;
}

function delegateTask(engine, { userId, agentId, runId }, args = {}) {
  const goal = String(args.task || '').trim();
  if (!goal) return { error: 'task is required.' };
  const requester = agents.getAgentById(userId, agents.resolveAgentId(userId, agentId));
  const owner = findAgent(userId, args.agent);
  if (!owner || owner.status !== 'active') {
    return {
      error: `No active agent matches "${args.agent}".`,
      agents: agents.getDelegationTargets(userId, requester?.id).map((agent) => agent.slug),
    };
  }
  if (!agents.agentCanDelegateTo(requester, owner)) {
    return { error: `${requester?.display_name || 'This agent'} may not hand work to ${owner.display_name}. The user decides this in the agents' settings.` };
  }
  const parentTask = tasks.getTaskForRun(runId);
  const refusal = delegationRefusal(userId, runId, parentTask, owner);
  if (refusal) return { error: refusal };

  const mode = args.handoff === true ? 'handoff' : 'delegate';
  const task = tasks.insertTask({
    userId,
    requesterAgentId: requester.id,
    ownerAgentId: owner.id,
    requesterRunId: runId,
    parentTaskId: parentTask?.id || null,
    goal,
    context: String(args.context || '').trim(),
    expectedOutput: String(args.expected_output || '').trim(),
    mode,
    depth: parentTask ? parentTask.depth + 1 : 0,
    replyRoute: parentTask ? parseJson(parentTask.reply_route_json) : routeOfRun(runId),
    // The owner works under its own limits and every limit of those who asked.
    toolRestrictions: mergeToolRestrictions(requester.tool_restrictions_json, parentTask?.tool_restrictions_json),
    allowExternalSideEffects: args.allow_external_side_effects === true,
  });
  recordTaskEvent(engine, task, 'created');
  dispatchTasks(engine);
  return {
    task_id: task.id,
    owner: owner.display_name,
    mode,
    status: tasks.getTaskById(task.id).status,
    note: mode === 'handoff'
      ? `${owner.display_name} owns this now and its result reaches the user without you. Tell the user in a sentence who took it over.`
      : `${owner.display_name} works on it in the background and its result comes back to you as an agent task update. Carry on or end your turn; use agent_task with action "status" and wait_seconds only when you cannot continue without it.`,
  };
}

// ── Working ─────────────────────────────────────────────────────────────────

function ownerConversationId(engine, userId, agentId) {
  try {
    return engine.app?.locals?.memoryManager?.getDefaultWebConversationId(userId, { agentId }) || null;
  } catch (error) {
    logger.warn(`No chat to record the task in for agent ${agentId}: ${error?.message || error}`);
    return null;
  }
}

function fenced(label, text) {
  return `${label}:\n${fenceUntrusted('external_agent_message', text)}`;
}

// What the owner's run starts from. The messages and subtask outcomes it shows
// count as seen only once that run has ended, so a restart shows them again.
function buildBrief(task, owner) {
  const requester = agentName(task.user_id, task.parent_agent_id);
  const details = [];
  if (task.expected_output) details.push(`Expected result:\n${task.expected_output}`);
  if (task.context) details.push(fenced(`Context from ${requester}`, task.context));
  if (task.result_summary) details.push(fenced('Where your last run on this task stopped', task.result_summary));
  const messages = tasks.unreadMessagesFor(task.id, owner.id);
  if (messages.length) {
    details.push(fenced('Messages on this task since then', messages.map((message) => (
      `${agentName(task.user_id, message.from_agent_id)}: ${message.content}`
    )).join('\n\n')));
  }
  const children = tasks.unreportedChildren(task.id);
  if (children.length) details.push(fenced('Agents you handed parts to', children.map(describeForRequester).join('\n\n')));
  const stillOpen = tasks.openDelegatedChildren(task.id).filter((child) => !children.some((seen) => seen.id === child.id));
  if (stillOpen.length) {
    details.push(`Still being worked on by others: ${stillOpen.map((child) => `${agentName(task.user_id, child.target_agent_id)} (${clampRunContext(child.task, 120)})`).join('; ')}.`);
  }
  const text = renderFragment('runtime/agent_task.md', {
    task_id: task.id,
    requester,
    owner: owner.display_name,
    ownership: task.mode === 'handoff'
      ? 'You own it now: finish it end to end.'
      : `${requester} stays responsible for the user's request and builds on your result.`,
    goal: task.task,
    details: details.length ? `\n${details.join('\n\n')}\n` : '',
    recipient: task.mode === 'handoff' ? 'the agent that talks to the user, which passes it on' : requester,
    side_effects: task.allow_external_side_effects === 1
      ? 'You may send messages or change outside systems where the goal needs it.'
      : 'Do not send messages, make calls, or change outside systems; report what should be done instead.',
  });
  return { text, messageIds: messages.map((message) => message.id), childIds: children.map((child) => child.id) };
}

function dispatchTasks(engine) {
  if (engine.shuttingDown) return;
  for (const task of tasks.pendingTasks()) {
    if (tasks.countWorkingTasks(task.user_id) >= WORKING_RUNS_PER_USER) continue;
    startTaskRun(engine, task);
  }
}

function startTaskRun(engine, task) {
  const owner = agents.getAgentById(task.user_id, task.target_agent_id);
  if (!owner || owner.status !== 'active') {
    finishTask(engine, task, { status: 'failed', error: `${owner?.display_name || 'The agent'} is paused or archived.` });
    return;
  }
  if (task.attempts >= tasks.LIMITS.attemptsPerTask) {
    finishTask(engine, task, { status: 'failed', error: 'The task took too many runs without finishing.' });
    return;
  }
  const runId = randomUUID();
  const claimed = tasks.claimTaskForRun(task.id, runId);
  if (!claimed) return;
  recordTaskEvent(engine, claimed, 'working');
  const requesterRun = engine.getRunMeta(claimed.parent_run_id);
  const brief = buildBrief(claimed, owner);
  engine.runWithModel(claimed.user_id, brief.text, {
    app: engine.app,
    runId,
    agentId: owner.id,
    title: claimed.task,
    triggerType: 'agent_delegation',
    triggerSource: 'agent_delegation',
    // The task and its result join the owner's own chat history; the owner
    // starts from the brief, not from that chat.
    conversationId: ownerConversationId(engine, claimed.user_id, owner.id),
    skipConversationHistory: true,
    allowExternalSideEffects: claimed.allow_external_side_effects === 1,
    // Shares the asking run's trust while it is around; otherwise the run
    // starts as untrusted, which only ever asks the owner more.
    parentTrust: requesterRun?.trust || null,
  }, null)
    .then((result) => settleOwnerRun(engine, claimed.id, runId, result, brief))
    .catch((error) => settleOwnerRun(engine, claimed.id, runId, { status: 'failed', error: error?.message || String(error) }, brief));
}

function settleOwnerRun(engine, taskId, runId, result, brief) {
  // A restart puts it back in the queue, brief and all.
  if (result?.status === 'interrupted' || engine.shuttingDown) return;
  tasks.markMessagesRead(brief.messageIds);
  for (const childId of brief.childIds) tasks.claimReport(childId);

  const task = tasks.getTaskById(taskId);
  // Handed on or cancelled while the run was going.
  if (!task || task.child_run_id !== runId || task.status !== 'working') {
    dispatchTasks(engine);
    return;
  }

  if (result?.status === 'stopped') {
    finishTask(engine, task, { status: 'cancelled', error: 'Its run was stopped.' });
  } else if (result?.status !== 'completed') {
    finishTask(engine, task, { status: 'failed', error: clampRunContext(result?.error || 'The run ended without a result.', 1000) });
  } else {
    const content = String(result.content || '').trim();
    const waiting = task.awaiting_reply === 1
      || tasks.openDelegatedChildren(task.id).length > 0
      || tasks.unreportedChildren(task.id).length > 0
      || tasks.hasMessagesFor(task.id, task.target_agent_id);
    if (waiting) {
      const updated = tasks.updateTask(task.id, { status: 'waiting', result: content }, { fromStatuses: ['working'] });
      if (updated) recordTaskEvent(engine, updated, 'waiting');
      resumeIfReady(engine, task.id);
    } else {
      finishTask(engine, task, { status: 'completed', result: content || 'The agent finished without writing a result.' });
    }
  }
  dispatchTasks(engine);
}

// A waiting task goes back to work once something new has arrived for it.
function resumeIfReady(engine, taskId) {
  const task = tasks.getTaskById(taskId);
  if (!task || task.status !== 'waiting' || task.awaiting_reply === 1) return;
  const news = tasks.unreportedChildren(task.id).length > 0 || tasks.hasMessagesFor(task.id, task.target_agent_id);
  if (!news && tasks.openDelegatedChildren(task.id).length > 0) return;
  const resumed = tasks.updateTask(task.id, { status: 'pending' }, { fromStatuses: ['waiting'] });
  if (!resumed) return;
  recordTaskEvent(engine, resumed, 'resumed');
  dispatchTasks(engine);
}

function finishTask(engine, task, { status, result = null, error = null }) {
  const settled = tasks.updateTask(task.id, {
    status,
    result: result ?? task.result_summary,
    error,
    awaitingReply: false,
    reportPending: true,
  }, { fromStatuses: tasks.OPEN_STATUSES });
  if (!settled) return;
  recordTaskEvent(engine, settled, status);
  if (status === 'completed') postToOwnerChat(settled);
  else cancelOpenChildren(engine, settled, 'The task it was part of ended.');
  notifyRequester(engine, settled);
}

function cancelTask(engine, task, reason) {
  const cancelled = tasks.updateTask(task.id, {
    status: 'cancelled', error: reason, awaitingReply: false, reportPending: false,
  }, { fromStatuses: tasks.OPEN_STATUSES });
  if (!cancelled) return false;
  if (task.status === 'working' && task.child_run_id) engine.stopRun(task.child_run_id, reason);
  recordTaskEvent(engine, cancelled, 'cancelled');
  cancelOpenChildren(engine, cancelled, reason);
  return true;
}

function cancelOpenChildren(engine, task, reason) {
  for (const child of tasks.openDelegatedChildren(task.id)) cancelTask(engine, child, reason);
}

// The owner's chat shows what it did, so the user can pick the work up there.
function postToOwnerChat(task) {
  db.prepare(
    `INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata)
     VALUES (?, ?, ?, 'assistant', ?, ?)`,
  ).run(
    task.user_id,
    task.target_agent_id,
    task.child_run_id,
    task.result_summary,
    JSON.stringify({
      platform: 'agent_task',
      agentTask: {
        id: task.id,
        mode: task.mode,
        goal: clampRunContext(task.task, 300),
        requester: agentName(task.user_id, task.parent_agent_id),
      },
    }),
  );
}

// ── Hearing back ────────────────────────────────────────────────────────────

function describeForRequester(task) {
  const owner = agentName(task.user_id, task.target_agent_id);
  const head = `Task ${task.id} for ${owner} (${clampRunContext(task.task, 200)})`;
  if (task.awaiting_reply === 1 && tasks.OPEN_STATUSES.includes(task.status)) {
    const question = tasks.lastMessageFrom(task.id, task.target_agent_id);
    return `${head} needs an answer from you before it can go on. ${owner} asks:\n${question}\nReply with agent_task (action "message").`;
  }
  if (task.status === 'completed') {
    return `${head} is done. Result:\n${clampRunContext(task.result_summary, RESULT_IN_UPDATE_CHARS)}`;
  }
  if (tasks.OPEN_STATUSES.includes(task.status)) return `${head} is ${task.status}.`;
  return `${head} ${task.status === 'cancelled' ? 'was cancelled' : 'failed'}: ${task.error || 'no reason given'}.`;
}

function renderUpdate(list, instruction) {
  return renderFragment('runtime/agent_task_update.md', {
    updates: fenceUntrusted('external_agent_message', list.map(describeForRequester).join('\n\n')),
    instruction,
  });
}

/**
 * Tells whoever asked for a task about its latest change: a note in the asking
 * run while it is still going, the parent task's next run when an agent asked
 * from inside a task, and otherwise a new run on the user's surface.
 */
function notifyRequester(engine, task) {
  const requesterRun = engine.getRunMeta(task.parent_run_id);
  if (requesterRun && !requesterRun.aborted) {
    const note = renderUpdate([task], 'Use it in what you are doing now.');
    if (engine.enqueueSystemSteering(task.parent_run_id, note, { reason: 'agent_task', agentTaskId: task.id })) {
      tasks.claimReport(task.id);
    }
    return;
  }
  if (task.mode === 'delegate' && task.parent_task_id) {
    const parent = tasks.getTaskById(task.parent_task_id);
    if (parent && tasks.OPEN_STATUSES.includes(parent.status)) resumeIfReady(engine, parent.id);
    else tasks.claimReport(task.id);
    return;
  }
  startReportRun(engine, task);
}

function startReportRun(engine, task) {
  if (engine.shuttingDown || !tasks.claimReport(task.id)) return;
  const route = parseJson(task.reply_route_json);
  const routeAgentId = route?.agentId || task.parent_agent_id;
  const options = route
    ? { ...route, context: { ...(route.context || {}), rawUserMessage: undefined }, mediaAttachments: undefined }
    : {
      triggerType: 'agent_task',
      triggerSource: 'web',
      agentId: routeAgentId,
      conversationId: ownerConversationId(engine, task.user_id, routeAgentId),
    };
  const owner = agentName(task.user_id, task.target_agent_id);
  const instruction = task.mode === 'handoff'
    ? `${owner} took this request over from you. Pass its outcome on to the user in your own words; do not redo the work.`
    : 'Nothing new came from the user. Carry on with the request this belongs to: tell the user what matters in your own words, or act on it. Answer an agent\'s question yourself when you can, and ask the user only when you cannot.';
  startRunOnRoute(engine, task.user_id, renderUpdate([task], instruction), {
    ...options,
    title: `Update: ${clampRunContext(task.task, 80)}`,
    app: engine.app,
  }).catch((error) => {
    logger.error(`Reporting task ${task.id} failed:`, error?.message || error);
    tasks.updateTask(task.id, { reportPending: true });
  });
}

/**
 * Called once a run has ended. Notes it never read are owed again, a run the
 * user stopped takes the work it handed out with it, and anything it asked for
 * that has news is reported now that it cannot read it.
 */
function onRunEnded(engine, runId, runMeta) {
  if (!runMeta) return;
  for (const item of runMeta.systemSteeringQueue || []) {
    const { agentTaskId, agentTaskMessageIds } = item.metadata || {};
    tasks.markMessagesUndelivered(agentTaskMessageIds);
    if (agentTaskId) tasks.updateTask(agentTaskId, { reportPending: true });
  }
  if (runMeta.status === 'stopped') {
    for (const task of tasks.tasksRequestedByRun(runId)) {
      if (task.mode === 'delegate') cancelTask(engine, task, 'The run that asked for it was stopped.');
    }
  }
  for (const task of tasks.tasksRequestedByRun(runId)) {
    if (task.report_pending === 1) notifyRequester(engine, task);
  }
}

function resumeAgentTasks(engine) {
  const requeued = tasks.requeueInterruptedTasks();
  for (const task of tasks.tasksToReport()) notifyRequester(engine, task);
  dispatchTasks(engine);
  if (requeued) logger.info(`Resuming ${requeued} agent task(s) a restart interrupted.`);
}

// ── The agent_task tool ─────────────────────────────────────────────────────

async function waitForChange(taskId, seconds) {
  const ms = Math.min(Math.max(Number(seconds) || 0, 0), MAX_WAIT_SECONDS) * 1000;
  if (!ms) return;
  await new Promise((resolve) => {
    const timer = setTimeout(done, ms);
    function done() {
      clearTimeout(timer);
      changes.off(taskId, done);
      resolve();
    }
    changes.on(taskId, done);
  });
}

function describeTask(task) {
  const view = tasks.serializeTask(task);
  return {
    ...view,
    result: view.result ? clampRunContext(view.result, RESULT_IN_UPDATE_CHARS) : '',
    messages: tasks.listMessages(task.id).slice(-6).map((message) => ({
      from: agentName(task.user_id, message.from_agent_id),
      content: clampRunContext(message.content, 600),
    })),
  };
}

function sendTaskMessage(engine, task, senderId, text) {
  if (!tasks.OPEN_STATUSES.includes(task.status)) {
    return { error: `Task ${task.id} is ${task.status}. Start a new task with delegate_to_agent instead.` };
  }
  if (tasks.countMessages(task.id) >= tasks.LIMITS.messagesPerTask) {
    return { error: 'This task has reached its message limit. Decide with what you have.' };
  }
  tasks.addMessage(task.id, senderId, text);

  if (senderId === task.target_agent_id) {
    // The owner asks the requester; the task waits for the answer.
    const asking = tasks.updateTask(task.id, { awaitingReply: true, reportPending: true });
    recordTaskEvent(engine, asking, 'question');
    notifyRequester(engine, asking);
    return { sent: true, note: 'End your turn now; this task continues when the answer arrives.' };
  }

  // The requester answers or adds something for the owner.
  const updated = tasks.updateTask(task.id, { awaitingReply: false });
  const ownerRun = updated.status === 'working' ? engine.getRunMeta(updated.child_run_id) : null;
  if (ownerRun && !ownerRun.aborted) {
    const messages = tasks.takeMessagesFor(updated.id, updated.target_agent_id);
    const note = fenced(`Message on agent task ${updated.id} from ${agentName(updated.user_id, senderId)}`,
      messages.map((message) => message.content).join('\n\n'));
    engine.enqueueSystemSteering(updated.child_run_id, note, {
      reason: 'agent_task_message',
      agentTaskMessageIds: messages.map((message) => message.id),
    });
  } else {
    resumeIfReady(engine, updated.id);
  }
  recordTaskEvent(engine, updated, 'message');
  return { sent: true };
}

function handOffTask(engine, { userId, agentId }, task, args) {
  if (task.target_agent_id !== agentId) return { error: 'Only the agent that owns a task can hand it on.' };
  const current = agents.getAgentById(userId, agentId);
  const next = findAgent(userId, args.agent);
  if (!next || next.status !== 'active') return { error: `No active agent matches "${args.agent}".` };
  if (!agents.agentCanDelegateTo(current, next)) return { error: `${current.display_name} may not hand work to ${next.display_name}.` };
  if (tasks.agentsOnChain(task.id).has(next.id)) {
    return { error: `${next.display_name} is already part of this task. Passing it back would go in circles; finish it yourself.` };
  }
  const note = String(args.message || '').trim();
  tasks.addMessage(task.id, agentId, note || `${current.display_name} handed this task to you.`);
  const moved = tasks.updateTask(task.id, {
    ownerAgentId: next.id, status: 'pending', awaitingReply: false,
  }, { fromStatuses: tasks.OPEN_STATUSES });
  if (!moved) return { error: `Task ${task.id} is no longer open.` };
  recordTaskEvent(engine, moved, 'handed_off');
  dispatchTasks(engine);
  return { handed_off: true, owner: next.display_name, note: 'It is no longer yours. End your turn with a one-line note.' };
}

async function taskAction(engine, ctx, args = {}) {
  const { userId, agentId, runId } = ctx;
  const action = String(args.action || '').trim();
  if (action === 'list' || (!args.task_id && action === 'status')) {
    return { tasks: tasks.openTasksForAgent(userId, agentId).map(describeTask) };
  }
  const task = tasks.getTask(userId, args.task_id);
  if (!task || (task.parent_agent_id !== agentId && task.target_agent_id !== agentId)) {
    return { error: `No agent task "${args.task_id}" that you asked for or own.` };
  }

  if (action === 'status') {
    if (task.parent_agent_id === agentId && tasks.OPEN_STATUSES.includes(task.status) && task.awaiting_reply !== 1) {
      await waitForChange(task.id, args.wait_seconds);
    }
    const fresh = tasks.getTaskById(task.id);
    // Reading the outcome here is hearing it; no update needs to follow.
    if (fresh.parent_agent_id === agentId && fresh.parent_run_id === runId && fresh.report_pending === 1) {
      tasks.claimReport(fresh.id);
    }
    return { task: describeTask(fresh) };
  }
  if (action === 'message') {
    const text = String(args.message || '').trim();
    if (!text) return { error: 'message is required.' };
    return sendTaskMessage(engine, task, agentId, text);
  }
  if (action === 'handoff') return handOffTask(engine, ctx, task, args);
  if (action === 'cancel') {
    if (task.parent_agent_id !== agentId) return { error: 'Only the agent that asked for a task can cancel it.' };
    const reason = String(args.message || '').trim() || 'Cancelled by the agent that asked for it.';
    return cancelTask(engine, task, reason)
      ? { cancelled: true, task_id: task.id }
      : { error: `Task ${task.id} is already ${task.status}.` };
  }
  return { error: 'action must be list, status, message, handoff, or cancel.' };
}

// For the prompt of an agent with tasks in flight.
function buildOpenTasksNote(userId, agentId, runId) {
  const own = tasks.getTaskForRun(runId)?.id;
  const open = tasks.openTasksForAgent(userId, agentId).filter((task) => task.id !== own);
  if (!open.length) return '';
  return [
    '[Agent tasks in flight]',
    ...open.map((task) => {
      const asked = task.parent_agent_id === agentId;
      const other = agentName(userId, asked ? task.target_agent_id : task.parent_agent_id);
      const status = task.awaiting_reply === 1 ? 'waiting for an answer' : task.status;
      return `- ${task.id}: ${asked ? `you asked ${other}` : `${other} asked you`} (${task.mode}, ${status}): ${clampRunContext(task.task, 200)}`;
    }),
    'Use agent_task for a fresh look or to send a message. Do not redo work another agent owns.',
  ].join('\n');
}

/**
 * Lets the user cancel a task from the app. Same rules as an agent cancelling,
 * without the ownership check: the user owns every agent on the account.
 */
function cancelTaskForUser(engine, userId, taskId) {
  const task = tasks.getTask(userId, taskId);
  if (!task) return null;
  cancelTask(engine, task, 'Cancelled by the user.');
  return tasks.serializeTask(tasks.getTaskById(task.id));
}

module.exports = {
  buildOpenTasksNote,
  cancelTaskForUser,
  delegateTask,
  onRunEnded,
  resumeAgentTasks,
  taskAction,
};
