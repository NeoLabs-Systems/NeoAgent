#!/usr/bin/env node
'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  buildDownloadNotes,
  mergeDownloadNotes,
} = require('./release_download_notes');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) {
    return '';
  }
  return value;
}

function requiredArgument(name) {
  const value = argument(name);
  if (!value) {
    throw new Error(`--${name} is required.`);
  }
  return value;
}

function resolveRepository(explicit) {
  return explicit ||
    process.env.GITHUB_REPOSITORY ||
    'NeoLabs-Systems/NeoAgent';
}

function ghJson(args) {
  const output = execFileSync('gh', args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return JSON.parse(output);
}

function updateReleaseDownloadNotes({ tag, repository, dryRun = false }) {
  const release = ghJson([
    'api',
    `repos/${repository}/releases/tags/${tag}`,
  ]);
  const downloadSection = buildDownloadNotes({
    tag,
    repository,
    assets: release.assets || [],
  });
  const nextBody = mergeDownloadNotes(release.body || '', downloadSection);
  if (nextBody === `${String(release.body || '').replace(/^\uFEFF/, '').trim()}\n`) {
    return { changed: false, body: nextBody, pageUrl: downloadSection };
  }
  if (dryRun) {
    return { changed: true, body: nextBody };
  }
  const notesPath = path.join(
    os.tmpdir(),
    `neoagent-release-notes-${process.pid}.md`,
  );
  fs.writeFileSync(notesPath, nextBody);
  try {
    execFileSync('gh', [
      'release',
      'edit',
      tag,
      '--repo',
      repository,
      '--notes-file',
      notesPath,
    ], { stdio: 'inherit' });
  } finally {
    fs.rmSync(notesPath, { force: true });
  }
  return { changed: true, body: nextBody };
}

module.exports = {
  buildDownloadNotes,
  mergeDownloadNotes,
  updateReleaseDownloadNotes,
};

if (require.main === module) {
  const tag = requiredArgument('tag');
  const repository = resolveRepository(argument('repo'));
  const dryRun = process.argv.includes('--dry-run');
  updateReleaseDownloadNotes({ tag, repository, dryRun });
}
