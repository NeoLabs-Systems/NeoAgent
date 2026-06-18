'use strict';

const crypto = require('crypto');
const db = require('../../db/database');

const HIGH_VOLUME_DOMAINS = new Set([
  'gmail.com', 'googlemail.com', 'outlook.com', 'hotmail.com',
  'live.com', 'icloud.com', 'me.com', 'mac.com', 'yahoo.com',
  'yahoo.co.uk', 'proton.me', 'protonmail.com',
]);

const MAX_TRIALS_PER_IP = 2;
const MAX_TRIALS_PER_DOMAIN = 3;
const WINDOW_DAYS = 30;
const MIN_ACCOUNT_AGE_DAYS = 1;

function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function windowStart() {
  const d = new Date();
  d.setDate(d.getDate() - WINDOW_DAYS);
  return d.toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
}

function countFingerprints(hash, type) {
  const row = db.prepare(
    `SELECT COUNT(*) AS n FROM trial_fingerprints
     WHERE fingerprint_hash = ? AND fingerprint_type = ? AND used_at > ?`,
  ).get(hash, type, windowStart());
  return row?.n ?? 0;
}

function checkIpThrottle(ip) {
  if (!ip) return;
  const count = countFingerprints(sha256(ip), 'ip');
  if (count >= MAX_TRIALS_PER_IP) {
    const err = new Error('Too many trial registrations from this IP address.');
    err.statusCode = 429;
    throw err;
  }
}

function checkEmailDomainThrottle(email) {
  if (!email) return;
  const domain = email.split('@')[1]?.toLowerCase();
  if (!domain || HIGH_VOLUME_DOMAINS.has(domain)) return;
  const count = countFingerprints(sha256(domain), 'email_domain');
  if (count >= MAX_TRIALS_PER_DOMAIN) {
    const err = new Error('Too many trial registrations from this email domain.');
    err.statusCode = 429;
    throw err;
  }
}

function checkAccountAge(userId) {
  const user = db.prepare('SELECT created_at FROM users WHERE id = ?').get(userId);
  if (!user) return;
  const createdMs = new Date(user.created_at.replace(' ', 'T') + 'Z').getTime();
  const ageDays = (Date.now() - createdMs) / 86400000;
  if (ageDays < MIN_ACCOUNT_AGE_DAYS) {
    const err = new Error('Your account is too new to start a trial. Please try again tomorrow.');
    err.statusCode = 403;
    throw err;
  }
}

const DEVICE_WINDOW_DAYS = 90;

function checkDeviceFingerprint(deviceFp) {
  if (!deviceFp) return;
  const hash = sha256(deviceFp);
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - DEVICE_WINDOW_DAYS);
  const cutoffStr = cutoff.toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
  const row = db.prepare(
    'SELECT id FROM trial_fingerprints WHERE fingerprint_hash = ? AND fingerprint_type = ? AND used_at > ? LIMIT 1',
  ).get(hash, 'device', cutoffStr);
  if (row) {
    const err = new Error('A trial has already been used from this device.');
    err.statusCode = 429;
    throw err;
  }
}

function recordFingerprints(userId, { ip, email, deviceFp } = {}) {
  const now = new Date().toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
  const insert = db.prepare(
    'INSERT INTO trial_fingerprints (fingerprint_hash, fingerprint_type, user_id, used_at) VALUES (?, ?, ?, ?)',
  );
  db.transaction(() => {
    if (ip) insert.run(sha256(ip), 'ip', userId, now);
    if (email) {
      const domain = email.split('@')[1]?.toLowerCase();
      if (domain && !HIGH_VOLUME_DOMAINS.has(domain)) {
        insert.run(sha256(domain), 'email_domain', userId, now);
      }
    }
    if (deviceFp) insert.run(sha256(deviceFp), 'device', userId, now);
  })();
}

function runChecks(userId, userEmail, { ip, deviceFp } = {}) {
  checkIpThrottle(ip);
  checkEmailDomainThrottle(userEmail);
  checkAccountAge(userId);
  checkDeviceFingerprint(deviceFp);
}

module.exports = { runChecks, recordFingerprints };
