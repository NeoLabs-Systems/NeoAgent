'use strict';

const express = require('express');
const { Server } = require('socket.io');
const db = require('../../db/database');
const { startServices, stopServices } = require('../manager');
const { getDefaultAgent, getAgentBySlug } = require('./manager');
const { startLocalCompanion } = require('../desktop/local_companion');
const { createModelSelectionId } = require('../ai/model_identity');
const { getSupportedModels } = require('../ai/models');

// Deliberately no way to choose a user. The CLI authenticates nobody, so
// selecting an account here would let anyone with shell access run an agent as
// any user -- with that user's integrations, memory and messaging identity --
// on a multi-user install. A single-account install has no such ambiguity.
function resolveUserId() {
  const users = db.prepare('SELECT id, username FROM users ORDER BY id').all();
  if (users.length === 0) {
    throw new Error('No account exists yet. Run "neoagent setup" first.');
  }
  if (users.length > 1) {
    throw new Error(
      'This install has more than one account, so "neoagent exec" cannot tell '
      + 'which one to run as. Use the web or API interfaces, which authenticate.',
    );
  }
  return users[0].id;
}

// Callers write models the way every other tool does -- "provider/model" --
// while the engine selects on "provider::model". Accept either, so a caller
// never has to know the internal form.
function toModelSelectionId(model) {
  const raw = String(model || '').trim();
  if (!raw || raw.includes('::')) return raw || null;
  const separator = raw.indexOf('/');
  if (separator <= 0) return raw;
  return createModelSelectionId(raw.slice(0, separator), raw.slice(separator + 1));
}

/**
 * Fail when the requested model is not one the account can actually reach.
 *
 * Routing treats an unresolvable override as a hint and quietly falls back to
 * another model. That is reasonable in a chat window and wrong here: a caller
 * that named a model wants that model, and a benchmark that silently measured
 * a different one is worse than a failed run.
 */
async function assertModelAvailable(userId, agentId, selectionId) {
  const models = await getSupportedModels(userId, agentId);
  // Most records already carry a fully qualified id; derive one for any that
  // only carry provider and bare model id.
  const ids = models
    .map((entry) => {
      const id = String(entry?.id || '');
      if (id.includes('::')) return id;
      return entry?.provider && id ? createModelSelectionId(entry.provider, id) : null;
    })
    .filter(Boolean);
  if (ids.includes(selectionId)) return;
  throw new Error(
    `Model ${selectionId} is not available to this account. `
    + `Available: ${ids.slice(0, 10).join(', ') || 'none'}`,
  );
}

function resolveAgentId(userId, slug) {
  if (!slug) {
    return getDefaultAgent(userId).id;
  }
  const agent = getAgentBySlug(userId, slug);
  if (!agent) {
    throw new Error(`No such agent: ${slug}`);
  }
  return agent.id;
}

/**
 * Run a single agent task without the HTTP layer.
 *
 * Boots the same services the server does and calls the same engine entry
 * point as `POST /api/agents`, so headless runs and interactive runs share one
 * code path. `workspaceRoot` pins the run to a directory the caller already
 * controls (a checkout, a benchmark task dir) instead of the per-user
 * workspace the server allocates.
 */
async function runHeadlessTask({
  instruction,
  model = null,
  agent = null,
  workspaceRoot = process.cwd(),
}) {
  const app = express();
  const io = new Server();
  let companion = null;
  await startServices(app, io);
  try {
    const userId = resolveUserId();
    const agentId = resolveAgentId(userId, agent);
    const { agentEngine, memoryManager, desktopCompanionRegistry } = app.locals;
    // Register this process as the user's companion so tools run here, in
    // `workspaceRoot`, over the same 'local' device path the desktop app uses.
    companion = startLocalCompanion({
      registry: desktopCompanionRegistry,
      userId,
      workspaceRoot,
    });
    const runOptions = {
      agentId,
      conversationId: memoryManager.getDefaultWebConversationId(userId, { agentId }),
      deviceTarget: 'local',
      workspaceRoot,
      triggerSource: 'cli',
      stream: false,
    };
    const selectionId = toModelSelectionId(model);
    if (selectionId) await assertModelAvailable(userId, agentId, selectionId);
    return selectionId
      ? await agentEngine.runWithModel(userId, instruction, runOptions, selectionId)
      : await agentEngine.run(userId, instruction, runOptions);
  } finally {
    companion?.stop();
    // No io.close(): this Server was never attached to an HTTP listener, so it
    // owns no sockets, and closing an unattached instance throws.
    await stopServices(app);
  }
}

module.exports = { runHeadlessTask };
