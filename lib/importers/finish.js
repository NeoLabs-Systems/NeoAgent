'use strict';

// The part a script cannot do well: the imported agent reads what was left
// behind and rebuilds what it can with tools it may use unattended
// (automations, MCP servers, memory). It runs as a one-time automation, so it happens inside the running
// server like any other task and its result shows up in NeoAgent.

const { insertTask } = require('./neoagent');
const { readText } = require('./common');

const MAX_PROMPT_CHARS = 14000;
const MAX_FILE_CHARS = 4000;
const START_DELAY_MS = 2 * 60 * 1000;
const SECRET_NAME = /(key|token|secret|password|auth)/i;

// Item details can carry a stdio server's env or a job's command; secrets are
// replaced so they never end up in a prompt.
function redact(value) {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, inner]) => (
      [key, SECRET_NAME.test(key) && typeof inner === 'string' ? '[hidden]' : redact(inner)]
    )));
  }
  return value;
}

function leftoverLines(session) {
  return session.entries
    .filter((entry) => (entry.status === 'skipped' || entry.status === 'failed') && entry.kind !== 'Key')
    .map((entry) => `- ${entry.kind} "${entry.name}": ${entry.detail}`);
}

// Source files worth the agent's reading: operating rules the user wrote by
// hand (OpenClaw's AGENTS.md) that have no direct NeoAgent field.
function handWrittenRules(bundles) {
  const parts = [];
  for (const bundle of bundles) {
    for (const agent of bundle.agents) {
      const text = bundle.source === 'openclaw' ? readText(`${agent.workspace}/AGENTS.md`) : null;
      const flagged = bundle.skipped.some((item) => item.name === `${agent.key}/AGENTS.md`);
      if (text && flagged) parts.push(`### ${agent.name} (${bundle.label}) AGENTS.md\n${text.slice(0, MAX_FILE_CHARS)}`);
    }
  }
  return parts;
}

function buildFinishPrompt(bundles, session) {
  const labels = [...new Set(bundles.map((bundle) => bundle.label))].join(' and ');
  const detailed = bundles.flatMap((bundle) => bundle.skipped.filter((item) => item.detail)
    .map((item) => `- ${item.kind} "${item.name}" (${bundle.label}): ${JSON.stringify(redact(item.detail))}`));

  const sections = [
    `The user just moved from ${labels} to NeoAgent. A script already imported keys, agents, memories, skills, automations, MCP servers and chat channels. Finish the move for the parts the script could not translate.`,
    'You run unattended: nobody is there to approve a tool call. Do not use execute_command, file writes or the browser. Work with memory_save, memory_update_core, create_task, list_tasks and mcp_add_server. If a tool is blocked or needs approval, do not retry it; put the exact change in your final message instead.',
    'For each item below, either recreate it the NeoAgent way or decide it is not needed (a local filesystem MCP server is not, for example: NeoAgent has its own file tools). Never invent credentials: where a token is missing, say so in your final message. Do not change anything that was imported correctly.',
    leftoverLines(session).length ? `## Left behind\n${leftoverLines(session).join('\n')}` : '',
    detailed.length ? `## Original definitions\n${detailed.join('\n')}` : '',
    ...handWrittenRules(bundles).map((part) => `## Rules the user wrote by hand\nKeep the ones that still apply as memories or core memory; ignore anything specific to ${labels}'s own tooling.\n${part}`),
    'End with one short notify_user message: what you set up, and what the user still needs to do themselves, with the exact place in NeoAgent to do it.',
  ].filter(Boolean);
  return sections.join('\n\n').slice(0, MAX_PROMPT_CHARS);
}

// Only after a run that brought something over: a repeat run has nothing
// new for the agent, and would queue the same work twice.
function hasLeftovers(session) {
  const imported = session.entries.filter((entry) => entry.status === 'imported');
  if (!imported.some((entry) => entry.kind !== 'Key')) return false;
  return leftoverLines(session).length > 0;
}

// One-time automation for the main agent, shortly after the restart that
// loads everything the import wrote.
function queueFinishTask(session, bundles) {
  const { ctx, userId } = session;
  const name = `Finish moving in from ${[...new Set(bundles.map((bundle) => bundle.label))].join(' and ')}`;
  const agentId = ctx.agents.ensureMainAgent(userId).id;
  const runAt = new Date(Date.now() + START_DELAY_MS).toISOString();
  insertTask(ctx, userId, {
    agentId,
    name,
    triggerConfig: { mode: 'one_time', runAt },
    taskConfig: { prompt: buildFinishPrompt(bundles, session) },
  });
  return name;
}

module.exports = {
  buildFinishPrompt,
  hasLeftovers,
  queueFinishTask,
};
