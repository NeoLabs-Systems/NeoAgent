'use strict';

function rejectUpgrade(socket, statusCode, message) {
  try {
    socket.write(
      `HTTP/1.1 ${statusCode} ${message}\r\n` +
      'Connection: close\r\n' +
      '\r\n',
    );
  } catch {}
  try {
    socket.destroy();
  } catch {}
}

function remoteAddressFromRequest(req) {
  const directPeer = req.socket?.remoteAddress || 'unknown';
  if (process.env.TRUST_PROXY === 'true' || process.env.TRUST_PROXY === '1') {
    const forwarded = req.headers?.['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim()) {
      return forwarded.split(',')[0].trim();
    }
  }
  return directPeer;
}

function createUpgradeLimiter({
  windowMs = 60 * 1000,
  maxAttempts = 30,
} = {}) {
  const attempts = new Map();
  return function allowUpgradeAttempt(remoteAddress) {
    const key = String(remoteAddress || 'unknown');
    const now = Date.now();
    for (const [entryKey, stats] of attempts.entries()) {
      if (!stats?.windowStart || stats.windowStart + windowMs <= now) {
        attempts.delete(entryKey);
      }
    }
    const current = attempts.get(key);
    if (!current || now - current.windowStart >= windowMs) {
      attempts.set(key, { windowStart: now, count: 1 });
      return true;
    }
    if (current.count >= maxAttempts) {
      return false;
    }
    current.count += 1;
    return true;
  };
}

module.exports = {
  createUpgradeLimiter,
  rejectUpgrade,
  remoteAddressFromRequest,
};
