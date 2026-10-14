'use strict';

const db = require('../../../db/database');
const { getAiSettings } = require('../settings');
const { getProviderForUser } = require('../provider_selector');
const { inferTaskKind, normalizeTaskModels } = require('../task_models');

// After a tool turn, moves the run onto the model the user pinned for the
// kind of work those tools show, and back to the run's own model when the work
// has no pin. Turns with no recognised tools leave the model alone. A failure
// to switch keeps the current model.
async function applyTaskModel(session, toolCalls) {
  if (session.explicitModel) return;
  const kind = inferTaskKind((toolCalls || []).map((call) => call.name));
  if (!kind) return;

  const pinned = normalizeTaskModels(
    getAiSettings(session.userId, session.agentId).task_models,
  )[kind];
  const wanted = pinned || session.baseModelSelectionId;
  if (!wanted || wanted === session.model.modelSelectionId) return;
  if (session.failedModelIds.has(wanted)) return;
  session.unroutableTaskModels ||= new Set();
  if (session.unroutableTaskModels.has(wanted)) return;

  try {
    const selected = await getProviderForUser(
      session.userId,
      session.userMessage,
      session.triggerType === 'subagent',
      wanted,
      { ...session.providerStatusConfig, onStatus: null, signal: session.getActiveSignal() },
    );
    // The router falls back to another model when the pinned one is not
    // routable; stay on the current model rather than adopt that fallback.
    if (selected.modelSelectionId !== wanted) {
      session.unroutableTaskModels.add(wanted);
      return;
    }
    session.model = {
      provider: selected.provider,
      providerName: selected.providerName,
      model: selected.model,
      modelSelectionId: selected.modelSelectionId,
    };
    db.prepare('UPDATE agent_runs SET model = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(selected.modelSelectionId, session.runId);
  } catch (error) {
    console.warn(`[Runtime] Task model switch to ${wanted} failed:`, error?.message || error);
  }
}

module.exports = { applyTaskModel };
