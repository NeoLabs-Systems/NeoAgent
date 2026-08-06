'use strict';

function isoNow() {
  return new Date().toISOString();
}

// Per-run record of what the agent is doing and when the user last saw
// something. The runtime progress broker reads lastUserVisibleUpdateAt from
// here so its heartbeat never talks over a model-authored interim update.
function buildInitialProgressLedger({ startedAt, retryState = {} } = {}) {
  const startedAtIso = startedAt || isoNow();
  const interimHistory = Array.isArray(retryState.interimHistory)
    ? retryState.interimHistory
      .map((item) => String(item?.content || '').trim())
      .filter(Boolean)
    : [];
  const lastInterimMessage = interimHistory[interimHistory.length - 1] || '';
  const lastVisibleAt = retryState.lastUserVisibleUpdateAt || (lastInterimMessage ? startedAtIso : null);
  return {
    currentStep: retryState.currentStep || null,
    currentTool: retryState.currentTool || null,
    currentStepStartedAt: retryState.currentStepStartedAt || null,
    lastVerifiedProgressAt: retryState.lastVerifiedProgressAt || startedAtIso,
    lastUserVisibleUpdateAt: lastVisibleAt,
    lastFinalDeliveryAt: retryState.lastFinalDeliveryAt || null,
    heartbeatCount: Number(retryState.heartbeatCount || 0),
    stallNotifiedAt: retryState.stallNotifiedAt || null,
    progressState: retryState.progressState || 'active',
    currentPhase: retryState.currentPhase || 'idle',
  };
}

module.exports = {
  buildInitialProgressLedger,
};
