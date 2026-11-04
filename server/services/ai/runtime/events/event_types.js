'use strict';

// The run ledger's whole vocabulary. Keep it small: a new kind of event has to
// answer a question the Runs tab or an eval cannot answer from these.
const EVENT_TYPES = Object.freeze({
  RUN_STARTED: 'run.started',
  RUN_STATE: 'run.state',
  RUN_COMPLETED: 'run.completed',
  RUN_FAILED: 'run.failed',
  RUN_CANCELLED: 'run.cancelled',
  CONTEXT_BUILT: 'context.built',
  CONTEXT_COMPACTED: 'context.compacted',
  MEMORY_RECALL: 'memory.recall',
  MEMORY_WRITE: 'memory.write',
  MODEL_REQUEST: 'model.request',
  MODEL_RESPONSE: 'model.response',
  TOOLS_SELECTED: 'tools.selected',
  TOOL_CALL: 'tool.call',
  TOOL_RESULT: 'tool.result',
  TOOL_SUPPRESSED: 'tool.suppressed',
  PERMISSION_DECISION: 'permission.decision',
  WORKSPACE_CHANGED: 'workspace.changed',
  CHECKPOINT_CREATED: 'checkpoint.created',
  CHECKPOINT_RESTORED: 'checkpoint.restored',
  DELIVERY_RESERVED: 'delivery.reserved',
  DELIVERY_SENT: 'delivery.sent',
  DELIVERY_FAILED: 'delivery.failed',
  DELIVERY_SUPPRESSED: 'delivery.suppressed',
  RECOVERY_TRIGGERED: 'recovery.triggered',
});

const EVENT_SCHEMA_VERSION = 1;

module.exports = {
  EVENT_SCHEMA_VERSION,
  EVENT_TYPES,
};
