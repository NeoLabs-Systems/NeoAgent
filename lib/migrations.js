'use strict';

// `neoagent migrate`: brings an OpenClaw or Hermes Agent installation over.
// Reading happens in lib/importers/<source>.js, writing in apply.js, and the
// agent-assisted finish in finish.js; this file is the conversation with the
// user around them.

const fs = require('fs');
const os = require('os');
const ui = require('./cli/ui');
const prompt = require('./cli/prompt');
const { createStepList, closeStepList } = require('./cli/steps');
const { renderFace } = require('./cli/mascot');
const { DATABASE_FILE } = require('../runtime/paths');
const { bundleContents, keyLabel, scanSources } = require('./importers/sources');
const { totals, writeReport } = require('./importers/report');

function plural(count, word, many = `${word}s`) {
  return `${count} ${count === 1 ? word : many}`;
}

// What a bundle holds, as card lines: [label, detail].
function summarize(bundle) {
  return bundleContents(bundle).map(({ part, count, names, days }) => {
    switch (part) {
      case 'agents': return [plural(count, 'agent'), names.join(', ')];
      case 'memories': return [plural(count, 'memory', 'memories'), days ? `and ${plural(days, 'day')} of notes` : ''];
      case 'skills': return [plural(count, 'skill'), names.slice(0, 4).join(', ')];
      case 'keys': return [plural(count, 'connection'), names.join(', ')];
      case 'model': return ['Model', names[0]];
      case 'tasks': return [plural(count, 'automation'), names.slice(0, 3).join(', ')];
      case 'mcp': return [plural(count, 'MCP server'), names.join(', ')];
      default: return ['Chat apps', names.join(', ')];
    }
  });
}

function printSourceCard(bundle) {
  ui.blank();
  ui.print(`  ${ui.paint.bold(bundle.label)}  ${ui.paint.faint(bundle.path)}`);
  const lines = summarize(bundle);
  if (!lines.length) {
    ui.item('pending', 'Nothing to bring over yet');
    return;
  }
  const width = Math.max(...lines.map(([label]) => label.length)) + 2;
  for (const [label, detail] of lines) ui.item('ok', label, detail, width);
  if (bundle.skipped.length) {
    ui.item('warn', plural(bundle.skipped.length, 'thing') + ' need a hand', 'listed at the end', width);
  }
}

async function chooseBundles(bundles, autoYes) {
  if (bundles.length === 1 || autoYes) return bundles;
  ui.blank();
  return prompt.select('What should come over?', [
    { value: bundles, label: 'Everything above', hint: 'recommended' },
    ...bundles.map((bundle) => ({ value: [bundle], label: `Only ${bundle.label}`, hint: bundle.path })),
    { value: null, label: 'Cancel' },
  ], { cancelValue: null });
}

// The import writes into one account. A fresh install has none yet: offer to
// make it here instead of sending the user to the browser and back.
async function resolveAccount(ctx, autoYes) {
  const { listAccounts } = require('./importers/neoagent');
  const accounts = listAccounts(ctx);
  if (accounts.length === 1) return accounts[0];
  if (accounts.length > 1) {
    if (autoYes) throw new Error('This install has more than one account; run `neoagent migrate` without --yes to choose one.');
    return prompt.select('Which account should receive everything?', accounts.map((account) => ({
      value: account,
      label: account.username,
      hint: account.is_admin ? 'admin' : '',
    })));
  }
  if (autoYes || !ui.isInteractive()) {
    throw new Error('No account exists yet. Create one with `neoagent account create`, then run `neoagent migrate` again.');
  }
  ui.blank();
  ui.paragraph('First, your NeoAgent account. You will use it to sign in to the app.');
  const { provisionFirstAccount } = require('../server/services/account/provision');
  const username = await prompt.ask('Username', os.userInfo().username);
  const password = await prompt.askSecret('Password (at least 8 characters)');
  const account = provisionFirstAccount({ username, password });
  ui.item('ok', `Created account ${account.username}`);
  return listAccounts(ctx).find((entry) => entry.username === account.username);
}

// Services log to the console as they work; inside the live step list those
// lines would tear the drawing, and the report records what happened.
async function withQuietConsole(task) {
  const saved = ['log', 'info', 'warn', 'debug'].map((method) => [method, console[method]]);
  for (const [method] of saved) console[method] = () => {};
  try {
    return await task();
  } finally {
    for (const [method, original] of saved) console[method] = original;
  }
}

