'use strict';

const { normalizeTrimmedText } = require('../security');
const { summaryParts } = require('./shared');

const OUTCOMES = Object.freeze(['any', 'succeeded', 'failed']);
// Tasks that trigger each other stop after this many runs in a row.
const MAX_CHAIN_DEPTH = 3;

module.exports = {
  type: 'task_run_finished',
  label: 'Another Task Finished',
  configHint: '{ sourceTaskId, outcome?: any|succeeded|failed }; each run receives the other task\'s result or error',
  async validateConfig(config = {}, context = {}) {
    const sourceTaskId = Number(config.sourceTaskId ?? config.source_task_id);
    if (!Number.isInteger(sourceTaskId) || sourceTaskId <= 0) {
      throw new Error('Choose the task whose runs should trigger this one.');
    }
    if (context.taskId && sourceTaskId === Number(context.taskId)) {
      throw new Error('A task cannot be triggered by its own runs.');
    }
    const outcome = normalizeTrimmedText(config.outcome, 20).toLowerCase() || 'any';
    if (!OUTCOMES.includes(outcome)) {
      throw new Error(`Outcome must be one of: ${OUTCOMES.join(', ')}.`);
    }
    return { sourceTaskId, outcome };
  },
  summarize(config = {}) {
    return summaryParts('After task', [`#${config.sourceTaskId}`, config.outcome !== 'any' && config.outcome]);
  },
  event: {
    source: 'runtime',
    name: 'task_run_finished',
    matches(config, event, task) {
      return Number(event.taskId) === config.sourceTaskId
        && Number(event.taskId) !== Number(task.id)
        && event.chainDepth <= MAX_CHAIN_DEPTH
        && (config.outcome === 'any' || config.outcome === event.outcome);
    },
    toPayload(event) {
      return {
        fingerprint: `task_run:${event.taskId}:${event.runId || event.finishedAt}`,
        timestamp: event.finishedAt,
        context: {
          triggerEvent: {
            provider: 'tasks',
            event: 'task_run_finished',
            taskId: event.taskId,
            taskName: event.taskName,
            outcome: event.outcome,
            result: event.result,
            error: event.error,
            chainDepth: event.chainDepth,
          },
        },
      };
    },
  },
};
