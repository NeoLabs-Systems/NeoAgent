'use strict';

const SUPPORTED_PLATFORMS = new Set(['youtube', 'tiktok', 'instagram', 'x']);

function normalizeInputUrl(input) {
  const raw = String(input || '').trim();
  if (!raw) {
    throw new Error('url is required.');
  }
  const withScheme = /^[a-z]+:\/\//i.test(raw) ? raw : `https://${raw}`;
  const parsed = new URL(withScheme);
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('Only http and https URLs are supported.');
  }
  parsed.hash = '';
  for (const key of [...parsed.searchParams.keys()]) {
    if (key.startsWith('utm_') || key === 'si') {
      parsed.searchParams.delete(key);
    }
  }
  return parsed;
}

function detectPlatformFromHostname(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (host === 'youtu.be' || host.endsWith('.youtube.com') || host === 'youtube.com') {
    return 'youtube';
  }
  if (host.endsWith('.tiktok.com') || host === 'tiktok.com') {
    return 'tiktok';
  }
  if (host.endsWith('.instagram.com') || host === 'instagram.com' || host === 'instagr.am') {
    return 'instagram';
  }
  if (host === 'x.com' || host.endsWith('.x.com') || host === 'twitter.com' || host.endsWith('.twitter.com')) {
    return 'x';
  }
  return 'unknown';
}

function canonicalizeByPlatform(parsed, platform) {
  if (platform === 'youtube') {
    if (parsed.hostname.toLowerCase() === 'youtu.be') {
      const id = parsed.pathname.replace(/^\/+/, '').split('/')[0];
      parsed.hostname = 'www.youtube.com';
      parsed.pathname = '/watch';
      if (id) {
        parsed.searchParams.set('v', id);
      }
      return parsed;
    }
    parsed.hostname = 'www.youtube.com';
    return parsed;
  }

  if (platform === 'x') {
    parsed.hostname = 'x.com';
    return parsed;
  }

  return parsed;
}

function normalizeAndDetectPlatform(inputUrl) {
  const parsed = normalizeInputUrl(inputUrl);
  const platform = detectPlatformFromHostname(parsed.hostname);
  if (!SUPPORTED_PLATFORMS.has(platform)) {
    throw new Error('Unsupported social video URL. Supported platforms: YouTube, TikTok, Instagram, and X.');
  }
  const canonical = canonicalizeByPlatform(parsed, platform);
  return {
    platform,
    normalizedUrl: canonical.toString(),
  };
}

module.exports = {
  SUPPORTED_PLATFORMS,
  canonicalizeByPlatform,
  detectPlatformFromHostname,
  normalizeAndDetectPlatform,
  normalizeInputUrl,
};
