'use strict';

const crypto = require('crypto');
const { randomUUID } = require('crypto');
const { EventEmitter } = require('events');
const db = require('../../db/database');
const { clientIpFromRequest, lookupIpLocation } = require('./geoip');
const { sessionHash } = require('./sessions');
const { parseJsonObject } = require('../../utils/text');

const QR_LOGIN_TTL_MS = 2 * 60 * 1000;
const QR_LOGIN_TERMINAL_RETENTION_MS = 60 * 60 * 1000;
const QR_LOGIN_LONG_POLL_MS = 25 * 1000;

// Wakes status requests held open for a challenge, keyed by challenge id.
const challengeChanges = new EventEmitter();
challengeChanges.setMaxListeners(0);

function notifyChallengeChanged(challengeId) {
  challengeChanges.emit(challengeId);
}

function sqliteDateFromMs(ms) {
  return new Date(ms).toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex');
}

function parseSqliteUtcMs(value) {
  const raw = String(value || '').trim();
  if (!raw) return Number.NaN;
  const normalized = raw.includes('T') ? raw : raw.replace(' ', 'T');
  const utcValue = /(?:Z|[+-]\d{2}:\d{2})$/.test(normalized)
    ? normalized
    : `${normalized}Z`;
  return Date.parse(utcValue);
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

/** The scanning device as the signing-in screen may show it. */
function scannerDescriptor(metadata) {
  return {
    label: trimmedString(metadata.deviceLabel || metadata.platformLabel, 120) || 'Phone',
    platformLabel: trimmedString(metadata.platformLabel, 60) || null,
    deviceClass: trimmedString(metadata.deviceClass, 24) || null,
  };
}

function challengeIsExpired(row, nowMs = Date.now()) {
  const expiresAtMs = parseSqliteUtcMs(row?.expires_at);
  return !Number.isFinite(expiresAtMs) || expiresAtMs <= nowMs;
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
    WHERE status IN ('pending', 'scanned', 'approved')
      AND datetime(expires_at) <= datetime('now')
  `).run();
  const retentionCutoff = sqliteDateFromMs(
    Date.now() - QR_LOGIN_TERMINAL_RETENTION_MS,
  );
  db.prepare(`
    DELETE FROM user_qr_login_challenges
    WHERE status IN ('expired', 'claimed', 'declined')
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
  const scannedMetadata = parseJsonObject(row.scanned_metadata_json);
  const requestLocation = parseJsonObject(row.request_location_json);
  const descriptor = parseClientDescriptor(row.request_user_agent, requestMetadata);

  return {
    challengeId: row.id,
    status: row.status || 'pending',
    requestedAt: row.created_at || null,
    expiresAt: row.expires_at || null,
    scannedAt: row.scanned_at || null,
    approvedAt: row.approved_at || null,
    claimedAt: row.claimed_at || null,
    scannedBy: row.scanned_at ? scannerDescriptor(scannedMetadata) : null,
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

/**
 * A signed-in phone opened the approval preview. The signing-in screen sees
 * this on its next poll and waits for the decision instead of showing the code.
 */
function markChallengeScanned({ challengeId, secret, scannerMetadata }) {
  const row = getChallengeRowByApproveSecret(challengeId, secret);
  if (!row || challengeIsExpired(row) || row.status === 'expired') {
    throw challengeNotFoundError();
  }
  if (row.status === 'declined') {
    throw challengeStateError('This QR login request was cancelled.');
  }
  if (row.status === 'pending') {
    db.prepare(`
      UPDATE user_qr_login_challenges
      SET status = 'scanned',
          scanned_at = ?,
          scanned_metadata_json = ?
      WHERE id = ?
        AND status = 'pending'
    `).run(
      sqliteDateFromMs(Date.now()),
      JSON.stringify(normalizeMetadata(scannerMetadata)),
      row.id,
    );
    notifyChallengeChanged(row.id);
  }
  const preview = resolveChallengeForApproval({ challengeId, secret });
  // To the phone a scanned request is still undecided; app builds from before
  // the scanned state only offer Approve for pending ones.
  if (preview.status === 'scanned') preview.status = 'pending';
  return preview;
}

function declineRow(row) {
  if (!row || challengeIsExpired(row) || row.status === 'expired') {
    throw challengeNotFoundError();
  }
  if (row.status === 'declined') return;
  if (row.status !== 'pending' && row.status !== 'scanned') {
    throw challengeStateError('This QR login request was already approved.');
  }
  db.prepare(`
    UPDATE user_qr_login_challenges
    SET status = 'declined'
    WHERE id = ?
      AND status IN ('pending', 'scanned')
  `).run(row.id);
  notifyChallengeChanged(row.id);
}

/** The phone turned the request down. */
function declineChallenge({ challengeId, secret }) {
  declineRow(getChallengeRowByApproveSecret(challengeId, secret));
}

/** The signing-in screen gave up on this code, so a late approval fails. */
function cancelChallenge({ challengeId, pollToken }) {
  declineRow(getChallengeRowByPollToken(challengeId, pollToken));
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
  if (row.status === 'declined') {
    throw challengeStateError('This QR login request was cancelled.');
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
      AND status IN ('pending', 'scanned', 'approved')
  `).run(
    userId,
    approvedSessionHash,
    JSON.stringify(metadata),
    now,
    row.id,
  );
  notifyChallengeChanged(row.id);

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
  const status = row.status || 'pending';
  const result = {
    challengeId: row.id,
    status,
    expiresAt: row.expires_at || null,
    approvedAt: row.approved_at || null,
    claimedAt: row.claimed_at || null,
  };
  if (status === 'scanned') {
    // Only what this screen already knows about itself, plus which device of
    // the account holder is deciding; the account stays unnamed until approval.
    const challenge = serializeChallenge(row);
    result.scannedAt = challenge.scannedAt;
    result.scannedBy = challenge.scannedBy;
    result.requestedDevice = { label: challenge.requestedDevice.label };
    result.requestLocation = { label: challenge.requestLocation.label };
  }
  return result;
}

/**
 * Answers once the challenge leaves [knownStatus]: right away if it already
 * has, else when the phone scans, approves or declines, the code expires, or
 * after [maxWaitMs]. [signal] ends the wait when the client goes away.
 */
function waitForChallengeStatusChange({
  challengeId,
  pollToken,
  knownStatus,
  signal,
  maxWaitMs = QR_LOGIN_LONG_POLL_MS,
}) {
  const read = () => ({
    ...getChallengeStatusForPoll({ challengeId, pollToken }),
    longPoll: true,
  });
  const current = read();
  if (current.status !== knownStatus || signal?.aborted) {
    return Promise.resolve(current);
  }
  const untilExpiry = parseSqliteUtcMs(current.expiresAt) - Date.now();
  const waitMs = Math.max(0, Math.min(maxWaitMs, untilExpiry + 250));
  return new Promise((resolve) => {
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      challengeChanges.off(current.challengeId, finish);
      signal?.removeEventListener('abort', finish);
      resolve(read());
    };
    const timer = setTimeout(finish, waitMs);
    challengeChanges.on(current.challengeId, finish);
    signal?.addEventListener('abort', finish, { once: true });
  });
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
  notifyChallengeChanged(row.id);

  const user = db.prepare(`
    SELECT id, username, email, email_verified_at, password_login_enabled, created_at, last_login, has_completed_onboarding
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
  cancelChallenge,
  claimApprovedChallenge,
  declineChallenge,
  getChallengeStatusForPoll,
  markChallengeScanned,
  resolveChallengeForApproval,
  waitForChallengeStatusChange,
  __test: {
    challengeIsExpired,
    parseSqliteUtcMs,
  },
};