async function importBundles(bundles, session, backup, keysDone) {
  const list = createStepList([
    ['Saving a backup of NeoAgent', 'Saved a backup of NeoAgent'],
    ...bundles.map((bundle) => [`Bringing over ${bundle.label}`, `Brought over ${bundle.label}`]),
  ], { bar: true });
  try {
    await list.run(0, () => backup({ prefix: 'pre-import' }));
    await withQuietConsole(async () => {
      for (const [index, bundle] of bundles.entries()) {
        await list.run(index + 1, () => session.applyBundle(bundle, async (label, run) => {
          list.note(label.toLowerCase());
          await run();
        }, { keysDone }));
      }
    });
  } finally {
    closeStepList(list);
  }
}

function printSummary(session, reportFile) {
  const count = (status) => session.entries.filter((entry) => entry.status === status);
  const imported = totals(count('imported'));
  const known = count('exists').reduce((sum, entry) => sum + entry.count, 0);

  ui.blank();
  ui.columns(renderFace('done'), [
    ui.paint.bold(imported.length ? 'Moved in' : 'Already moved in'),
    ui.paint.muted(imported.length ? 'Your agent now lives in NeoAgent.' : 'Everything was already in NeoAgent.'),
  ]);
  if (imported.length) {
    ui.section('Brought over');
    for (const line of imported) ui.item('ok', line);
    if (known) ui.item('info', `${known} already in NeoAgent`, 'left as they were');
  }

  const attention = [...count('failed'), ...count('skipped')];
  if (attention.length) {
    ui.section('Needs a hand');
    for (const entry of attention.slice(0, 8)) {
      ui.item(entry.status === 'failed' ? 'error' : 'warn', `${entry.kind} ${entry.name}`, entry.detail);
    }
    if (attention.length > 8) ui.note(`  …and ${attention.length - 8} more in the report.`);
  }
  ui.blank();
  ui.note(`Full report: ${reportFile.replace(os.homedir(), '~')}`);
}

// The agent-assisted part. It needs a model; without one the user can
// connect it right here.
async function offerFinish(session, bundles, io, autoYes) {
  const { hasLeftovers, queueFinishTask } = require('./importers/finish');
  const { hasUsableAi } = require('./importers/neoagent');
  if (!hasLeftovers(session)) return false;
  ui.blank();
  ui.paragraph('NeoAgent can look at what was left behind and rebuild what it can itself: automations, MCP servers and rules worth remembering.');
  if (!autoYes && !(await prompt.confirm('Let NeoAgent finish moving in?'))) return false;
  if (!hasUsableAi()) {
    if (autoYes || !ui.isInteractive()) {
      ui.note('Skipped: connect an AI first (`neoagent login` or `neoagent setup`), then run `neoagent migrate` again.');
      return false;
    }
    ui.paragraph('That needs an AI to think with, and none is connected yet.');
    if (!(await io.chooseAiProvider())) return false;
  }
  const name = queueFinishTask(session, bundles);
  ui.item('ok', 'Queued', `"${name}" starts two minutes after NeoAgent restarts; you'll get a message when it's done.`);
  return true;
}

// keyEntries: what setup's earlier key import recorded, so the summary
// counts those keys as brought over instead of finding them already there.
async function runImport(bundles, io, { autoYes, keyEntries = null }) {
  const { ImportSession } = require('./importers/apply');
  const { openNeoAgent } = require('./importers/neoagent');
  if (!fs.existsSync(DATABASE_FILE)) {
    throw new Error('NeoAgent is not set up yet. Run `neoagent setup` first.');
  }
  const ctx = openNeoAgent();
  const account = await resolveAccount(ctx, autoYes);
  const session = new ImportSession(ctx, account.id, keyEntries || []);
  ui.blank();
  await importBundles(bundles, session, io.backupRuntimeData, Boolean(keyEntries));
  const reportFile = writeReport(session, bundles);
  printSummary(session, reportFile);
  const queued = await offerFinish(session, bundles, io, autoYes);

  ui.blank();
  if (!io.isServiceInstalled()) {
    ui.note(`Start NeoAgent with ${ui.paint.command('neoagent start')} to load everything.`);
  } else if (autoYes || await prompt.confirm(queued ? 'Restart NeoAgent now to load everything and start the finish?' : 'Restart NeoAgent now to load everything?')) {
    await io.restart();
  } else {
    ui.note(`Everything loads at the next ${ui.paint.command('neoagent restart')}.`);
  }
}

