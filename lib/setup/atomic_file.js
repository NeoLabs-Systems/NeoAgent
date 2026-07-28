'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function uniqueSibling(filePath, suffix) {
  return path.join(
    path.dirname(filePath),
    `.${path.basename(filePath)}.${process.pid}.${crypto.randomBytes(6).toString('hex')}.${suffix}`,
  );
}

function activateTemporaryFile(temporary, filePath) {
  try {
    fs.renameSync(temporary, filePath);
    return;
  } catch (error) {
    if (
      !fs.existsSync(filePath)
      || !['EEXIST', 'ENOTEMPTY', 'EPERM'].includes(error.code)
    ) {
      throw error;
    }
  }

  const backup = uniqueSibling(filePath, 'backup');
  fs.renameSync(filePath, backup);
  try {
    fs.renameSync(temporary, filePath);
    try {
      fs.rmSync(backup, { force: true });
    } catch {
      // Activation succeeded; a stale backup is safer than removing the live file.
    }
  } catch (error) {
    if (!fs.existsSync(filePath) && fs.existsSync(backup)) {
      fs.renameSync(backup, filePath);
    }
    throw error;
  }
}

function writeAtomicFile(filePath, content, options = {}) {
  const directory = path.dirname(filePath);
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  const temporary = uniqueSibling(filePath, 'tmp');
  try {
    fs.writeFileSync(temporary, content, {
      encoding: 'utf8',
      mode: options.mode,
      flag: 'wx',
    });
    activateTemporaryFile(temporary, filePath);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
}

module.exports = {
  writeAtomicFile,
};
