'use strict';

const { summarizeForLog } = require('./logFormat');

// Why a shell command failed, or '' when it ran. A non-zero exit alone is a
// status, not a failure: grep and find report "nothing matched" that way, a
// pipe into `head` ends its writer early, and the exit code stays in the result
// for the model to read. A command failed when it could not run or finish, or
// when it exited non-zero and said why on stderr.
function commandFailureMessage(result) {
  if (!result || typeof result !== 'object') return '';
  if (result.error) return summarizeForLog(String(result.error), 220);
  if (result.timedOut) return `Command timed out after ${result.durationMs || 'unknown'} ms`;
  if (result.killed || result.signal) return 'Command was killed before it finished';
  const stderr = String(result.stderr || '').trim();
  if (typeof result.exitCode === 'number' && result.exitCode !== 0 && stderr) {
    return summarizeForLog(stderr, 220);
  }
  return '';
}

module.exports = {
  commandFailureMessage,
};
