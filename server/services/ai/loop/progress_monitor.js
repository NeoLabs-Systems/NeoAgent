'use strict';

const FIRST_UPDATE_MS = 60 * 1000;
const REPEAT_UPDATE_MS = 90 * 1000;
const STALL_MS = 240 * 1000;
const TICK_MS = 15 * 1000;

function isoNow() {
  return new Date().toISOString();
}

function timestampMs(value, fallback = 0) {
  const resolved = value ? Date.parse(value) : NaN;
  return Number.isFinite(resolved) ? resolved : fallback;
}

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

function evaluateProgressLiveness(runMeta, now = Date.now()) {
  const startedAtMs = Number.isFinite(runMeta?.startedAt) ? runMeta.startedAt : now;
  const ledger = runMeta?.progressLedger || {};
  const lastVerifiedAtMs = timestampMs(ledger.lastVerifiedProgressAt, startedAtMs);
  const lastVisibleAtMs = timestampMs(ledger.lastUserVisibleUpdateAt, 0);
  const thresholdMs = lastVisibleAtMs > 0 ? REPEAT_UPDATE_MS : FIRST_UPDATE_MS;
  const comparisonVisibleAtMs = lastVisibleAtMs > 0 ? lastVisibleAtMs : startedAtMs;
  const shouldNudge = (now - comparisonVisibleAtMs) >= thresholdMs;
  const stalled = (now - lastVerifiedAtMs) >= STALL_MS;

  return {
    startedAtMs,
    thresholdMs,
    shouldNudge,
    stalled,
    phase: ledger.currentPhase || 'idle',
    currentStep: ledger.currentStep || null,
    currentTool: ledger.currentTool || null,
  };
}

function buildProgressNudge({ stalled = false } = {}) {
  return [
    'Internal progress check for the active messaging run.',
    stalled
      ? 'No verified progress has been recorded for the stall threshold.'
      : 'The originating chat has not received a user-visible update for the progress threshold.',
    'On the next normal agent turn, decide whether to continue silently, send a concise model-authored interim update with send_interim_update, report a real blocker, or finish with the final answer.',
    'Do not repeat previous status text and do not treat an interim update as final delivery.',
  ].join(' ');
}

module.exports = {
  FIRST_UPDATE_MS,
  REPEAT_UPDATE_MS,
  STALL_MS,
  TICK_MS,
  buildInitialProgressLedger,
  evaluateProgressLiveness,
  buildProgressNudge,
};