function parseArguments(args) {
  const options = { mode: 'run', from: null, only: null, autoYes: false };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--from') options.from = args[++index];
    else if (arg === '--yes' || arg === '-y') options.autoYes = true;
    else if (arg === '--dry-run' || arg === 'dry-run' || arg === 'status') options.mode = 'preview';
    else if (arg === 'openclaw' || arg === 'hermes') options.only = arg;
    else if (arg === '--help' || arg === '-h' || arg === 'help') options.mode = 'help';
    else throw new Error(`Unknown option: ${arg}. See \`neoagent migrate --help\`.`);
  }
  if (args.includes('--from') && !options.from) throw new Error('Usage: neoagent migrate --from <folder>');
  return options;
}

function printHelp() {
  ui.title('neoagent migrate', 'Bring OpenClaw or Hermes Agent over to NeoAgent');
  ui.blank();
  for (const [command, text] of [
    ['neoagent migrate', 'Find both on this computer, preview, then import'],
    ['neoagent migrate --dry-run', 'Only show what would come over'],
    ['neoagent migrate openclaw', 'Only OpenClaw (or: hermes)'],
    ['neoagent migrate --from <folder>', 'A copied or non-default folder'],
    ['neoagent migrate --yes', 'No questions: import everything and restart'],
  ]) ui.print(`  ${ui.padEnd(ui.paint.command(command), 36)}${ui.paint.muted(text)}`);
  ui.blank();
  ui.note('Nothing is removed from the old agent, and running it twice does not duplicate anything.');
}

// io: { backupRuntimeData, restart, chooseAiProvider, isServiceInstalled }
async function cmdMigrate(args, io) {
  const options = parseArguments(args);
  if (options.mode === 'help') {
    printHelp();
    return;
  }
  let bundles = scanSources(options.from).filter((bundle) => !options.only || bundle.source === options.only);
  ui.title('Bring your agent to NeoAgent', 'Everything is copied. The old agent keeps working as it did.');
  if (!bundles.length) {
    ui.blank();
    ui.item('pending', 'No OpenClaw or Hermes Agent found', 'looked in ~/.openclaw and ~/.hermes');
    ui.note(`If it lives somewhere else, run ${ui.paint.command('neoagent migrate --from <folder>')}.`);
    return;
  }
  for (const bundle of bundles) printSourceCard(bundle);
  if (options.mode === 'preview') {
    ui.blank();
    ui.note(`Run ${ui.paint.command('neoagent migrate')} to bring it over.`);
    return;
  }
  bundles = await chooseBundles(bundles, options.autoYes);
  if (!bundles) return;
  await runImport(bundles, io, options);
}

// Setup's offer, before it asks for an AI: keys come over right away, so a
// user with a working agent never pastes a key twice. The rest follows once
// NeoAgent runs (importAfterSetup).
async function offerImportDuringSetup() {
  const bundles = scanSources(null);
  if (!bundles.length) return null;
  const { ImportSession } = require('./importers/apply');
  const { hasUsableAi } = require('./importers/neoagent');
  const { AI_PROVIDER_DEFINITIONS } = require('../server/services/ai/provider_definitions');
  ui.title(
    `Found ${bundles.map((bundle) => bundle.label).join(' and ')} on this computer`,
    `NeoAgent can bring over ${bundles.length > 1 ? 'their' : 'its'} keys, memory, skills, automations and chat apps.`,
  );
  for (const bundle of bundles) printSourceCard(bundle);
  ui.blank();
  if (!(await prompt.confirm('Bring it over?'))) return null;
  const session = new ImportSession(null, null);
  for (const bundle of bundles) session.applyKeys(bundle);
  const aiKeys = new Set(Object.values(AI_PROVIDER_DEFINITIONS).map((definition) => definition.envKey).filter(Boolean));
  const aiLabels = session.entries
    .filter((entry) => entry.kind === 'Key' && entry.status !== 'skipped' && aiKeys.has(entry.name))
    .map((entry) => keyLabel(entry.name));
  return { bundles, keyEntries: session.entries, aiReady: hasUsableAi(), aiLabels: [...new Set(aiLabels)] };
}

async function importAfterSetup(offer, io) {
  ui.title('Bringing over the rest');
  await runImport(offer.bundles, io, { autoYes: false, keyEntries: offer.keyEntries });
}

module.exports = {
  cmdMigrate,
  importAfterSetup,
  offerImportDuringSetup,
};
