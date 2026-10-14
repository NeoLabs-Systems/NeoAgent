'use strict';

const ui = require('./ui');

// What a failed command means to the person who ran it, by error code. The
// error's own message says what happened; this adds the headline and the
// next thing to try.
const GUIDANCE = Object.freeze({
  SETUP_PORT_IN_USE: { title: "NeoAgent couldn't start", next: 'neoagent start' },
  SETUP_PORT_UNAVAILABLE: { title: "NeoAgent couldn't find a free address", next: 'neoagent doctor' },
  SETUP_SERVER_NOT_READY: { title: "NeoAgent started but isn't answering", next: 'neoagent logs' },
  SETUP_RUNTIME_INCOMPLETE: { title: 'Some of NeoAgent\'s files are missing', next: 'neoagent repair' },
  SETUP_RESUME_NOT_FOUND: { title: 'There is no setup to continue', next: 'neoagent setup' },
  SETUP_CANCELLED: { title: 'Setup cancelled — nothing was changed' },
  SETUP_NOT_INSTALLED: { title: "NeoAgent isn't installed yet", next: 'neoagent' },
  SETUP_PROFILE_REQUIRED: { title: 'Setup needs to know how to install', next: 'neoagent setup --quick' },
  UPDATE_ROLLED_BACK: { title: "The update didn't work, so NeoAgent went back", next: 'neoagent logs' },
  UPDATE_ROLLBACK_FAILED: { title: "The update didn't work and NeoAgent couldn't go back", next: 'neoagent repair' },
});

function printError(error, { details = false } = {}) {
  const write = (line = '') => process.stderr.write(`${line}\n`);
  if (error?.code === 'CLI_CANCELLED') {
    write(`\n  ${ui.paint.muted('Cancelled.')}`);
    return;
  }
  const guidance = GUIDANCE[error?.code] || { title: 'Something went wrong', next: 'neoagent doctor' };
  write('');
  write(`  ${ui.paint.error('✕')} ${ui.paint.bold(guidance.title)}`);
  if (error?.message) write(`    ${error.message}`);
  write('');
  if (guidance.next) {
    write(`  ${ui.paint.muted('Try')} ${ui.paint.command(guidance.next)}${ui.paint.muted(
      guidance.next === 'neoagent repair' ? '' : '  ·  still stuck? neoagent repair tries the usual fixes',
    )}`);
  }
  if (details) {
    write('');
    write(`  ${ui.paint.muted(`Technical details${error?.code ? ` (${error.code})` : ''}:`)}`);
    write(ui.paint.muted(String(error?.stack || error).split('\n').map((line) => `    ${line}`).join('\n')));
  } else {
    write(`  ${ui.paint.muted('Technical details: add --details')}`);
  }
  write('');
}

module.exports = {
  printError,
};
