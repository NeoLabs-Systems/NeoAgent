'use strict';

const crypto = require('crypto');
const fs = require('fs');
const { Transform } = require('stream');
const { pipeline } = require('stream/promises');

const MAX_COMMAND_OUTPUT_BYTES = 16 * 1024 * 1024;

function uploadError(message, status = 400, code = 'COMMAND_OUTPUT_UPLOAD_INVALID') {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  return error;
}

function parseContentLength(value) {
  const byteSize = Number(value);
  if (!Number.isSafeInteger(byteSize) || byteSize <= 0) {
    throw uploadError('A positive Content-Length is required.');
  }
  if (byteSize > MAX_COMMAND_OUTPUT_BYTES) {
    throw uploadError('Command output exceeds the 16 MiB artifact limit.', 413);
  }
  return byteSize;
}

function parseChecksum(value) {
  const checksum = String(value || '').trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(checksum)) {
    throw uploadError('A SHA-256 command output checksum is required.');
  }
  return checksum;
}

async function uploadDesktopCommandOutput(options) {
  const {
    userId,
    deviceId,
    commandId,
    contentLength,
    checksum,
    complete,
    stdoutBytes,
    stderrBytes,
    stream,
    registry,
    artifactStore,
  } = options;
  if (!registry || !artifactStore) {
    throw uploadError('Desktop command output storage is unavailable.', 503);
  }
  const context = registry.claimPendingCommandOutput(userId, deviceId, commandId);
  if (!context) {
    throw uploadError(
      'Command output is not tied to an active desktop command.',
      409,
      'COMMAND_OUTPUT_NOT_PENDING',
    );
  }
  const expectedBytes = parseContentLength(contentLength);
  const expectedChecksum = parseChecksum(checksum);
  let allocation = null;
  try {
    allocation = artifactStore.allocateFile(userId, {
      kind: 'command-output',
      backend: 'desktop-companion',
      extension: 'log',
      contentType: 'text/plain; charset=utf-8',
      filenameBase: 'command-output',
      metadata: {
        deviceId: context.deviceId,
        sessionId: context.sessionId,
        commandId: context.commandId,
        runId: context.runId,
        stepId: context.stepId,
        stdoutBytes,
        stderrBytes,
        complete,
      },
    });
    const hash = crypto.createHash('sha256');
    let receivedBytes = 0;
    const guard = new Transform({
      transform(chunk, _encoding, callback) {
        receivedBytes += chunk.length;
        if (receivedBytes > expectedBytes || receivedBytes > MAX_COMMAND_OUTPUT_BYTES) {
          callback(uploadError('Command output byte count exceeded Content-Length.', 413));
          return;
        }
        hash.update(chunk);
        callback(null, chunk);
      },
    });
    await pipeline(stream, guard, fs.createWriteStream(allocation.storagePath, { flags: 'wx' }));
    if (receivedBytes !== expectedBytes) {
      throw uploadError('Command output byte count did not match Content-Length.');
    }
    const actualChecksum = hash.digest('hex');
    if (actualChecksum !== expectedChecksum) {
      throw uploadError('Command output checksum mismatch.', 400, 'COMMAND_OUTPUT_CHECKSUM_MISMATCH');
    }
    const artifact = artifactStore.finalizeFile(
      allocation.artifactId,
      allocation.storagePath,
    );
    if (!registry.finishPendingCommandOutput(userId, deviceId, commandId, { success: true })) {
      throw uploadError(
        'Desktop command disconnected before output transfer completed.',
        409,
        'COMMAND_OUTPUT_DISCONNECTED',
      );
    }
    return {
      artifactId: artifact.artifactId,
      url: artifact.url,
      byteSize: artifact.byteSize,
      complete,
    };
  } catch (error) {
    registry.finishPendingCommandOutput(userId, deviceId, commandId, { success: false });
    if (allocation) {
      try { artifactStore.deleteArtifact(userId, allocation.artifactId); } catch {}
    }
    throw error;
  }
}

module.exports = {
  MAX_COMMAND_OUTPUT_BYTES,
  uploadDesktopCommandOutput,
};
