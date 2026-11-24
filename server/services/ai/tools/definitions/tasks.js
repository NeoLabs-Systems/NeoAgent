'use strict';

// Scheduled tasks tools: schemas plus the metadata the harness reads.

const taskTriggerAdapters = require('../../../tasks/adapters');

const TASK_TRIGGER_TYPES = taskTriggerAdapters.map((adapter) => adapter.type).join(', ');

module.exports = [
  {
    name: 'create_task',
    selection: 'default',
    persistent: true,
    resultShape: 'status',
    group: 'tasks', access: 'write', sideEffect: 'task', stateScope: 'tasks', latencyClass: 'local', untrusted: false,
    capabilities: ['task', 'schedule', 'reminder', 'timer', 'cron', 'later'],
    policy: { safe: true },
    whenToUse: ['work that must happen later or repeat'],
    whenNotToUse: ['work you can do right now'],
    description: 'Create a future, recurring, monitored, or background automation. Do not use for immediate work. Resolve references into a self-contained prompt with exact targets, action, notification condition (every run, change, error, or matched condition), destination when known, and any supplied expiry. Use manual for run-on-demand, schedule for one-time/recurring time triggers, and an integration trigger for incoming app events. A successful result is required before claiming the task exists.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Short descriptive name for the task.' },
        trigger: { type: 'object', description: 'Unified trigger object. Prefer { type: "manual" | "schedule" | integration_trigger_type, config: {...} }.' },
        trigger_type: { type: 'string', description: `Trigger type, one of: ${TASK_TRIGGER_TYPES}.` },
        trigger_config: { type: 'object', description: 'Trigger-specific configuration object. For schedule triggers prefer { mode: "recurring", cronExpression: "m h dom mon dow" } or { mode: "one_time", runAt: ISO datetime }. Cron fields and runAt values without an offset are read in the user\'s timezone. 5-field cron only (seconds unsupported). Integration triggers take the connectionId of the connected account. A config the trigger cannot use is answered with the fields it expects.' },
        prompt: { type: 'string', description: 'The instructions the agent will run when the trigger fires.' },
        enabled: { type: 'boolean', description: 'Whether to activate immediately.' },
        model: { type: 'string', description: 'Optional model override.' }
      },
      required: ['name', 'prompt']
    }
  },
  {
    name: 'list_tasks',
    resultShape: 'task_list',
    group: 'tasks', access: 'read', stateScope: 'tasks', latencyClass: 'local', untrusted: false, repeatable: true,
    capabilities: ['task', 'schedule', 'list'],
    policy: { safe: true },
    description: 'List saved background/scheduled tasks for this user and agent. Do not use for ordinary immediate replies.',
    parameters: { type: 'object', properties: {} }
  },
  {
    name: 'delete_task',
    resultShape: 'status',
    group: 'tasks', access: 'write', sideEffect: 'task', stateScope: 'tasks', latencyClass: 'local', untrusted: false,
    capabilities: ['task', 'delete'],
    description: 'Delete a saved background/scheduled task by its ID.',
    parameters: {
      type: 'object',
      properties: {
        task_id: { type: 'number', description: 'The numeric ID of the task to delete.' }
      },
      required: ['task_id']
    }
  },
  {
    name: 'update_task',
    persistent: true,
    resultShape: 'status',
    group: 'tasks', access: 'write', sideEffect: 'task', stateScope: 'tasks', latencyClass: 'local', untrusted: false,
    capabilities: ['task', 'schedule', 'update'],
    policy: { safe: true },
    description: 'Update an existing saved background/scheduled task, including its trigger, prompt, or enabled state.',
    parameters: {
      type: 'object',
      properties: {
        task_id: { type: 'number', description: 'The numeric ID of the task to update.' },
        name: { type: 'string', description: 'New name for the task.' },
        trigger: { type: 'object', description: 'Unified trigger object. Use { type, config } to update trigger in one section.' },
        trigger_type: { type: 'string', description: 'Updated trigger type, e.g. manual, schedule, or integration trigger type.' },
        trigger_config: { type: 'object', description: 'Updated trigger-specific configuration. For schedule triggers use mode+cronExpression (recurring) or mode+runAt (one_time), both read in the user\'s timezone unless runAt carries an offset.' },
        prompt: { type: 'string', description: 'Updated task prompt.' },
        enabled: { type: 'boolean', description: 'Enable or disable the task.' },
        model: { type: 'string', description: 'Specific AI model ID for this task. Set to empty string to clear the override.' }
      },
      required: ['task_id']
    }
  },
];
