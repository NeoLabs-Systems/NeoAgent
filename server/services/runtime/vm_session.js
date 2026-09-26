'use strict';

const crypto = require('crypto');
const net = require('net');

// Session and start-up bookkeeping shared by every computer runtime backend
// (QEMU micro-VMs and Docker containers). The backends differ only in how they
// boot a guest; how a start is de-duplicated and how a user without a running
// guest is reported are the same either way.

function isProcessAlive(processHandle) {
  if (!processHandle || processHandle.killed || processHandle.exitCode != null) return false;
  if (!Number.isInteger(processHandle.pid) || processHandle.pid <= 0) return false;
  try {
    process.kill(processHandle.pid, 0);
    return true;
  } catch {
    return false;
  }
}

// A loopback port for the host side of a guest's agent connection.
function findAvailablePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

function isQueueableCapacityError(error) {
  return error?.code === 'COMPUTER_CAPACITY';
}

// Per-user directory and container names are derived from a hash so a user ID
// never leaks into a filesystem path or a Docker object name.
function userDirectoryKey(userId) {
  return crypto.createHash('sha256').update(String(userId)).digest('hex').slice(0, 24);
}

// Tracks in-flight starts and the state of users whose guest is not running, so
// the UI can distinguish starting, sleeping, waiting for capacity, and failed.
class VmStartTracker {
  #pending = new Map();
  #transient = new Map();

  // Run `startGuest` once per user, sharing the promise with concurrent callers
  // and recording the outcome as transient status.
  begin(key, startGuest) {
    const existing = this.#pending.get(key);
    if (existing) return existing;
    this.#transient.set(key, { state: 'starting', startedAt: new Date().toISOString() });
    const promise = Promise.resolve()
      .then(startGuest)
      .then((session) => {
        this.#transient.delete(key);
        return session;
      })
      .catch((error) => {
        this.fail(key, error);
        throw error;
      })
      .finally(() => this.#pending.delete(key));
    this.#pending.set(key, promise);
    return promise;
  }

  // The status of a user with no live session, or null when nothing is known.
  status(key) {
    const transient = this.#transient.get(key);
    if (!transient) return null;
    return { ...transient, error: transient.lastError || null };
  }

  fail(key, error) {
    const message = String(error?.message || error || 'Cloud computer failed.');
    this.#transient.set(key, {
      state: isQueueableCapacityError(error) ? 'capacity_wait' : 'error',
      lastError: message,
      error: message,
      errorCode: error?.code || null,
    });
  }

  sleep(key) {
    this.#transient.set(key, { state: 'sleeping' });
  }

  clear(key) {
    this.#transient.delete(key);
  }

  clearAll() {
    this.#transient.clear();
  }

  settled() {
    return Promise.allSettled(this.#pending.values());
  }
}

module.exports = {
  VmStartTracker,
  findAvailablePort,
  isProcessAlive,
  isQueueableCapacityError,
  userDirectoryKey,
};
