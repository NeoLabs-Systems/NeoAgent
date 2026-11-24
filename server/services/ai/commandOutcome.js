'use strict';

const { summarizeForLog } = require('./logFormat');

// Exit status is execution evidence even when a program prints no stderr.
// A caller may interpret grep's no-match as useful, but it is not exit success.
function commandFailureMessage(result) {
  if (!result || typeof result !== 'object') return '';
  if (result.error) return summarizeForLog(String(result.error), 220);
  if (result.timedOut) return `Command timed out after ${result.durationMs || 'unknown'} ms`;
  if (result.killed || result.signal) return 'Command was killed before it finished';
  const stderr = String(result.stderr || '').trim();
  if (typeof result.exitCode === 'number' && result.exitCode !== 0) {
    return summarizeForLog(stderr || `Command exited with status ${result.exitCode}.`, 220);
  }
  return '';
}

module.exports = {
  commandFailureMessage,
};
