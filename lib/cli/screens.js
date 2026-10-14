'use strict';

const ui = require('./ui');
const { renderFace } = require('./mascot');

// The setup wizard's stages, shown as a progress bar above each screen.
const SETUP_STAGES = Object.freeze(['Welcome', 'AI', 'Install', 'Done']);

function printSetupProgress(current) {
  ui.blank();
  if (ui.isNarrow()) {
    ui.print(`  ${ui.paint.faint(`Step ${current + 1} of ${SETUP_STAGES.length} ·`)} ${ui.paint.command(SETUP_STAGES[current])}`);
    return;
  }
  const segment = 12;
  const bar = SETUP_STAGES.map((_, index) => (index <= current
    ? ui.paint.accent('━'.repeat(segment - 1))
    : ui.sgr(ui.foreground('unlit'), '━'.repeat(segment - 1)))).join(' ');
  const labels = SETUP_STAGES.map((name, index) => {
    const text = ui.padEnd(name, segment);
    if (index === current) return ui.paint.command(text);
    return index < current ? ui.paint.muted(text) : ui.paint.faint(text);
  }).join('');
  ui.print(`  ${bar}`);
  ui.print(`  ${labels}`.trimEnd());
}

// The first few problems in a column; the rest are one status away.
const PROBLEMS_SHOWN = 3;

function printProblems(problems) {
  const shown = problems.slice(0, PROBLEMS_SHOWN);
  const width = Math.max(0, ...shown.map((problem) => ui.visibleLength(problem.label))) + 2;
  for (const problem of shown) ui.item(problem.tone, problem.label, problem.detail, width);
  if (problems.length > shown.length) {
    ui.print(`    ${ui.paint.faint(`and ${problems.length - shown.length} more —`)} ${ui.paint.command('neoagent status')}`);
  }
}

// The mascot beside one line of state and the address, then only the checks
// that need attention: the menu below covers everything else.
function printHomeHeader(facts, problems) {
  const lines = facts.running
    ? [ui.paint.bold('NeoAgent is running'), ui.paint.accent(facts.url)]
    : [ui.paint.bold("NeoAgent isn't running"), `${ui.paint.faint('run')} ${ui.paint.command('neoagent start')}`];
  ui.blank();
  ui.columns(renderFace('idle'), lines);
  if (problems.length > 0) {
    ui.blank();
    printProblems(problems);
  }
}

// The last setup screen: where NeoAgent is, and anything left to do.
function printSetupFinished({ url, startsItself, notes }) {
  ui.blank();
  ui.columns(renderFace('done'), [
    ui.paint.bold("You're all set"),
    ui.paint.muted(startsItself ? 'NeoAgent starts by itself with your computer.' : 'NeoAgent is running.'),
    '',
    `Open ${ui.paint.accent(url)}`,
    ui.paint.muted('and create your account.'),
  ]);
  if (notes.length > 0) {
    ui.blank();
    for (const text of notes) ui.item('info', text);
  }
  ui.blank();
}

module.exports = {
  printHomeHeader,
  printSetupFinished,
  printSetupProgress,
};
