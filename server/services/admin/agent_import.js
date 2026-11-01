'use strict';

// The app's way to bring OpenClaw or Hermes Agent over, for installs without
// the CLI. It runs the same importer as `neoagent migrate`; what it writes
// (keys, channels, skills) loads at the server's next start.

const { PARTS, bundleContents, scanSources, selectParts } = require('../../../lib/importers/sources');
const { httpError } = require('../../utils/http_error');

const ATTENTION_LIMIT = 50;

// One import at a time: a second run while the first writes would find
// nothing "already there" yet and add everything twice.
let running = false;

function describeSource(bundle) {
  return {
    id: bundle.home,
    source: bundle.source,
    label: bundle.label,
    path: bundle.path,
    contents: bundleContents(bundle),
    needsHand: bundle.skipped.length,
  };
}

function listImportSources() {
  const { hasUsableAi } = require('../../../lib/importers/neoagent');
  return { sources: scanSources(null).map(describeSource), parts: PARTS, aiReady: hasUsableAi() };
}

function summarize(session, reportFile, finishTask) {
  const { totals } = require('../../../lib/importers/report');
  const imported = session.entries.filter((entry) => entry.status === 'imported');
  const attention = session.entries.filter((entry) => entry.status === 'failed' || entry.status === 'skipped');
  return {
    broughtOver: totals(imported),
    alreadyThere: session.entries.filter((entry) => entry.status === 'exists').reduce((sum, entry) => sum + entry.count, 0),
    attention: attention.slice(0, ATTENTION_LIMIT).map(({ kind, status, name, detail }) => ({ kind, status, name, detail })),
    attentionTotal: attention.length,
    reportFile,
    finishTask,
    restartRequired: imported.length > 0 || Boolean(finishTask),
  };
}

// sourceIds: ids from listImportSources; parts: a subset of PARTS.
async function runImport(userId, { sourceIds, parts, finish }) {
  if (running) throw httpError(409, 'An import is already running', 'IMPORT_RUNNING');
  const bundles = scanSources(null)
    .filter((bundle) => sourceIds.includes(bundle.home))
    .map((bundle) => selectParts(bundle, parts));
  if (!bundles.length) throw httpError(404, 'The chosen agent was not found on this computer', 'IMPORT_SOURCE_NOT_FOUND');

  const { ImportSession } = require('../../../lib/importers/apply');
  const { openNeoAgent, hasUsableAi } = require('../../../lib/importers/neoagent');
  const { hasLeftovers, queueFinishTask } = require('../../../lib/importers/finish');
  const { writeReport } = require('../../../lib/importers/report');
  running = true;
  try {
    const session = new ImportSession(openNeoAgent(), userId);
    for (const bundle of bundles) await session.applyBundle(bundle, (label, step) => step());
    const reportFile = writeReport(session, bundles);
    const finishTask = finish && hasLeftovers(session) && hasUsableAi() ? queueFinishTask(session, bundles) : null;
    return summarize(session, reportFile, finishTask);
  } finally {
    running = false;
  }
}

module.exports = {
  listImportSources,
  runImport,
};
