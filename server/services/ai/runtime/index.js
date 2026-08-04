'use strict';

const { DurableRunRuntime, runOrchestrator } = require('./run_orchestrator');
const { runConversation, getFailureFallbackModelId } = require('./adapter');
const constants = require('./constants');
const stateMachine = require('./run_state_machine');
const leases = require('./leases');
const taskContract = require('./task_contract');
const workGraph = require('./work_graph');
const { createBudgetManager } = require('./budget_manager');
const decisionEngine = require('./decision_engine');
const { evaluateCompletionClaim } = require('./completion_gate');
const { verifyRun } = require('./verification_service');
const recoveryManager = require('./recovery_manager');
const checkpointService = require('./checkpoint_service');
const resourceLockManager = require('./resource_lock_manager');
const outbox = require('./delivery/outbox_repository');
const deliveryWorker = require('./delivery/delivery_worker');
const { createProgressBroker } = require('./delivery/progress_broker');
const { RunEventBus } = require('./events/run_event_bus');
const eventStore = require('./events/run_event_store');
const { EVENT_TYPES, VISIBILITY } = require('./events/event_types');
const { buildContextView } = require('./context/context_view_builder');
const evidencePacketBuilder = require('./context/evidence_packet_builder');
const { createWorkingMemory } = require('./memory/working_memory');
const memoryWritePipeline = require('./memory/memory_write_pipeline');

module.exports = {
  // Primary entry points
  DurableRunRuntime,
  runOrchestrator,
  runConversation,
  getFailureFallbackModelId,

  // Kernel modules
  constants,
  stateMachine,
  leases,
  taskContract,
  workGraph,
  createBudgetManager,
  decisionEngine,
  evaluateCompletionClaim,
  verifyRun,
  recoveryManager,
  checkpointService,
  resourceLockManager,
  outbox,
  deliveryWorker,
  createProgressBroker,
  RunEventBus,
  eventStore,
  EVENT_TYPES,
  VISIBILITY,
  buildContextView,
  evidencePacketBuilder,
  createWorkingMemory,
  memoryWritePipeline,
};
