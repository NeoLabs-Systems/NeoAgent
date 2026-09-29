'use strict';

const EVENT_TYPES = Object.freeze({
  RUN_ACCEPTED: 'run.accepted',
  RUN_STATE_CHANGED: 'run.state_changed',
  NODE_PROGRESS: 'node.progress',
  MODEL_STARTED: 'model.started',
  MODEL_REQUEST_RECORDED: 'model.request_recorded',
  CONTEXT_PRESSURE: 'context.pressure',
  CONTEXT_COMPACTED: 'context.compacted',
  CONTEXT_OVERFLOW_RECOVERED: 'context.overflow_recovered',
  TOOL_STARTED: 'tool.started',
  TOOL_COMPLETED: 'tool.completed',
  TOOL_FAILED: 'tool.failed',
  ARTIFACT_CREATED: 'artifact.created',
  CHECKPOINT_SAVED: 'checkpoint.saved',
  PROGRESS_USER_UPDATE: 'progress.user_update',
  DELIVERY_COMMITTED: 'delivery.committed',
  DELIVERY_CONFIRMED: 'delivery.confirmed',
  RUN_COMPLETED: 'run.completed',
  RUN_FAILED: 'run.failed',
  RUN_CANCELLED: 'run.cancelled',
});

const VISIBILITY = Object.freeze({
  INTERNAL: 'internal',
  OPERATOR: 'operator',
  USER: 'user',
});

module.exports = {
  EVENT_TYPES,
  VISIBILITY,
};
