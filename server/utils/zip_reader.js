'use strict';

const zlib = require('zlib');

// A small reader for uploaded .zip archives: stored and deflated entries, read
// from the central directory. Zip64, encryption and multi-disk archives are
// refused rather than half-read.
const EOCD_SIGNATURE = 0x06054b50;
const CENTRAL_SIGNATURE = 0x02014b50;
const LOCAL_SIGNATURE = 0x04034b50;
const EOCD_MIN_SIZE = 22;
const MAX_COMMENT = 0xffff;

function zipError(message) {
  const error = new Error(message);
  error.status = 400;
  return error;
}

function findEndOfCentralDirectory(buffer) {
  const lowest = Math.max(0, buffer.length - EOCD_MIN_SIZE - MAX_COMMENT);
  for (let offset = buffer.length - EOCD_MIN_SIZE; offset >= lowest; offset--) {
    if (buffer.readUInt32LE(offset) === EOCD_SIGNATURE) return offset;
  }
  throw zipError('This file is not a zip archive');
}

/**
 * Returns the archive's files as `{ path, data }`, directories left out.
 * Paths use forward slashes exactly as stored; callers decide which to trust.
 */
function readZipEntries(buffer, {
  maxEntries = 5000,
  maxFileBytes = 5 * 1024 * 1024,
  maxTotalBytes = 64 * 1024 * 1024,
} = {}) {
  if (!Buffer.isBuffer(buffer) || buffer.length < EOCD_MIN_SIZE) {
    throw zipError('This file is not a zip archive');
  }
  const eocd = findEndOfCentralDirectory(buffer);
  const entryCount = buffer.readUInt16LE(eocd + 10);
  const directorySize = buffer.readUInt32LE(eocd + 12);
  const directoryOffset = buffer.readUInt32LE(eocd + 16);
  if (entryCount === 0xffff || directoryOffset === 0xffffffff) {
    throw zipError('Zip64 archives are not supported; zip a smaller folder');
  }
  if (entryCount > maxEntries) {
    throw zipError(`The archive has ${entryCount} entries; the limit is ${maxEntries}`);
  }
  if (directoryOffset + directorySize > buffer.length) {
    throw zipError('The zip archive is damaged');
  }

  const files = [];
  let totalBytes = 0;
  let cursor = directoryOffset;
  for (let index = 0; index < entryCount; index++) {
    if (cursor + 46 > buffer.length || buffer.readUInt32LE(cursor) !== CENTRAL_SIGNATURE) {
      throw zipError('The zip archive is damaged');
    }
    const flags = buffer.readUInt16LE(cursor + 8);
    const method = buffer.readUInt16LE(cursor + 10);
    const compressedSize = buffer.readUInt32LE(cursor + 20);
    const size = buffer.readUInt32LE(cursor + 24);
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const localOffset = buffer.readUInt32LE(cursor + 42);
    const name = buffer.toString(flags & 0x800 ? 'utf8' : 'latin1', cursor + 46, cursor + 46 + nameLength);
    cursor += 46 + nameLength + extraLength + commentLength;

    if (name.endsWith('/')) continue;
    if (flags & 0x1) throw zipError('Encrypted zip archives are not supported');
    if (size > maxFileBytes) continue;
    totalBytes += size;
    if (totalBytes > maxTotalBytes) {
      throw zipError(`The archive unpacks to more than ${Math.round(maxTotalBytes / 1024 / 1024)} MB`);
    }

    if (localOffset + 30 > buffer.length || buffer.readUInt32LE(localOffset) !== LOCAL_SIGNATURE) {
      throw zipError('The zip archive is damaged');
    }
    const dataStart = localOffset + 30
      + buffer.readUInt16LE(localOffset + 26)
      + buffer.readUInt16LE(localOffset + 28);
    const raw = buffer.subarray(dataStart, dataStart + compressedSize);
    let data;
    if (method === 0) {
      data = Buffer.from(raw);
    } else if (method === 8) {
      // Inflate no further than the size the entry declares, so a crafted
      // entry can't expand past the archive's limits.
      try {
        data = zlib.inflateRawSync(raw, { maxOutputLength: Math.max(size, 1) });
      } catch {
        throw zipError('The zip archive is damaged');
      }
    } else {
      throw zipError(`Unsupported zip compression (method ${method})`);
    }
    if (data.length !== size) throw zipError('The zip archive is damaged');
    files.push({ path: name.replace(/\\/g, '/'), data });
  }
  return files;
}

module.exports = { readZipEntries };
