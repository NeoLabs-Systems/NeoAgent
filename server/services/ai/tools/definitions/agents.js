'use strict';

// Sub-agents and delegation tools: schemas plus the metadata the harness reads.

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
    group: 'agents', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'slow', repeatable: true,
    capabilities: ['agent', 'delegate', 'specialist'],
    policy: { safe: true },
    description: 'Delegate a task to a named specialist agent. Use only when that agent clearly matches the task; if unsure, handle it yourself.',
    parameters: {
      type: 'object',
      properties: {
        agent: { type: 'string', description: 'Target agent slug, display name, or ID.' },
        task: { type: 'string', description: 'Self-contained task for the specialist agent.' },
        context: { type: 'string', description: 'Relevant context to pass. Do not include secrets unless the user explicitly asked.' },
        allow_external_side_effects: { type: 'boolean', description: 'Set true only when the user explicitly wants the delegated agent to send messages or affect external systems.' }
      },
      required: ['agent', 'task']
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
