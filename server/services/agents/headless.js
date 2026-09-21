'use strict';

const express = require('express');
const { Server } = require('socket.io');
const db = require('../../db/database');
const { startServices, stopServices } = require('../manager');
const { getDefaultAgent, getAgentBySlug } = require('./manager');
const { startLocalCompanion } = require('../desktop/local_companion');
const { createModelSelectionId } = require('../ai/model_identity');
const { getSupportedModels } = require('../ai/models');
const { getTerminalEnv, TERMINAL_ENV_HOST } = require('../../utils/deployment');
const fsp = require('node:fs/promises');
const path = require('node:path');

// Directories never worth copying into a guest -- version control metadata
// and dependency trees a benchmark task has no business shipping.
const SEED_EXCLUDE_DIRS = new Set(['.git', 'node_modules', '.neobench', '__pycache__']);

/**
 * Copy a host directory's files into the guest workspace before the run.
 *
 * The Docker/QEMU guest has its OWN persistent workspace
 * (/home/neo/workspace, guest_paths.js) with no bind mount to the host --
 * unlike a host-bind-mounted container, nothing here is visible to the guest
 * unless it is copied in explicitly. This is what lets `exec --cwd <task
 * dir>` actually hand the agent its task files when running containerized.
 *
 * Text files only: readFile/writeFile speak UTF-8 strings over the guest's
 * HTTP API, so a file that fails to decode as UTF-8 (almost always binary)
 * is skipped rather than corrupted. A task needing binary fixtures inside
 * the guest needs a different mechanism than this one.
 */
async function seedGuestWorkspace(client, runtimeManager, userId, deviceTarget, hostRoot) {
  /*
   * The guest workspace is a NAMED VOLUME that survives across every `exec`
   * invocation for this account -- it is not created fresh per trial the way
   * a host-bind-mounted container would be. Left alone, trial N's files (and
   * this fixture's own leftover probe.txt, discovered testing this) leak
   * into trial N+1: a file_state grader could see a file the CURRENT trial
   * never wrote, and `ls` results the agent reads would be contaminated by a
   * previous, unrelated task. There is no delete endpoint on the workspace
   * API, so this goes through the guest's own /exec instead -- the same
   * endpoint its shell tool uses.
   */
  await runtimeManager.requestComputer(
    userId, 'POST', '/exec',
    { command: 'rm -rf /home/neo/workspace/* /home/neo/workspace/.[!.]* 2>/dev/null; true' },
    { deviceTarget },
  ).catch(() => {}); // an empty workspace failing to "empty" further is not fatal

  const skipped = [];
  const files = await listFilesRecursive(hostRoot, SEED_EXCLUDE_DIRS);
  for (const relPath of files) {
    let content;
    try {
      content = await fsp.readFile(path.join(hostRoot, relPath), 'utf8');
    } catch {
      skipped.push(relPath); // binary or unreadable
      continue;
    }
    const result = await client.writeFile(userId, { path: relPath, content, deviceTarget });
    if (!result?.success) skipped.push(relPath);
  }
  return { seeded: files.length - skipped.length, skipped };
}

