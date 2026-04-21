'use strict';

const crypto = require('crypto');
const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { clientIpFromRequest, lookupIpLocation } = require('./geoip');
const { sessionHash } = require('./sessions');

const QR_LOGIN_TTL_MS = 2 * 60 * 1000;
const QR_LOGIN_TERMINAL_RETENTION_MS = 60 * 60 * 1000;

function sqliteDateFromMs(ms) {
  return new Date(ms).toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex');
}

function randomToken(bytes = 24) {
  return crypto.randomBytes(bytes).toString('base64url');
}

function trimmedString(value, maxLength = 160) {
  return String(value || '').trim().slice(0, maxLength);
}

function userAgentFromRequest(req) {
  return trimmedString(req.get?.('user-agent') || req.headers?.['user-agent'] || '', 500);
}

function parseJsonObject(value) {
  try {
    const parsed = JSON.parse(value || '{}');
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function normalizeMetadata(value) {
  const raw = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  const metadata = {
    deviceLabel: trimmedString(raw.deviceLabel, 120),
    platformLabel: trimmedString(raw.platformLabel, 60),
    browserLabel: trimmedString(raw.browserLabel, 60),
    deviceClass: trimmedString(raw.deviceClass, 24).toLowerCase(),
    appMode: trimmedString(raw.appMode, 24).toLowerCase(),
    platform: trimmedString(raw.platform, 32).toLowerCase(),
  };
  if (!['mobile', 'tablet', 'desktop', 'server', 'unknown'].includes(metadata.deviceClass)) {
    metadata.deviceClass = '';
  }
  return metadata;
}

function parseClientDescriptor(userAgent, metadata = {}) {
  const lower = String(userAgent || '').toLowerCase();
  const isTablet = lower.includes('ipad') || lower.includes('tablet');
  const isMobile = !isTablet && (
    lower.includes('iphone')
    || lower.includes('android') && lower.includes('mobile')
  );

  const platformLabel = metadata.platformLabel || (() => {
    if (lower.includes('iphone')) return 'iPhone';
    if (lower.includes('ipad')) return 'iPad';
    if (lower.includes('android')) return 'Android';
    if (lower.includes('mac os x') || lower.includes('macintosh')) return 'macOS';
    if (lower.includes('windows nt')) return 'Windows';
    if (lower.includes('linux') || lower.includes('x11')) return 'Linux';
    if (lower.includes('curl/') || lower.includes('wget/') || lower.includes('httpie/')) return 'CLI session';
    return 'Unknown device';
  })();

  const browserLabel = metadata.browserLabel || (() => {
    if (lower.includes('edg/')) return 'Edge';
    if (lower.includes('opr/') || lower.includes('opera/')) return 'Opera';
    if (lower.includes('brave/')) return 'Brave';
    if (lower.includes('firefox/')) return 'Firefox';
    if (lower.includes('chrome/') || lower.includes('crios/') || lower.includes('chromium/')) return 'Chrome';
    if (lower.includes('safari/') && lower.includes('version/')) return 'Safari';
    if (lower.includes('dart/')) return 'Flutter app';
    if (lower.includes('curl/')) return 'curl';
    if (lower.includes('wget/')) return 'wget';
    if (lower.includes('httpie/')) return 'HTTPie';
    return 'Unknown browser';
  })();

  const deviceClass = metadata.deviceClass || (() => {
    if (platformLabel === 'CLI session') return 'server';
    if (isTablet) return 'tablet';
    if (isMobile) return 'mobile';
    if (['macOS', 'Windows', 'Linux'].includes(platformLabel)) return 'desktop';
    return 'unknown';
  })();

  const primaryLabel = metadata.deviceLabel || (() => {
    const parts = [platformLabel];
    if (browserLabel && browserLabel !== 'Unknown browser' && browserLabel !== 'Flutter app') {
      parts.push(browserLabel);
    } else if (browserLabel === 'Flutter app') {
      parts.push('App');
    }
    return parts.join(' · ');
  })();

  return {
    label: primaryLabel,
    platformLabel,
    browserLabel,
    deviceClass,
  };
}

function challengeIsExpired(row) {
  return !row?.expires_at || Date.parse(row.expires_at) <= Date.now();
}

function challengeNotFoundError() {
  const error = new Error('QR login request was not found or has expired.');
  error.statusCode = 404;
  return error;
}

function challengeStateError(message, statusCode = 409) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function pruneExpiredChallenges() {
  db.prepare(`
    UPDATE user_qr_login_challenges
    SET status = 'expired'
    WHERE status IN ('pending', 'approved')
      AND datetime(expires_at) <= datetime('now')
  `).run();
  const retentionCutoff = sqliteDateFromMs(
    Date.now() - QR_LOGIN_TERMINAL_RETENTION_MS,
  );
  db.prepare(`
    DELETE FROM user_qr_login_challenges
    WHERE status IN ('expired', 'claimed')
      AND datetime(COALESCE(claimed_at, expires_at, created_at)) <= datetime(?)
  `).run(retentionCutoff);
}

function getChallengeRowByApproveSecret(challengeId, secret) {
  pruneExpiredChallenges();
  return db.prepare(`
    SELECT *
    FROM user_qr_login_challenges
    WHERE id = ?
      AND approve_secret_hash = ?
    LIMIT 1
  `).get(String(challengeId || '').trim(), tokenHash(secret));
}

function getChallengeRowByPollToken(challengeId, pollToken) {
  pruneExpiredChallenges();
  return db.prepare(`
    SELECT *
    FROM user_qr_login_challenges
    WHERE id = ?
      AND poll_token_hash = ?
    LIMIT 1
  `).get(String(challengeId || '').trim(), tokenHash(pollToken));
}

function serializeChallenge(row) {
  const requestMetadata = parseJsonObject(row.request_metadata_json);
  const approvedMetadata = parseJsonObject(row.approved_metadata_json);
  const requestLocation = parseJsonObject(row.request_location_json);
  const descriptor = parseClientDescriptor(row.request_user_agent, requestMetadata);

  return {
    challengeId: row.id,
    status: row.status || 'pending',
    requestedAt: row.created_at || null,
    expiresAt: row.expires_at || null,
    approvedAt: row.approved_at || null,
    claimedAt: row.claimed_at || null,
    requestedDevice: {
      label: descriptor.label,
      platformLabel: descriptor.platformLabel,
      browserLabel: descriptor.browserLabel,
      deviceClass: descriptor.deviceClass,
      userAgent: row.request_user_agent || '',
      metadata: requestMetadata,
    },
    requestLocation: {
      label: row.request_location_label || 'Unknown',
      ipAddress: row.request_ip_address || null,
      city: trimmedString(requestLocation.city, 80) || null,
      region: trimmedString(requestLocation.region, 80) || null,
      country: trimmedString(requestLocation.country, 80) || null,
      timezone: trimmedString(requestLocation.timezone, 80) || null,
    },
    approval: row.approved_by_user_id ? {
      userId: Number(row.approved_by_user_id),
      metadata: approvedMetadata,
    } : null,
  };
}

function createChallenge(req, options = {}) {
  pruneExpiredChallenges();
  const requestMetadata = normalizeMetadata(options.requestMetadata);
  const geo = lookupIpLocation(clientIpFromRequest(req));
  const userAgent = userAgentFromRequest(req);
  const challengeId = randomUUID();
  const pollToken = randomToken();
  const approveSecret = randomToken();
  const expiresAt = sqliteDateFromMs(Date.now() + QR_LOGIN_TTL_MS);

  db.prepare(`
    INSERT INTO user_qr_login_challenges (
      id,
      poll_token_hash,
      approve_secret_hash,
      status,
      request_user_agent,
      request_ip_address,
      request_location_label,
      request_location_json,
      request_metadata_json,
      expires_at
    )
    VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?)
  `).run(
    challengeId,
    tokenHash(pollToken),
    tokenHash(approveSecret),
    userAgent,
    geo.ipAddress,
    geo.label,
    JSON.stringify(geo.data || {}),
    JSON.stringify(requestMetadata),
    expiresAt,
  );

  return {
    challengeId,
    pollToken,
    approveSecret,
    expiresAt,
    status: 'pending',
  };
}

function resolveChallengeForApproval({ challengeId, secret }) {
  const row = getChallengeRowByApproveSecret(challengeId, secret);
  if (!row || challengeIsExpired(row) || row.status === 'expired') {
    throw challengeNotFoundError();
  }
  return serializeChallenge(row);
}

function approveChallenge({
  challengeId,
  secret,
  userId,
  approverSessionId,
  approvalMetadata,
}) {
  const metadata = normalizeMetadata(approvalMetadata);
  const row = getChallengeRowByApproveSecret(challengeId, secret);
  if (!row || challengeIsExpired(row) || row.status === 'expired') {
    throw challengeNotFoundError();
  }
  if (row.status === 'claimed') {
    throw challengeStateError('This QR login request was already used.');
  }
  if (row.status === 'approved' &&
      row.approved_by_user_id &&
      Number(row.approved_by_user_id) !== Number(userId)) {
    throw challengeStateError('This QR login request was already approved.');
  }

  const approvedSessionHash = approverSessionId ? sessionHash(approverSessionId) : null;
  const now = sqliteDateFromMs(Date.now());

  db.prepare(`
    UPDATE user_qr_login_challenges
    SET status = 'approved',
        approved_by_user_id = ?,
        approved_session_hash = ?,
        approved_metadata_json = ?,
        approved_at = ?
    WHERE id = ?
      AND status IN ('pending', 'approved')
  `).run(
    userId,
    approvedSessionHash,
    JSON.stringify(metadata),
    now,
    row.id,
  );

  return resolveChallengeForApproval({ challengeId, secret });
}

function getChallengeStatusForPoll({ challengeId, pollToken }) {
  const row = getChallengeRowByPollToken(challengeId, pollToken);
  if (!row || challengeIsExpired(row) || row.status === 'expired') {
    return {
      challengeId: String(challengeId || '').trim(),
      status: 'expired',
      expiresAt: row?.expires_at || null,
    };
  }
  return {
    challengeId: row.id,
    status: row.status || 'pending',
    expiresAt: row.expires_at || null,
    approvedAt: row.approved_at || null,
    claimedAt: row.claimed_at || null,
  };
}

function claimApprovedChallenge({ challengeId, pollToken }) {
  const row = getChallengeRowByPollToken(challengeId, pollToken);
  if (!row || challengeIsExpired(row) || row.status === 'expired') {
    throw challengeNotFoundError();
  }
  if (row.status === 'claimed') {
    throw challengeStateError('This QR login request was already used.');
  }
  if (row.status !== 'approved' || !row.approved_by_user_id) {
    throw challengeStateError('This QR login request is not approved yet.', 409);
  }

  const now = sqliteDateFromMs(Date.now());
  const result = db.prepare(`
    UPDATE user_qr_login_challenges
    SET status = 'claimed',
        claimed_at = ?
    WHERE id = ?
      AND poll_token_hash = ?
      AND status = 'approved'
  `).run(now, row.id, tokenHash(pollToken));

  if (result.changes !== 1) {
    throw challengeStateError('This QR login request is no longer available.');
  }

  const user = db.prepare(`
    SELECT id, username, email, email_verified_at, password_login_enabled, created_at, last_login
    FROM users
    WHERE id = ?
  `).get(row.approved_by_user_id);
  if (!user) {
    throw challengeStateError('The approving account is no longer available.', 404);
  }

  return {
    user,
    challenge: serializeChallenge({
      ...row,
      status: 'claimed',
      claimed_at: now,
    }),
  };
}

module.exports = {
  createChallenge,
  approveChallenge,
  claimApprovedChallenge,
  getChallengeStatusForPoll,
  resolveChallengeForApproval,
};
