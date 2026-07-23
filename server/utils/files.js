'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { createAbortError, throwIfAborted } = require('./abort');

async function writeBufferAtomic(destination, data, options = {}) {
  const target = String(destination || '').trim();
  if (!target) throw new Error('Atomic file destination is required.');
  const resolved = path.resolve(target);
  const temporary = `${resolved}.${process.pid}.${randomUUID()}.tmp`;
  throwIfAborted(options.signal, 'File write was aborted.');
  try {
    await fs.promises.writeFile(temporary, data, {
      flag: 'wx',
      mode: options.mode ?? 0o600,
      signal: options.signal,
    });
    throwIfAborted(options.signal, 'File write was aborted.');
    await fs.promises.rename(temporary, resolved);
    return resolved;
  } catch (error) {
    if (options.signal?.aborted) throw createAbortError(options.signal, 'File write was aborted.');
    throw error;
  } finally {
    await fs.promises.rm(temporary, { force: true }).catch(() => {});
  }
}

module.exports = { writeBufferAtomic };
