'use strict';

const ui = require('./ui');

const CLI = 'neoagent';

// Everyday commands, grouped by what someone is trying to do.
const GROUPS = Object.freeze([
  ['Getting started', [
    ['setup', 'Set up NeoAgent, step by step'],
    ['account create', 'Make the first account'],
    ['login', 'Connect an AI account you already have'],
  ]],
  ['Everyday', [
    ['status', 'Is everything working?'],
    ['update', 'Get the latest version — your data stays'],
    ['restart', 'Turn it off and on again'],
  ]],
  ["When something's wrong", [
    ['doctor', 'Find problems and explain them'],
    ['repair', 'Fix common problems for you'],
    ['logs', 'See what NeoAgent is doing right now'],
  ]],
  ['Your data', [
    ['backup', 'Save a copy of your settings and chats'],
    ['start · stop', 'Turn NeoAgent on or off'],
    ['uninstall', 'Stop NeoAgent starting with your computer'],
  ]],
]);

// Every command and flag, for developers and admins.
const REFERENCE = Object.freeze([
  ['Setup', [
    ['install', 'Install dependencies, settings and the background service'],
    ['install --channel stable|beta', 'Install from a release channel'],
    ['setup --quick', 'Apply safe defaults'],
    ['setup --full', 'Configure every setup section'],
    ['setup --resume', 'Continue an interrupted setup'],
    ['--json', 'Write versioned JSON events instead of text (install, setup, status, doctor)'],
  ]],
  ['Running', [
    ['start · stop · restart', 'Control the background service'],
    ['status --details', 'Health plus install folder, versions and process IDs'],
    ['doctor', 'Read-only diagnostics'],
    ['logs', 'Follow the server logs'],
    ['backup', 'Snapshot settings, data and computer disks'],
    ['repair [--runtime-package]', 'Back up, reinstall dependencies and restart'],
    ['uninstall', 'Remove the background service'],
  ]],
  ['Updates', [
    ['update [stable|beta]', 'Update, optionally switching channel; rolls back if it fails'],
    ['update --notes', "Show what's new without updating"],
    ['channel [stable|beta]', 'Show or switch the release channel'],
    ['version', 'Print the installed version'],
    ['rebuild-web', 'Rebuild the bundled Flutter web client'],
  ]],
  ['Accounts & AI', [
    ['login claude-code|openai-codex|github-copilot|grok-oauth', 'Sign in to an AI account'],
    ['account create --username U --password P', 'Create the first account'],
    ['admin [grant|revoke <user>]', 'List or change admins'],
  ]],
  ['Configuration', [
    ['env list|get|set|unset', 'Read or change settings (secrets masked)'],
    ['migrate [dry-run|status]', 'Bring data over from OpenClaw or Hermes'],
  ]],
  ['Automation', [
    ['exec "<task>"', 'Run one task in this folder on this computer, then exit'],
    ['exec --model M --provider P', 'Pick the model ("provider/model" works with --model alone)'],
    ['exec --allow-all-tools --yes', 'Skip approval prompts and the local-run warning'],
  ]],
]);

function printGroupColumns(groups) {
  const columns = groups.map(([name, commands]) => [
    ui.paint.accent(ui.paint.bold(name)),
    ...commands.flatMap(([command, description]) => [
      ui.paint.bold(`${CLI} ${command}`),
      ui.paint.muted(description),
    ]),
  ]);
  const columnWidth = Math.max(...columns.flat().map(ui.visibleLength)) + 4;
  const perRow = ui.width() > 2 + columnWidth * 2 ? 2 : 1;
  for (let index = 0; index < columns.length; index += perRow) {
    const [left, right = []] = columns.slice(index, index + perRow);
    ui.blank();
    for (let row = 0; row < Math.max(left.length, right.length); row += 1) {
      ui.print(`  ${ui.padEnd(left[row] || '', columnWidth)}${right[row] || ''}`.trimEnd());
    }
  }
}

function printHelp({ all = false } = {}) {
  if (all) {
    ui.title('Every neoagent command');
    for (const [name, commands] of REFERENCE) {
      ui.section(ui.paint.accent(name));
      for (const [command, description] of commands) {
        ui.print(`  ${ui.padEnd(`neoagent ${command}`, 48)}  ${ui.paint.muted(description)}`);
      }
    }
    ui.blank();
    return;
  }
  ui.title("Here's what you can do", 'Not sure? Just type neoagent and pick from a menu.');
  printGroupColumns(GROUPS);
  ui.blank();
  ui.print(`  ${ui.paint.muted('More for developers and admins:')} ${ui.paint.command('neoagent help --all')}`);
  ui.blank();
}

module.exports = {
  printHelp,
};
