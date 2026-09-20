'use strict';

const { startLocalCompanion } = require('./local_companion');

/**
 * Keeps this server process registered as every user's companion device.
 *
 * `startLocalCompanion` already maps the companion protocol onto CLIExecutor and
 * WorkspaceManager for a single `neoagent exec` run. TERMINAL_ENV=host needs the
 * same thing for every user, for as long as the server runs, so this only owns
 * the lifecycle: one companion per user, registered on first use, re-registered
 * if its connection ever closes, and closed on shutdown.
 */
class HostCompanionRegistrar {
  #companions = new Map();
  #pending = new Map();

  constructor(options = {}) {
    this.registry = options.registry;
    this.workspaceManager = options.workspaceManager || null;
  }

  async ensure(userId) {
    const key = String(userId || '').trim();
    if (!key) throw new Error('The host computer requires a user ID.');
    if (this.registry?.isConnected(key)) return;
    const inflight = this.#pending.get(key);
    if (inflight) return inflight;
    const promise = this.#start(key).finally(() => this.#pending.delete(key));
    this.#pending.set(key, promise);
    return promise;
  }

  async #start(key) {
    // A companion whose socket closed leaves a dead handle behind; drop it
    // before registering its replacement.
    this.#companions.get(key)?.stop();
    this.#companions.delete(key);
    const workspaceRoot = this.workspaceManager
      ? await this.workspaceManager.getWorkspaceRoot(key)
      : undefined;
    this.#companions.set(key, startLocalCompanion({
      registry: this.registry,
      userId: key,
      workspaceRoot,
    }));
  }

  shutdown() {
    for (const companion of this.#companions.values()) {
      try { companion.stop(); } catch { /* already closed */ }
    }
    this.#companions.clear();
  }
}

module.exports = { HostCompanionRegistrar };
