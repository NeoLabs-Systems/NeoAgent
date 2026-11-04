'use strict';

// Run control tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'task_ledger',
    selection: 'always',
    group: 'control', stepType: 'note', access: 'read', latencyClass: 'instant', untrusted: false, repeatable: true,
    capabilities: ['plan', 'checklist', 'steps', 'progress'],
    policy: { safe: true },
    whenToUse: ['multi-step work you need to keep track of, alongside your next real action'],
    whenNotToUse: ['anything a couple of calls can settle', 'as a turn on its own'],
    description: 'Keep the record of a multi-step task: its goal, constraints, steps, what you have found, and what blocks you. It survives context compaction and the user can see it. Send only the fields that changed.',
    parameters: {
      type: 'object',
      properties: {
        goal: { type: 'string', description: 'What the whole task is meant to achieve.' },
        constraints: { type: 'array', items: { type: 'string' }, description: 'Rules the work has to respect.' },
        steps: {
          type: 'array',
          description: 'The steps, in order, with their current status.',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string', description: 'Short step name.' },
              status: { type: 'string', enum: ['pending', 'active', 'done', 'blocked'] },
            },
            required: ['id', 'status'],
          },
        },
        observations: { type: 'array', items: { type: 'string' }, description: 'What you have found out so far. These are your own notes: what the run actually did is recorded separately.' },
        blockers: { type: 'array', items: { type: 'string' }, description: 'What stops progress right now.' },
      },
    },
  },
  {
    name: 'search_tools',
    selection: 'always',
    group: 'control', access: 'read', latencyClass: 'instant', untrusted: false,
    capabilities: ['tools', 'discover'],
    policy: { safe: true },
    description: 'Search the complete tool registry by capability. Use this only when no tool in the listed catalog fits; the result returns exact names and descriptions for activate_tools.',
    access: 'read',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Describe the capability or action you need.' },
        limit: { type: 'integer', minimum: 1, maximum: 12, description: 'Maximum matches to return (default 8).' }
      },
      required: ['query']
    }
  },
  {
    name: 'activate_tools',
    selection: 'always',
    group: 'control', access: 'write', latencyClass: 'instant', untrusted: false, exclusive: true,
    capabilities: ['tools', 'activate'],
    policy: { safe: true },
    description: 'Activate tools by exact name from the tool catalog or search_tools. Activated schemas become available on the next model turn; unrelated active schemas may be replaced when the schema limit is full.',
    parameters: {
      type: 'object',
      properties: {
        names: {
          type: 'array',
          items: { type: 'string' },
          description: 'Exact tool names from the tool catalog or search_tools.'
        }
      },
      required: ['names']
    }
  },
  {
    name: 'background_task',
    group: 'control', access: 'write', sideEffect: 'agent', stateScope: 'agents', latencyClass: 'instant', repeatable: true,
    capabilities: ['background', 'task', 'status'],
    availableWhen: (options) => options.triggerType === 'user' && ['web', 'messaging', 'voice_live'].includes(options.triggerSource),
    description: 'Check on, instruct, or cancel a task the user started earlier that is still running in the background. Running background tasks are listed in the conversation context.',
    parameters: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['status', 'instruct', 'cancel'], description: 'status: fresh progress (omit run_id to list all); instruct: pass a change or addition on to the task; cancel: stop the task.' },
        run_id: { type: 'string', description: 'run_id of the background task. Required for instruct and cancel.' },
        instruction: { type: 'string', description: 'For instruct: the change or addition, self-contained, with everything the task needs to apply it.' }
      },
      required: ['action']
    }
  },
];
