'use strict';

const DEFAULT_REPOSITORY = 'NeoLabs-Systems/NeoAgent';
const NOTES_START = '<!-- neoagent-download:start -->';
const NOTES_END = '<!-- neoagent-download:end -->';

const APP_SLOTS = [
  {
    id: 'macos-arm64',
    label: 'macOS',
    detail: 'Apple Silicon',
    badgeLabel: 'macOS',
    badgeMessage: 'Apple_Silicon',
    badgeLogo: 'apple',
    readyColor: '1c2117',
  },
  {
    id: 'macos-x64',
    label: 'macOS',
    detail: 'Intel',
    badgeLabel: 'macOS',
    badgeMessage: 'Intel',
    badgeLogo: 'apple',
    readyColor: '1c2117',
  },
  {
    id: 'windows-x64',
    label: 'Windows',
    detail: 'x64 installer',
    badgeLabel: 'Windows',
    badgeMessage: 'x64',
    badgeLogo: 'windows',
    readyColor: '0078d4',
  },
  {
    id: 'windows-arm64',
    label: 'Windows',
    detail: 'ARM64 installer',
    badgeLabel: 'Windows',
    badgeMessage: 'ARM64',
    badgeLogo: 'windows',
    readyColor: '0078d4',
  },
  {
    id: 'linux-appimage',
    label: 'Linux',
    detail: 'AppImage',
    badgeLabel: 'Linux',
    badgeMessage: 'AppImage',
    badgeLogo: 'linux',
    readyColor: '2f7d6e',
  },
  {
    id: 'linux-deb',
    label: 'Linux',
    detail: 'Debian / Ubuntu',
    badgeLabel: 'Linux',
    badgeMessage: 'deb',
    badgeLogo: 'debian',
    readyColor: 'a80030',
  },
  {
    id: 'linux-arch',
    label: 'Linux',
    detail: 'Arch',
    badgeLabel: 'Linux',
    badgeMessage: 'Arch',
    badgeLogo: 'archlinux',
    readyColor: '1793d1',
  },
  {
    id: 'android',
    label: 'Android',
    detail: 'APK',
    badgeLabel: 'Android',
    badgeMessage: 'APK',
    badgeLogo: 'android',
    readyColor: '3ddc84',
  },
  {
    id: 'android-launcher',
    label: 'Android',
    detail: 'Launcher APK',
    badgeLabel: 'Android',
    badgeMessage: 'Launcher',
    badgeLogo: 'android',
    readyColor: '3ddc84',
  },
];

const SLOT_BY_ID = Object.fromEntries(APP_SLOTS.map((slot) => [slot.id, slot]));

function githubDownloadUrl(repository, tag, name) {
  return `https://github.com/${repository}/releases/download/${encodeURIComponent(tag)}/${encodeURIComponent(name)}`;
}

function classifyAppAsset(name) {
  const fileName = String(name || '');
  let match = fileName.match(/^neoagent-windows-(x64|arm64)-setup-.+\.exe$/);
  if (match) {
    return SLOT_BY_ID[`windows-${match[1]}`];
  }
  match = fileName.match(/^neoagent-macos-(arm64|x64)-.+\.dmg$/);
  if (match) {
    return SLOT_BY_ID[`macos-${match[1]}`];
  }
  if (/^neoagent-linux-x86_64-.+\.AppImage$/.test(fileName)) {
    return SLOT_BY_ID['linux-appimage'];
  }
  if (/^neoagent-linux-amd64-.+\.deb$/.test(fileName)) {
    return SLOT_BY_ID['linux-deb'];
  }
  if (/^neoagent-arch-x86_64-.+\.pkg\.tar\.zst$/.test(fileName)) {
    return SLOT_BY_ID['linux-arch'];
  }
  if (/^neoagent-android-launcher-.+\.apk$/.test(fileName)) {
    return SLOT_BY_ID['android-launcher'];
  }
  if (/^neoagent-android-.+\.apk$/.test(fileName)) {
    return SLOT_BY_ID.android;
  }
  return null;
}

function assetUrl(asset, repository, tag) {
  if (asset && asset.browser_download_url) {
    return asset.browser_download_url;
  }
  if (asset && asset.name && repository && tag) {
    return githubDownloadUrl(repository, tag, asset.name);
  }
  return '';
}

function mapAppAssets(assets, repository, tag) {
  const byId = {};
  for (const asset of assets || []) {
    const slot = classifyAppAsset(asset && asset.name);
    if (!slot) {
      continue;
    }
    byId[slot.id] = {
      slot,
      name: asset.name,
      size: Number(asset.size || asset.sizeBytes || 0),
      url: assetUrl(asset, repository, tag),
    };
  }
  return byId;
}

function badgeUrl(label, message, color, logo) {
  return 'https://img.shields.io/badge/' +
    encodeURIComponent(label) + '-' +
    encodeURIComponent(message) + '-' +
    color +
    '?style=for-the-badge&logo=' +
    encodeURIComponent(logo) +
    '&logoColor=white';
}

function buildDownloadNotes(options) {
  const tag = String((options && options.tag) || '').trim();
  const repository = String((options && options.repository) || DEFAULT_REPOSITORY).trim() ||
    DEFAULT_REPOSITORY;
  const byId = mapAppAssets((options && options.assets) || [], repository, tag);
  const readyCount = Object.keys(byId).length;
  const releaseUrl = `https://github.com/${repository}/releases/tag/${encodeURIComponent(tag)}`;
  const badgeLine = APP_SLOTS.map((slot) => {
    const ready = byId[slot.id];
    const href = ready ? ready.url : releaseUrl;
    const color = ready ? slot.readyColor : '6b7280';
    const message = ready ? slot.badgeMessage : 'building';
    return `<a href="${href}"><img alt="${slot.label} ${slot.detail}" src="${badgeUrl(slot.badgeLabel, message, color, slot.badgeLogo)}"></a>`;
  }).join('\n  ');

  const status = readyCount === 0
    ? 'Installers are publishing now. Each platform appears here as soon as its build finishes.'
    : readyCount < APP_SLOTS.length
      ? 'Ready apps download in one click. Remaining platforms attach as soon as their builds finish.'
      : 'Every desktop and Android app for this release is ready.';

  return [
    NOTES_START,
    '',
    '<p align="center">',
    `  <strong>Download NeoAgent ${tag}</strong>`,
    '</p>',
    '',
    '<p align="center">',
    `  ${badgeLine}`,
    '</p>',
    '',
    `<p align="center"><sub>${status}</sub></p>`,
    '',
    '---',
    '',
    NOTES_END,
  ].join('\n');
}

function mergeDownloadNotes(body, downloadSection) {
  const current = String(body || '').replace(/^\uFEFF/, '');
  const section = String(downloadSection || '').trim();
  if (!section) {
    return current;
  }
  const start = current.indexOf(NOTES_START);
  const end = current.indexOf(NOTES_END);
  if (start >= 0 && end > start) {
    const after = current.slice(end + NOTES_END.length).replace(/^\s*/, '');
    const before = current.slice(0, start).replace(/\s*$/, '');
    return [before, section, after].filter(Boolean).join('\n\n').trim() + '\n';
  }
  if (!current.trim()) {
    return `${section}\n`;
  }
  return `${section}\n\n${current.replace(/^\s+/, '')}`;
}

module.exports = {
  APP_SLOTS,
  DEFAULT_REPOSITORY,
  NOTES_END,
  NOTES_START,
  buildDownloadNotes,
  classifyAppAsset,
  githubDownloadUrl,
  mapAppAssets,
  mergeDownloadNotes,
};
