'use strict';

const BASE_MANIFEST = require('../../../../extensions/chrome-browser/manifest.json');
const { getVersionInfo } = require('../../../utils/version');

function chromeVersionFor(packageVersion) {
  const parts = String(packageVersion || '')
    .match(/\d+/g)
    ?.slice(0, 4)
    .map((part) => Math.min(Number(part) || 0, 65535)) || [];

  while (parts.length < 3) {
    parts.push(0);
  }

  return parts.join('.');
}

function getExtensionManifest() {
  const { packageVersion } = getVersionInfo();
  const displayVersion = packageVersion || BASE_MANIFEST.version_name || BASE_MANIFEST.version;

  return {
    ...BASE_MANIFEST,
    version: chromeVersionFor(displayVersion),
    version_name: displayVersion,
  };
}

module.exports = {
  chromeVersionFor,
  getExtensionManifest,
};
