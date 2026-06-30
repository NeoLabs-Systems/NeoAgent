'use strict';

const crypto = require('crypto');

const USER_AGENTS = Object.freeze([
  {
    ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
    platform: 'Win32',
    webglVendor: 'Google Inc. (NVIDIA)',
    webglRenderer: 'ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)',
  },
  {
    ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    platform: 'Win32',
    webglVendor: 'Google Inc. (Intel)',
    webglRenderer: 'ANGLE (Intel, Intel(R) UHD Graphics 770 Direct3D11 vs_5_0 ps_5_0, D3D11)',
  },
  {
    ua: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
    platform: 'MacIntel',
    webglVendor: 'Google Inc. (Apple)',
    webglRenderer: 'ANGLE (Apple, Apple M2, OpenGL 4.1)',
  },
  {
    ua: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    platform: 'MacIntel',
    webglVendor: 'Google Inc. (Apple)',
    webglRenderer: 'ANGLE (Apple, Apple M1, OpenGL 4.1)',
  },
  {
    ua: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
    platform: 'Linux x86_64',
    webglVendor: 'Google Inc. (Intel)',
    webglRenderer: 'ANGLE (Intel, Mesa Intel(R) UHD Graphics 620, OpenGL 4.6)',
  },
]);

const VIEWPORTS = Object.freeze([
  { width: 1920, height: 1080, weight: 35 },
  { width: 1366, height: 768, weight: 26 },
  { width: 1536, height: 864, weight: 16 },
  { width: 1280, height: 720, weight: 9 },
  { width: 1440, height: 900, weight: 9 },
  { width: 1600, height: 900, weight: 5 },
]);

const REFERRER_MODES = new Set(['direct', 'google', 'current']);

function hashInt(value) {
  const hash = crypto.createHash('sha256').update(String(value || 'default')).digest();
  return hash.readUInt32BE(0);
}

function chooseWeighted(items, seed) {
  const total = items.reduce((sum, item) => sum + Number(item.weight || 1), 0);
  let cursor = Math.abs(Number(seed) || 0) % total;
  for (const item of items) {
    cursor -= Number(item.weight || 1);
    if (cursor < 0) return item;
  }
  return items[0];
}

function chooseBrowserIdentity(profileKey) {
  const seed = hashInt(profileKey);
  const profile = USER_AGENTS[seed % USER_AGENTS.length];
  const viewport = chooseWeighted(VIEWPORTS, seed >>> 3);
  return {
    userAgent: profile.ua,
    platform: profile.platform,
    viewport: { width: viewport.width, height: viewport.height },
    webglVendor: profile.webglVendor,
    webglRenderer: profile.webglRenderer,
    hardwareConcurrency: [4, 6, 8, 12, 16][seed % 5],
    deviceMemory: [4, 8, 16][(seed >>> 5) % 3],
  };
}

function normalizeReferrerMode(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return REFERRER_MODES.has(normalized) ? normalized : 'direct';
}

function normalizeChallengeRetry(value) {
  return value !== false;
}

function detectBotChallenge(input = {}) {
  const title = String(input.title || '').trim();
  const url = String(input.url || '').trim();
  const html = String(input.html || '');
  const text = String(input.text || input.pageContent || '');
  const haystack = `${title}\n${url}\n${html.slice(0, 200000)}\n${text.slice(0, 50000)}`.toLowerCase();

  if (title === 'Just a moment...' || haystack.includes('cf-turnstile-response') || haystack.includes('/cdn-cgi/challenge-platform/')) {
    return { detected: true, provider: 'cloudflare' };
  }
  if (haystack.includes('please verify you are a human') || haystack.includes('press & hold to confirm')) {
    return { detected: true, provider: 'perimeterx' };
  }
  if (haystack.includes('datadome') || haystack.includes('geo.captcha-delivery.com')) {
    return { detected: true, provider: 'datadome' };
  }
  if (
    haystack.includes('unusual traffic')
    || haystack.includes('are you a robot')
    || haystack.includes('verify that you are human')
    || haystack.includes('complete the security check')
  ) {
    return { detected: true, provider: 'generic' };
  }
  return { detected: false, provider: null };
}

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function easeInOutQuad(t) {
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}

function easeOutQuad(t) {
  return 1 - (1 - t) * (1 - t);
}

function easeInOutSine(t) {
  return -(Math.cos(Math.PI * t) - 1) / 2;
}

function bezierPoint(points, t) {
  let current = points.map((point) => ({ x: point.x, y: point.y }));
  while (current.length > 1) {
    current = current.slice(0, -1).map((point, index) => ({
      x: point.x + (current[index + 1].x - point.x) * t,
      y: point.y + (current[index + 1].y - point.y) * t,
    }));
  }
  return current[0];
}

function generateHumanMousePath(from, to, viewport = {}) {
  const start = {
    x: Number.isFinite(Number(from?.x)) ? Number(from.x) : 0,
    y: Number.isFinite(Number(from?.y)) ? Number(from.y) : 0,
  };
  const end = {
    x: Number.isFinite(Number(to?.x)) ? Number(to.x) : 0,
    y: Number.isFinite(Number(to?.y)) ? Number(to.y) : 0,
  };
  const distance = Math.hypot(end.x - start.x, end.y - start.y);
  if (distance < 2) return [start, end];

  const width = Math.max(1, Number(viewport.width || 1440));
  const height = Math.max(1, Number(viewport.height || 900));
  const steps = Math.max(12, Math.min(90, Math.round(18 + distance / 18 + rand(-5, 8))));
  const boundaryX = Math.min(90, Math.max(10, distance * 0.12));
  const boundaryY = Math.min(90, Math.max(10, distance * 0.12));
  const controlCount = rand(1, 3);
  const controls = [];
  for (let i = 1; i <= controlCount; i += 1) {
    const ratio = i / (controlCount + 1);
    controls.push({
      x: Math.max(0, Math.min(width, start.x + (end.x - start.x) * ratio + rand(-boundaryX, boundaryX))),
      y: Math.max(0, Math.min(height, start.y + (end.y - start.y) * ratio + rand(-boundaryY, boundaryY))),
    });
  }

  const tweens = [easeInOutQuad, easeOutQuad, easeInOutSine];
  const tween = tweens[rand(0, tweens.length - 1)];
  const curve = [start, ...controls, end];
  const path = [];
  for (let i = 0; i < steps; i += 1) {
    const point = bezierPoint(curve, tween(i / (steps - 1)));
    path.push({
      x: Math.round(Math.max(0, Math.min(width, point.x))),
      y: Math.round(Math.max(0, Math.min(height, point.y + (i > 0 && i < steps - 1 ? rand(-1, 1) : 0)))),
    });
  }
  path[0] = { x: Math.round(start.x), y: Math.round(start.y) };
  path[path.length - 1] = { x: Math.round(end.x), y: Math.round(end.y) };
  return path;
}

module.exports = {
  chooseBrowserIdentity,
  detectBotChallenge,
  generateHumanMousePath,
  normalizeChallengeRetry,
  normalizeReferrerMode,
  rand,
};
