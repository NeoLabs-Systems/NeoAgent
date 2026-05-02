'use strict';

const DEFAULT_GITHUB_REPOSITORY = 'NeoLabs-Systems/NeoAgent';
const DEFAULT_ASSET_NAME = 'neoagent-wearable-firmware.bin';
const MANIFEST_CACHE_TTL_MS = 5 * 60 * 1000;
const manifestCache = new Map();

function trimString(value, maxLength = 512) {
  return String(value || '').trim().slice(0, maxLength);
}

function normalizeChannel(value) {
  return trimString(value).toLowerCase() === 'beta' ? 'beta' : 'stable';
}

function parseRepositorySlug(value) {
  const raw = trimString(value, 256);
  if (!raw) {
    return null;
  }
  const slugMatch = raw.match(/^([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)$/);
  if (slugMatch) {
    return slugMatch[1].replace(/\.git$/, '');
  }
  const urlMatch = raw.match(/github\.com[/:]([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+?)(?:\.git)?(?:\/.*)?$/i);
  if (urlMatch) {
    return urlMatch[1].replace(/\.git$/, '');
  }
  return null;
}

function getGithubRepository() {
  return (
    parseRepositorySlug(process.env.NEOAGENT_WEARABLE_FIRMWARE_GITHUB_REPOSITORY)
    || DEFAULT_GITHUB_REPOSITORY
  );
}

function getFirmwareAssetName() {
  return trimString(process.env.NEOAGENT_WEARABLE_FIRMWARE_ASSET_NAME, 128) || DEFAULT_ASSET_NAME;
}

function getGithubToken() {
  return trimString(
    process.env.NEOAGENT_WEARABLE_GITHUB_TOKEN
      || process.env.GITHUB_TOKEN
      || process.env.GH_TOKEN,
    2048
  ) || null;
}

function stripHashPrefix(value) {
  const text = trimString(value, 512);
  if (!text) {
    return null;
  }
  return text.replace(/^sha256:/i, '').toLowerCase();
}

function toBoolean(value, fallback = false) {
  const normalized = String(value || '').trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function selectGithubRelease(releases, channel) {
  const normalizedChannel = normalizeChannel(channel);
  if (normalizedChannel === 'stable') {
    return Array.isArray(releases) ? releases.find((release) => release && release.prerelease === false && release.draft === false) || null : null;
  }

  const betaPattern = /-beta(?:\.\d+)?$/i;
  const candidates = Array.isArray(releases)
    ? releases.filter((release) => release && release.prerelease === true && betaPattern.test(String(release.tag_name || '')))
    : [];
  candidates.sort((left, right) => {
    const rightPublished = Date.parse(right?.published_at ?? right?.created_at ?? '') || 0;
    const leftPublished = Date.parse(left?.published_at ?? left?.created_at ?? '') || 0;
    return rightPublished - leftPublished;
  });
  return candidates[0] || null;
}

function selectReleaseAsset(release, assetName) {
  if (!release || !Array.isArray(release.assets) || release.assets.length === 0) {
    return null;
  }
  const expectedName = trimString(assetName, 128) || DEFAULT_ASSET_NAME;
  return release.assets.find((asset) => asset && asset.name === expectedName) || null;
}

function selectChecksumAsset(release, assetName) {
  if (!release || !Array.isArray(release.assets) || release.assets.length === 0) {
    return null;
  }
  const expectedName = trimString(assetName, 128) || DEFAULT_ASSET_NAME;
  return release.assets.find((asset) => {
    const name = String(asset?.name || '');
    if (!name || name === expectedName) {
      return false;
    }
    const lower = name.toLowerCase();
    return (
      lower === `${expectedName.toLowerCase()}.sha256`
      || lower === `${expectedName.toLowerCase()}.sha256sum`
      || lower.includes('checksum')
      || lower.endsWith('.sha256')
      || lower.endsWith('.sha256sum')
    );
  }) || null;
}

async function fetchGithubJson(fetchImpl, url, token) {
  const response = await fetchImpl(url, {
    headers: {
      Accept: 'application/vnd.github+json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    const error = new Error(`GitHub API request failed with ${response.status}`);
    error.status = response.status;
    error.body = body;
    throw error;
  }
  return response.json();
}

async function fetchText(fetchImpl, url, token) {
  const response = await fetchImpl(url, {
    headers: {
      Accept: 'text/plain, application/octet-stream;q=0.9, */*;q=0.1',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!response.ok) {
    const error = new Error(`Asset request failed with ${response.status}`);
    error.status = response.status;
    throw error;
  }
  return response.text();
}

function parseChecksumBody(body, assetName) {
  const normalizedAssetName = String(assetName || '').trim();
  const lines = String(body || '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  for (const line of lines) {
    const firstToken = line.split(/\s+/)[0];
    const normalized = stripHashPrefix(firstToken);
    if (normalized && /^[a-f0-9]{64}$/i.test(normalized)) {
      if (!normalizedAssetName || line.includes(normalizedAssetName) || lines.length === 1) {
        return normalized;
      }
    }
  }
  return null;
}

async function fetchGithubRelease(fetchImpl, repository, channel, token) {
  const normalizedChannel = normalizeChannel(channel);
  if (normalizedChannel === 'stable') {
    return fetchGithubJson(fetchImpl, `https://api.github.com/repos/${repository}/releases/latest`, token);
  }
  const releases = await fetchGithubJson(fetchImpl, `https://api.github.com/repos/${repository}/releases?per_page=100`, token);
  const release = selectGithubRelease(releases, normalizedChannel);
  if (!release) {
    const error = new Error(`No ${normalizedChannel} firmware release found for ${repository}`);
    error.status = 404;
    throw error;
  }
  return release;
}

function cacheKey({ repository, channel, assetName, downloadUrlOverride }) {
  return [repository, channel, assetName, downloadUrlOverride || ''].join('|');
}

function getCachedManifest(key) {
  const cached = manifestCache.get(key);
  if (!cached) {
    return null;
  }
  if (cached.expiresAt <= Date.now()) {
    manifestCache.delete(key);
    return null;
  }
  return cached.manifest;
}

function setCachedManifest(key, manifest) {
  manifestCache.set(key, {
    manifest,
    expiresAt: Date.now() + MANIFEST_CACHE_TTL_MS,
  });
}

async function resolveFirmwareManifest({
  channel,
  downloadUrlOverride,
  currentVersionOverride,
  releaseNotesUrlOverride,
  sha256Override,
  repositoryOverride,
  assetNameOverride,
  fetchImpl = fetch,
} = {}) {
  const normalizedChannel = normalizeChannel(channel);
  const repository = parseRepositorySlug(repositoryOverride) || getGithubRepository();
  const assetName = trimString(assetNameOverride, 128) || getFirmwareAssetName();
  const downloadUrl = trimString(downloadUrlOverride, 2000);
  const cacheId = cacheKey({ repository, channel: normalizedChannel, assetName, downloadUrlOverride: downloadUrl });
  const cached = getCachedManifest(cacheId);
  if (cached) {
    return cached;
  }

  if (downloadUrl) {
    const manifest = {
      configured: true,
      source: 'static',
      manifestVersion: 2,
      channel: normalizedChannel,
      currentVersion: trimString(currentVersionOverride, 120) || null,
      releaseName: trimString(currentVersionOverride, 120) || null,
      releaseTag: trimString(currentVersionOverride, 120) || null,
      minimumServerVersion: trimString(process.env.NEOAGENT_WEARABLE_MIN_SERVER_VERSION, 120) || null,
      downloadUrl,
      releaseNotesUrl: trimString(releaseNotesUrlOverride, 2000) || null,
      sha256: stripHashPrefix(sha256Override),
      assetName,
      repository,
      generatedAt: new Date().toISOString(),
      mandatory: toBoolean(process.env.NEOAGENT_WEARABLE_FIRMWARE_MANDATORY, false),
    };
    setCachedManifest(cacheId, manifest);
    return manifest;
  }

  if (!repository) {
    return {
      configured: false,
      source: 'github',
      manifestVersion: 2,
      channel: normalizedChannel,
      downloadUrl: null,
      releaseNotesUrl: null,
      sha256: null,
      assetName,
      repository: null,
      generatedAt: new Date().toISOString(),
      error: 'GitHub repository is not configured.',
      mandatory: false,
    };
  }

  try {
    const token = getGithubToken();
    const release = await fetchGithubRelease(fetchImpl, repository, normalizedChannel, token);
    const asset = selectReleaseAsset(release, assetName);
    if (!asset || !asset.browser_download_url) {
      return {
        configured: false,
        source: 'github',
        manifestVersion: 2,
        channel: normalizedChannel,
        currentVersion: trimString(release?.tag_name, 120) || null,
        releaseName: trimString(release?.name, 128) || trimString(release?.tag_name, 120) || null,
        releaseTag: trimString(release?.tag_name, 120) || null,
        minimumServerVersion: trimString(process.env.NEOAGENT_WEARABLE_MIN_SERVER_VERSION, 120) || null,
        downloadUrl: null,
        releaseNotesUrl: trimString(release?.html_url, 2000) || null,
        sha256: null,
        assetName,
        repository,
        generatedAt: new Date().toISOString(),
        error: `Release asset ${assetName} was not found.`,
        mandatory: false,
        prerelease: Boolean(release?.prerelease),
      };
    }

    let checksum = null;
    const checksumAsset = selectChecksumAsset(release, asset.name);
    if (checksumAsset?.browser_download_url) {
      try {
        checksum = parseChecksumBody(
          await fetchText(fetchImpl, checksumAsset.browser_download_url, token),
          asset.name,
        );
      } catch {
        checksum = null;
      }
    }

    const manifest = {
      configured: true,
      source: 'github',
      manifestVersion: 2,
      channel: normalizedChannel,
      currentVersion: trimString(release?.tag_name, 120) || null,
      releaseName: trimString(release?.name, 128) || trimString(release?.tag_name, 120) || null,
      releaseTag: trimString(release?.tag_name, 120) || null,
      minimumServerVersion: trimString(process.env.NEOAGENT_WEARABLE_MIN_SERVER_VERSION, 120) || null,
      downloadUrl: asset.browser_download_url,
      releaseNotesUrl: trimString(release?.html_url, 2000) || null,
      sha256: checksum,
      assetName: asset.name,
      repository,
      generatedAt: new Date().toISOString(),
      mandatory: toBoolean(process.env.NEOAGENT_WEARABLE_FIRMWARE_MANDATORY, false),
      prerelease: Boolean(release?.prerelease),
    };
    setCachedManifest(cacheId, manifest);
    return manifest;
  } catch (error) {
    return {
      configured: false,
      source: 'github',
      manifestVersion: 2,
      channel: normalizedChannel,
      downloadUrl: null,
      releaseNotesUrl: null,
      sha256: null,
      assetName,
      repository,
      generatedAt: new Date().toISOString(),
      error: error.message,
      mandatory: false,
    };
  }
}

module.exports = {
  DEFAULT_ASSET_NAME,
  DEFAULT_GITHUB_REPOSITORY,
  getFirmwareAssetName,
  getGithubRepository,
  normalizeChannel,
  parseRepositorySlug,
  resolveFirmwareManifest,
  selectGithubRelease,
  selectReleaseAsset,
  stripHashPrefix,
};
