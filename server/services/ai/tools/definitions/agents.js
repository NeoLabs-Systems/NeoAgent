'use strict';

// Sub-agents and agent-task tools: schemas plus the metadata the harness reads.

const { DEFAULT_POLICY } = require('../../../security/default_policy');

const TOOL_CATEGORY_NAMES = Object.keys(DEFAULT_POLICY);

module.exports = [
  {
    name: 'spawn_subagent',
    resultShape: 'subagent_started',
    group: 'agents', stepType: 'subagent', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'instant', repeatable: true, untrusted: false,
    capabilities: ['subagent', 'parallel', 'delegate'],
    policy: { safe: true },
    whenToUse: ['independent sub-problems that benefit from parallel work or isolated context'],
    whenNotToUse: ['a single sequential task you can do yourself'],
    description: 'Start an independent sub-agent in the background for separate work: exploring several areas at once, or a task whose detail would crowd your context. Returns a handle at once; collect its result with wait_subagent. The result includes what the run recorded, so check that rather than trusting its summary. Read-only unless write is set.',
    parameters: {
      type: 'object',
      properties: {
        task: { type: 'string', description: 'The task for the sub-agent to complete' },
        model: { type: 'string', description: 'Optional model override selected from the live model catalog.' },
        context: { type: 'string', description: 'Only the constraints and evidence the sub-agent needs.' },
        required_artifacts: { type: 'array', items: { type: 'string' }, description: 'Artifacts the sub-agent must return.' },
        tools: { type: 'array', items: { type: 'string' }, description: 'Limit the sub-agent to these tools. Enforced.' },
        write: { type: 'boolean', description: 'Allow it to change things. Off by default, and only one at a time may have it; the parent cannot change the workspace while it runs.' },
        max_turns: { type: 'integer', description: 'Model turns it may use. Default 30, at most 60.' },
        max_tokens: { type: 'integer', description: 'Tokens it may use. Default 300000.' },
        max_seconds: { type: 'integer', description: 'Time it may take. Default 600, at most 1800.' }
      },
      required: ['task']
    }
  },
  {
    name: 'delegate_to_agent',
    group: 'agents', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'instant', repeatable: true, untrusted: false,
    capabilities: ['agent', 'delegate', 'handoff', 'specialist'],
    policy: { safe: true },
    whenToUse: [
      'a part of the work falls squarely in another agent\'s responsibility and it benefits from that agent\'s own memory, tools or context',
      'handoff: the request belongs to another agent from now on',
    ],
    whenNotToUse: [
      'a quick or tightly connected step you can do yourself',
      'parallel throwaway exploration (use spawn_subagent)',
    ],
    description: 'Give a task to one of your fellow agents. It runs in the background in that agent\'s own run and returns at once with a task_id; you are not blocked. By default you stay responsible and its result comes back to you as an agent task update. Set handoff when the request belongs to that agent from now on; its result then reaches the user without you. Pass only what it needs: it does not see your conversation.',
    parameters: {
      type: 'object',
      properties: {
        agent: { type: 'string', description: 'The agent, by identifier or name.' },
        task: { type: 'string', description: 'What it should achieve, self-contained.' },
        context: { type: 'string', description: 'Only the facts, constraints and references it needs. No secrets.' },
        expected_output: { type: 'string', description: 'What a finished result looks like.' },
        handoff: { type: 'boolean', description: 'Hand the request over for good instead of getting the result back.' },
        allow_external_side_effects: { type: 'boolean', description: 'Set true only when the user wants that agent to send messages or change outside systems itself.' }
      },
      required: ['agent', 'task']
    }
  },
  {
    name: 'agent_task',
    group: 'agents', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'instant', repeatable: true, untrusted: false,
    capabilities: ['agent', 'task', 'status', 'message', 'handoff'],
    policy: { safe: true },
    description: 'Work with agent tasks you asked for or own. list: your open tasks. status: one task, with its result once done; wait_seconds waits up to 120 s for it to move on. message: send an answer, a question or new information about an open task (as its owner, a question makes the task wait for the reply). handoff: as the owner, pass the task on to another agent. cancel: stop a task you asked for.',
    parameters: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['list', 'status', 'message', 'handoff', 'cancel'] },
        task_id: { type: 'string', description: 'The task, from delegate_to_agent or an agent task update.' },
        message: { type: 'string', description: 'For message: the text. For handoff and cancel: an optional note.' },
        agent: { type: 'string', description: 'For handoff: the agent that takes it over.' },
        wait_seconds: { type: 'integer', description: 'For status: how long to wait for a change, at most 120.' }
      },
      required: ['action']
    }
  },
  {
    name: 'create_agent',
    group: 'agents', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'instant', untrusted: false,
    capabilities: ['agent', 'create', 'specialist'],
    policy: { category: 'agent_creation' },
    whenToUse: [
      'the user asks for a lasting agent for something',
      'a lasting area of responsibility has emerged that needs its own memory, context or ownership',
    ],
    whenNotToUse: [
      'one-off work (do it, or use spawn_subagent)',
      'something that only has to happen on a schedule (a task on an existing agent covers it)',
      'an existing agent already covers the responsibility',
    ],
    description: 'Create a new persistent agent: a lasting specialist with its own chat and memory that the user sees and manages next to you. It never gets more permissions than you have. Give it one clear responsibility, not a generic helper role.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Short display name.' },
        responsibility: { type: 'string', description: 'The lasting area it owns, in one or two sentences.' },
        description: { type: 'string', description: 'One line on what it is good at.' },
        instructions: { type: 'string', description: 'How it should work, if it differs from the default.' },
        reason: { type: 'string', description: 'Why this needs its own agent; shown to the user.' },
        ask_first: { type: 'array', items: { type: 'string', enum: TOOL_CATEGORY_NAMES }, description: 'Tool categories it must ask the user about before each use.' },
        not_allowed: { type: 'array', items: { type: 'string', enum: TOOL_CATEGORY_NAMES }, description: 'Tool categories it may not use at all.' }
      },
      required: ['name', 'responsibility', 'reason']
    }
  },
  {
    name: 'list_subagents',
    resultShape: 'subagents',
    group: 'agents', stepType: 'subagent', access: 'read', stateScope: 'agents', latencyClass: 'instant', repeatable: true, untrusted: false,
    capabilities: ['subagent', 'status'],
    description: 'List the async sub-agents that belong to the current parent run, including status and any finished results.',
    parameters: { type: 'object', properties: {} }
  },
  {
    name: 'wait_subagent',
    resultShape: 'subagents',
    group: 'agents', stepType: 'subagent', access: 'read', stateScope: 'agents', latencyClass: 'slow', repeatable: true, exclusive: true,
    capabilities: ['subagent', 'wait'],
    description: 'Wait for a spawned sub-agent to finish and return its result.',
    parameters: {
      type: 'object',
      properties: {
        handle: { type: 'string', description: 'The handle returned by spawn_subagent.' },
        timeout_ms: { type: 'number', description: 'Optional timeout in milliseconds (default 30000).' }
      },
      required: ['handle']
    }
  },
  {
    name: 'cancel_subagent',
    resultShape: 'subagents',
    group: 'agents', stepType: 'subagent', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'instant', untrusted: false,
    capabilities: ['subagent', 'cancel'],
    description: 'Cancel a spawned sub-agent by handle.',
    parameters: {
      type: 'object',
      properties: {
        handle: { type: 'string', description: 'The handle returned by spawn_subagent.' }
      },
      required: ['handle']
    }
  },
];
