'use strict';

// A service starts with the bare PATH of launchd or systemd, where `npm` is
// not found: it sits next to the Node binary, or under Homebrew. The update
// runner is started by that service and needs npm, git and node.

const path = require('node:path');

const COMMON_DIRS = process.platform === 'win32' ? [] : ['/opt/homebrew/bin', '/usr/local/bin', '/usr/bin', '/bin'];

function withToolPath(env = process.env, execPath = process.execPath) {
  const separator = process.platform === 'win32' ? ';' : ':';
  const current = String(env.PATH || '').split(separator).filter(Boolean);
  const wanted = [path.dirname(execPath), ...COMMON_DIRS].filter((dir) => !current.includes(dir));
  return { ...env, PATH: [...current, ...wanted].join(separator) };
}

module.exports = { withToolPath };
