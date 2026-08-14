'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  APP_SLOTS,
  buildDownloadNotes,
  classifyAppAsset,
  mergeDownloadNotes,
} = require('../../../scripts/release_download_notes');

test('classifies Flutter installer names for each shipping platform', () => {
  assert.equal(classifyAppAsset('neoagent-macos-arm64-3.4.0.dmg').id, 'macos-arm64');
  assert.equal(classifyAppAsset('neoagent-macos-x64-3.4.0-beta.1.dmg').id, 'macos-x64');
  assert.equal(classifyAppAsset('neoagent-windows-x64-setup-3.4.0.exe').id, 'windows-x64');
  assert.equal(classifyAppAsset('neoagent-windows-arm64-setup-3.4.0.exe').id, 'windows-arm64');
  assert.equal(classifyAppAsset('neoagent-linux-x86_64-3.4.0.AppImage').id, 'linux-appimage');
  assert.equal(classifyAppAsset('neoagent-linux-amd64-3.4.0.deb').id, 'linux-deb');
  assert.equal(classifyAppAsset('neoagent-arch-x86_64-3.4.0-1.pkg.tar.zst').id, 'linux-arch');
  assert.equal(classifyAppAsset('neoagent-android-3.4.0.apk').id, 'android');
  assert.equal(classifyAppAsset('neoagent-android-launcher-3.4.0.apk').id, 'android-launcher');
  assert.equal(classifyAppAsset('neoagent-runtime-macos-arm64-3.4.0.zip'), null);
  assert.equal(classifyAppAsset('neoagent-cli-linux-x64-3.4.0'), null);
});

test('release notes keep generated changelog text and refresh the download block', () => {
  const first = buildDownloadNotes({
    tag: 'v3.4.0-beta.2',
    repository: 'NeoLabs-Systems/NeoAgent',
    assets: [],
  });
  assert.match(first, /Download NeoAgent v3\.4\.0-beta\.2/);
  assert.match(first, /building/);
  assert.doesNotMatch(first, /neolabs-systems\.github\.io/);
  assert.equal(APP_SLOTS.length, 9);

  const macUrl = 'https://github.com/NeoLabs-Systems/NeoAgent/releases/download/v3.4.0-beta.2/neoagent-macos-arm64-3.4.0-beta.2.dmg';
  const withMac = buildDownloadNotes({
    tag: 'v3.4.0-beta.2',
    repository: 'NeoLabs-Systems/NeoAgent',
    assets: [
      {
        name: 'neoagent-macos-arm64-3.4.0-beta.2.dmg',
        browser_download_url: macUrl,
        size: 80_000_000,
      },
    ],
  });
  assert.match(withMac, /neoagent-macos-arm64-3\.4\.0-beta\.2\.dmg/);
  assert.match(withMac, /Remaining platforms attach/);

  const merged = mergeDownloadNotes('## Changes\n\n- Fix login\n', first);
  const refreshed = mergeDownloadNotes(merged, withMac);
  assert.match(refreshed, /## Changes/);
  assert.match(refreshed, /Fix login/);
  assert.match(refreshed, /Apple_Silicon/);
  assert.match(refreshed, new RegExp(macUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
});