/** Recursively list a host directory's files as workspace-relative paths. */
async function listFilesRecursive(root, excludeDirs, relDir = '') {
  const absDir = path.join(root, relDir);
  let entries;
  try {
    entries = await fsp.readdir(absDir, { withFileTypes: true });
  } catch {
    return [];
  }
  const out = [];
  for (const entry of entries) {
    if (entry.name.startsWith('.') && entry.name !== '.') continue;
    const rel = relDir ? `${relDir}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      if (excludeDirs.has(entry.name)) continue;
      out.push(...await listFilesRecursive(root, excludeDirs, rel));
    } else if (entry.isFile()) {
      out.push(rel);
    }
  }
  return out;
}

/**
 * Copy the guest workspace's files back to the host after the run, so a
 * file-state grader reading the HOST directory sees what the agent actually
 * wrote -- the same contract file_state graders already rely on for a
 * host-bind-mounted container.
 *
 * readFile truncates any single file over 20000 characters (its own,
 * pre-existing limit, shared with the desktop chat UI) -- a large output
 * file syncs back truncated rather than not at all. Documented, not solved:
 * fixing that would mean adding a new guest API, which is out of scope here.
 */
async function syncGuestWorkspaceBack(client, userId, deviceTarget, hostRoot) {
  const synced = [];
  const truncated = [];
  const entries = await listGuestFilesRecursive(client, userId, deviceTarget);
  for (const entry of entries) {
    const result = await client.readFile(userId, { path: entry.path, deviceTarget });
    if (result?.error || result?.content == null) continue;
    const dest = path.join(hostRoot, entry.path);
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    await fsp.writeFile(dest, result.content);
    synced.push(entry.path);
    if (typeof result.content === 'string' && result.content.endsWith('...[truncated]')) {
      truncated.push(entry.path);
    }
  }
  return { synced: synced.length, truncated };
}

/** Recursively list the guest workspace's files (not directories). */
async function listGuestFilesRecursive(client, userId, deviceTarget, relDir = '') {
  const listing = await client.listDirectory(userId, { path: relDir || '.', deviceTarget });
  if (listing?.error) return [];
  const out = [];
  for (const entry of listing.entries || []) {
    if (entry.type === 'directory') {
      out.push(...await listGuestFilesRecursive(client, userId, deviceTarget, entry.path));
    } else {
      out.push(entry);
    }
  }
  return out;
}


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
  // Explicit provider, e.g. from `neoagent exec --provider openrouter`.
  // Kept separate from `model` rather than folded into a "provider/model"
  // string: OpenRouter's own model ids often contain a slash themselves
  // (e.g. "inclusionai/ling-3.0-flash-vl:free"), which toModelSelectionId's
  // first-slash split would misparse as provider="inclusionai". Passing
  // provider and model as two arguments removes that ambiguity outright.
  provider = null,
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

    /*
     * `exec`'s tools ran on the host UNCONDITIONALLY, no matter what
     * TERMINAL_ENV said: this always registered the 'local' device (this
     * process, right here) and the chat/desktop path's TERMINAL_ENV=docker
     * routing -- which really does isolate shell and file tools, not only
     * screen/browser control, through the exact same ComputerWorkspaceClient
     * every tool call goes through -- was never reached from the CLI at all.
     *
     * deviceTarget is the ONLY thing that decides which backend a tool call
     * reaches (server/services/runtime/manager.js#_computerBackendForUser):
     * 'local' always means the desktop-companion device registered below;
     * anything else means the VM-backed backend TERMINAL_ENV built at
     * startup (createComputerBackend, in backend_factory.js). So `exec` now
     * asks for 'cloud' whenever TERMINAL_ENV says anything other than host,
     * and only registers the local companion as a fallback for the case that
     * actually needs it.
     */
    const containerized = getTerminalEnv() !== TERMINAL_ENV_HOST;
    const deviceTarget = containerized ? 'cloud' : 'local';

    if (!containerized) {
      // Register this process as the user's companion so tools run here, in
      // `workspaceRoot`, over the 'local' device path the desktop app uses.
      companion = startLocalCompanion({
        registry: desktopCompanionRegistry,
        userId,
        workspaceRoot,
      });
    }
    const runOptions = {
      agentId,
      conversationId: memoryManager.getDefaultWebConversationId(userId, { agentId }),
      deviceTarget,
      workspaceRoot,
      triggerSource: 'cli',
      stream: false,
    };
    // An explicit --provider always wins over guessing from --model's shape:
    // it is unambiguous, and it is what the caller asked for.
    const selectionId = provider
      ? createModelSelectionId(provider, model)
      : toModelSelectionId(model);
    if (provider && !model) {
      throw new Error('--provider requires --model (a provider alone does not select a model).');
    }
    if (selectionId) await assertModelAvailable(userId, agentId, selectionId);

    // The guest has no bind mount to workspaceRoot -- copy the caller's
    // files in first, or the agent opens an empty directory no matter what
    // --cwd said.
    if (containerized) {
      const { computerWorkspaceManager, runtimeManager } = app.locals;
      const { seeded, skipped } = await seedGuestWorkspace(computerWorkspaceManager, runtimeManager, userId, deviceTarget, workspaceRoot);
      if (skipped.length) {
        console.error(`[exec] ${skipped.length} file(s) not copied into the guest workspace (binary or unreadable): ${skipped.slice(0, 10).join(', ')}`);
      }
      console.error(`[exec] copied ${seeded} file(s) from ${workspaceRoot} into the guest workspace`);
    }

    let result;
    try {
      result = selectionId
        ? await agentEngine.runWithModel(userId, instruction, runOptions, selectionId)
        : await agentEngine.run(userId, instruction, runOptions);
    } finally {
      // Copy back even if the run itself failed or threw -- partial output
      // is exactly what a grader most needs to see, and this is the ONLY
      // opportunity: the guest's workspace does not survive past this
      // process the way a host bind mount would.
      if (containerized) {
        const { computerWorkspaceManager } = app.locals;
        const { synced, truncated } = await syncGuestWorkspaceBack(computerWorkspaceManager, userId, deviceTarget, workspaceRoot)
          .catch((err) => { console.error(`[exec] could not sync the guest workspace back: ${err.message}`); return { synced: 0, truncated: [] }; });
        if (truncated.length) {
          console.error(`[exec] ${truncated.length} synced file(s) were truncated at the guest's 20000-character read limit: ${truncated.slice(0, 10).join(', ')}`);
        }
        console.error(`[exec] synced ${synced} file(s) from the guest workspace back to ${workspaceRoot}`);
      }
    }
    return result;
  } finally {
    companion?.stop();
    // No io.close(): this Server was never attached to an HTTP listener, so it
    // owns no sockets, and closing an unattached instance throws.
    await stopServices(app);
  }
}

module.exports = { runHeadlessTask };
