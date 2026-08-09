'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const MAX_ARTIFACT_BYTES = 16 * 1024 * 1024;
const STDOUT_PREVIEW_BYTES = 50_000;
const STDERR_PREVIEW_BYTES = 10_000;

function appendBounded(chunks, buffer, maxBytes, currentBytes) {
  if (currentBytes >= maxBytes || buffer.length === 0) return currentBytes;
  const remaining = maxBytes - currentBytes;
  const slice = buffer.length <= remaining ? buffer : buffer.subarray(0, remaining);
  chunks.push(slice);
  return currentBytes + slice.length;
}

function trimTail(chunks, totalBytes, maxBytes) {
  let current = totalBytes;
  while (current > maxBytes && chunks.length) {
    const excess = current - maxBytes;
    const first = chunks[0];
    if (first.length <= excess) {
      chunks.shift();
      current -= first.length;
    } else {
      chunks[0] = first.subarray(excess);
      current -= excess;
    }
  }
  return current;
}

function writeAllSync(fd, buffer) {
  let offset = 0;
  while (offset < buffer.length) {
    offset += fs.writeSync(fd, buffer, offset, buffer.length - offset);
  }
}

class BoundedStreamPreview {
  constructor(limitBytes) {
    this.limitBytes = limitBytes;
    this.headLimit = Math.max(1, Math.floor(limitBytes * 0.2));
    this.tailLimit = Math.max(1, limitBytes - this.headLimit);
    this.head = [];
    this.tail = [];
    this.full = [];
    this.headBytes = 0;
    this.tailBytes = 0;
    this.fullBytes = 0;
    this.totalBytes = 0;
  }

  append(data) {
    const buffer = Buffer.isBuffer(data) ? data : Buffer.from(data || '');
    this.totalBytes += buffer.length;
    this.fullBytes = appendBounded(
      this.full,
      buffer,
      this.limitBytes,
      this.fullBytes,
    );
    this.headBytes = appendBounded(
      this.head,
      buffer,
      this.headLimit,
      this.headBytes,
    );
    this.tail.push(buffer);
    this.tailBytes += buffer.length;
    this.tailBytes = trimTail(this.tail, this.tailBytes, this.tailLimit);
  }

  snapshot() {
    const truncated = this.totalBytes > this.limitBytes;
    if (!truncated) return Buffer.concat(this.full).toString('utf8').trim();
    return [
      Buffer.concat(this.head).toString('utf8').trimEnd(),
      `...[truncated preview, ${this.totalBytes} bytes total]`,
      Buffer.concat(this.tail).toString('utf8').trimStart(),
    ].filter(Boolean).join('\n');
  }
}

class CommandOutputAccumulator {
  constructor(options = {}) {
    this.maxArtifactBytes = Number(options.maxArtifactBytes) || MAX_ARTIFACT_BYTES;
    this.headLimit = Math.floor(this.maxArtifactBytes / 2);
    this.tailLimit = Math.floor(this.maxArtifactBytes / 2);
    this.stdout = new BoundedStreamPreview(
      Number(options.stdoutPreviewBytes) || STDOUT_PREVIEW_BYTES,
    );
    this.stderr = new BoundedStreamPreview(
      Number(options.stderrPreviewBytes) || STDERR_PREVIEW_BYTES,
    );
    this.artifactTail = [];
    this.artifactTailBytes = 0;
    this.artifactFileBytes = 0;
    this.totalArtifactBytes = 0;
    this.lastStream = null;
    this.outputDir = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-command-output-'));
    this.outputFilePath = path.join(this.outputDir, 'command.log');
    this.outputFd = fs.openSync(this.outputFilePath, 'w');
    this.finalized = false;
  }

  append(stream, data) {
    const payload = Buffer.isBuffer(data) ? data : Buffer.from(data || '');
    if (stream === 'stderr') this.stderr.append(payload);
    else this.stdout.append(payload);

    const marker = this.lastStream === stream
      ? Buffer.alloc(0)
      : Buffer.from(`${this.totalArtifactBytes ? '\n' : ''}[${stream}]\n`);
    this.lastStream = stream;
    this.#appendArtifact(Buffer.concat([marker, payload]));
  }

  #appendArtifact(buffer) {
    this.totalArtifactBytes += buffer.length;
    if (this.artifactFileBytes < this.maxArtifactBytes) {
      const writable = buffer.subarray(
        0,
        Math.min(buffer.length, this.maxArtifactBytes - this.artifactFileBytes),
      );
      if (writable.length) {
        writeAllSync(this.outputFd, writable);
        this.artifactFileBytes += writable.length;
      }
    }
    this.artifactTail.push(buffer);
    this.artifactTailBytes += buffer.length;
    this.artifactTailBytes = trimTail(
      this.artifactTail,
      this.artifactTailBytes,
      this.tailLimit,
    );
  }

  finalize() {
    if (this.finalized) throw new Error('Command output was already finalized.');
    this.finalized = true;
    fs.closeSync(this.outputFd);
    this.outputFd = null;
    const truncated = this.stdout.totalBytes > this.stdout.limitBytes
      || this.stderr.totalBytes > this.stderr.limitBytes;
    const result = {
      stdout: this.stdout.snapshot(),
      stderr: this.stderr.snapshot(),
      stdoutBytes: this.stdout.totalBytes,
      stderrBytes: this.stderr.totalBytes,
      truncated,
      outputFilePath: null,
      outputFileByteSize: 0,
      outputFileComplete: true,
    };
    if (!truncated) {
      this.discard();
      return result;
    }

    const complete = this.totalArtifactBytes <= this.maxArtifactBytes;
    if (!complete) {
      const marker = Buffer.from(
        `\n...[artifact bounded, ${this.totalArtifactBytes} bytes total]...\n`,
      );
      const headBytes = Math.min(
        this.headLimit,
        Math.max(0, this.maxArtifactBytes - marker.length),
      );
      const head = Buffer.alloc(headBytes);
      const sourceFd = fs.openSync(this.outputFilePath, 'r');
      const bytesRead = fs.readSync(sourceFd, head, 0, headBytes, 0);
      fs.closeSync(sourceFd);
      const tail = Buffer.concat(this.artifactTail);
      const tailBytes = Math.max(0, this.maxArtifactBytes - bytesRead - marker.length);
      fs.writeFileSync(this.outputFilePath, Buffer.concat([
        head.subarray(0, bytesRead),
        marker,
        tail.subarray(Math.max(0, tail.length - tailBytes)),
      ]));
    }
    const byteSize = fs.statSync(this.outputFilePath).size;
    return {
      ...result,
      outputFilePath: this.outputFilePath,
      outputFileByteSize: byteSize,
      outputFileComplete: complete,
    };
  }

  discard() {
    if (this.outputFd != null) {
      try { fs.closeSync(this.outputFd); } catch {}
      this.outputFd = null;
    }
    try { fs.rmSync(this.outputDir, { recursive: true, force: true }); } catch {}
  }
}

module.exports = {
  BoundedStreamPreview,
  CommandOutputAccumulator,
  MAX_ARTIFACT_BYTES,
  STDERR_PREVIEW_BYTES,
  STDOUT_PREVIEW_BYTES,
};
