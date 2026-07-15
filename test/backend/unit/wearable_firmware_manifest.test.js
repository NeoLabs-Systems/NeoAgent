'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  resolveFirmwareManifest,
  selectGithubRelease,
} = require('../../../server/services/wearable/firmware_manifest');

function release({ tag, prerelease = false, asset = true, publishedAt }) {
  return {
    tag_name: tag,
    name: tag,
    draft: false,
    prerelease,
    published_at: publishedAt,
    html_url: `https://github.com/NeoLabs-Systems/NeoAgent/releases/tag/${tag}`,
    assets: asset
      ? [{
        name: 'neoagent-wearable-firmware.bin',
        browser_download_url: `https://github.com/NeoLabs-Systems/NeoAgent/releases/download/${tag}/neoagent-wearable-firmware.bin`,
      }]
      : [],
  };
}

test('stable firmware selection skips releases without the firmware asset', () => {
  const releases = [
    release({ tag: 'v3.0.0', asset: false, publishedAt: '2026-03-03T00:00:00Z' }),
    release({ tag: 'v2.9.0', publishedAt: '2026-03-02T00:00:00Z' }),
    release({ tag: 'v3.1.0-beta.0', prerelease: true, publishedAt: '2026-03-04T00:00:00Z' }),
  ];

  assert.equal(
    selectGithubRelease(releases, 'stable', 'neoagent-wearable-firmware.bin').tag_name,
    'v2.9.0',
  );
});

test('beta firmware selection uses the newest published beta with an asset', () => {
  const releases = [
    release({ tag: 'v3.1.0-beta.1', prerelease: true, asset: false, publishedAt: '2026-03-04T00:00:00Z' }),
    release({ tag: 'v3.1.0-beta.0', prerelease: true, publishedAt: '2026-03-03T00:00:00Z' }),
    release({ tag: 'v3.0.0', publishedAt: '2026-03-02T00:00:00Z' }),
  ];

  assert.equal(
    selectGithubRelease(releases, 'beta', 'neoagent-wearable-firmware.bin').tag_name,
    'v3.1.0-beta.0',
  );
});

test('GitHub firmware manifest exposes the release binary and checksum', async () => {
  const firmwareRelease = release({ tag: 'v4.0.0', publishedAt: '2026-04-01T00:00:00Z' });
  firmwareRelease.assets.push({
    name: 'neoagent-wearable-firmware.bin.sha256',
    browser_download_url: 'https://downloads.example/neoagent-wearable-firmware.bin.sha256',
  });
  const checksum = 'a'.repeat(64);
  const fetchImpl = async (url) => {
    if (String(url).includes('/releases?')) {
      return {
        ok: true,
        json: async () => [firmwareRelease],
      };
    }
    if (url === 'https://downloads.example/neoagent-wearable-firmware.bin.sha256') {
      return {
        ok: true,
        text: async () => `${checksum}  neoagent-wearable-firmware.bin\n`,
      };
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  const manifest = await resolveFirmwareManifest({
    channel: 'stable',
    repositoryOverride: 'Example/NeoAgentFirmwareTest',
    fetchImpl,
  });

  assert.equal(manifest.configured, true);
  assert.equal(manifest.source, 'github');
  assert.equal(manifest.currentVersion, 'v4.0.0');
  assert.equal(manifest.sha256, checksum);
  assert.equal(
    manifest.downloadUrl,
    'https://github.com/NeoLabs-Systems/NeoAgent/releases/download/v4.0.0/neoagent-wearable-firmware.bin',
  );
});
