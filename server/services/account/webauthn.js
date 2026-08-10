'use strict';

const {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} = require('@simplewebauthn/server');
const db = require('../../db/database');
const { isAllowedOrigin } = require('../../config/origins');

const RP_NAME = 'NeoAgent';
const CHALLENGE_TTL_MS = 5 * 60 * 1000;
const CEREMONY_TIMEOUT_MS = 2 * 60 * 1000;
const MAX_CREDENTIALS_PER_USER = 20;
const MAX_LABEL_LENGTH = 48;

function httpError(message, statusCode) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function toBase64Url(bytes) {
  return Buffer.from(bytes).toString('base64url');
}

function fromBase64Url(value) {
  return new Uint8Array(Buffer.from(String(value), 'base64url'));
}

function parseTransports(row) {
  try {
    const parsed = JSON.parse(row.transports_json || '[]');
    return Array.isArray(parsed) ? parsed.filter((entry) => typeof entry === 'string') : [];
  } catch {
    return [];
  }
}

function normalizeLabel(value, fallback) {
  const label = String(value || '').trim().replace(/\s+/g, ' ');
  if (!label) return fallback;
  if (label.length > MAX_LABEL_LENGTH) {
    throw httpError(`Security key name must be ${MAX_LABEL_LENGTH} characters or fewer.`, 400);
  }
  return label;
}

/**
 * WebAuthn ties a credential to the exact hostname it was created on, so the
 * relying party is derived from the origin the ceremony actually runs on
 * rather than from a single configured public URL.
 */
function resolveRelyingParty(req) {
  const selfOrigin = `${req.protocol}://${req.get('host')}`;
  const origin = String(req.get('origin') || '').trim() || selfOrigin;
  if (origin !== selfOrigin && !isAllowedOrigin(origin, { allowMissingOrigin: false })) {
    throw httpError('Security key sign-in is not allowed from this origin.', 403);
  }
  let hostname = '';
  try {
    hostname = new URL(origin).hostname;
  } catch {
    hostname = '';
  }
  if (!hostname) {
    throw httpError('Security key sign-in requires a valid request origin.', 400);
  }
  return { origin, rpId: hostname };
}

function toCredentialPayload(row) {
  return {
    id: row.id,
    label: row.label,
    createdAt: row.created_at || null,
    lastUsedAt: row.last_used_at || null,
    transports: parseTransports(row),
    backedUp: row.backed_up === 1,
    rpId: row.rp_id,
  };
}

function listCredentials(userId) {
  return db
    .prepare(
      `SELECT id, label, rp_id, transports_json, backed_up, created_at, last_used_at
       FROM user_webauthn_credentials
       WHERE user_id = ?
       ORDER BY created_at DESC, id DESC`,
    )
    .all(userId)
    .map(toCredentialPayload);
}

function getCredentialsForRelyingParty(userId, rpId) {
  return db
    .prepare(
      `SELECT credential_id, transports_json
       FROM user_webauthn_credentials
       WHERE user_id = ? AND rp_id = ?`,
    )
    .all(userId, rpId);
}

function readChallenge(pending, rpId) {
  if (!pending?.challenge || Date.now() > Number(pending.expiresAt || 0)) {
    throw httpError('Security key challenge expired, start again.', 400);
  }
  if (pending.rpId !== rpId) {
    throw httpError('Security key challenge was started on a different address.', 400);
  }
  return pending;
}

async function beginRegistration({ req, userId }) {
  const { rpId } = resolveRelyingParty(req);
  const user = db.prepare('SELECT id, username, display_name, email FROM users WHERE id = ?').get(userId);
  if (!user) {
    throw httpError('User not found', 404);
  }

  const existing = getCredentialsForRelyingParty(userId, rpId);
  if (listCredentials(userId).length >= MAX_CREDENTIALS_PER_USER) {
    throw httpError(`You can register at most ${MAX_CREDENTIALS_PER_USER} security keys.`, 400);
  }

  const options = await generateRegistrationOptions({
    rpName: RP_NAME,
    rpID: rpId,
    userID: Buffer.from(String(user.id), 'utf8'),
    userName: user.email || user.username,
    userDisplayName: user.display_name || user.username,
    attestationType: 'none',
    timeout: CEREMONY_TIMEOUT_MS,
    excludeCredentials: existing.map((row) => ({
      id: row.credential_id,
      transports: parseTransports(row),
    })),
    authenticatorSelection: {
      residentKey: 'preferred',
      userVerification: 'preferred',
    },
  });

  return {
    options,
    challenge: {
      challenge: options.challenge,
      rpId,
      expiresAt: Date.now() + CHALLENGE_TTL_MS,
    },
  };
}

async function completeRegistration({ req, userId, response, label, pending }) {
  const { origin, rpId } = resolveRelyingParty(req);
  const challenge = readChallenge(pending, rpId);

  let verification;
  try {
    verification = await verifyRegistrationResponse({
      response,
      expectedChallenge: challenge.challenge,
      expectedOrigin: origin,
      expectedRPID: rpId,
      requireUserVerification: false,
    });
  } catch (error) {
    throw httpError(error.message || 'Security key could not be verified.', 400);
  }

  if (!verification.verified || !verification.registrationInfo) {
    throw httpError('Security key could not be verified.', 400);
  }

  const { credential, credentialDeviceType, credentialBackedUp, userVerified } = verification.registrationInfo;
  const credentialId = credential.id;
  const alreadyRegistered = db
    .prepare('SELECT user_id FROM user_webauthn_credentials WHERE credential_id = ?')
    .get(credentialId);
  if (alreadyRegistered) {
    throw httpError('That security key is already registered.', 409);
  }

  const existingCount = listCredentials(userId).length;
  db.prepare(
    `INSERT INTO user_webauthn_credentials
       (user_id, credential_id, public_key, counter, rp_id, transports_json, device_type, backed_up, user_verified, label)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    userId,
    credentialId,
    toBase64Url(credential.publicKey),
    Number(credential.counter || 0),
    rpId,
    JSON.stringify(credential.transports || []),
    credentialDeviceType || null,
    credentialBackedUp ? 1 : 0,
    userVerified ? 1 : 0,
    normalizeLabel(label, `Security key ${existingCount + 1}`),
  );

  return { success: true, credentials: listCredentials(userId) };
}

async function beginLogin({ req, username }) {
  const { rpId } = resolveRelyingParty(req);
  const account = String(username || '').trim();

  // Without a username the browser picks a discoverable credential itself, so
  // the allow-list stays empty and no account existence is leaked.
  let allowCredentials = [];
  if (account) {
    const user = db.prepare('SELECT id FROM users WHERE username = ?').get(account);
    if (user) {
      allowCredentials = getCredentialsForRelyingParty(user.id, rpId).map((row) => ({
        id: row.credential_id,
        transports: parseTransports(row),
      }));
    }
  }

  const options = await generateAuthenticationOptions({
    rpID: rpId,
    timeout: CEREMONY_TIMEOUT_MS,
    userVerification: 'preferred',
    allowCredentials,
  });

  return {
    options,
    challenge: {
      challenge: options.challenge,
      rpId,
      expiresAt: Date.now() + CHALLENGE_TTL_MS,
    },
  };
}

async function completeLogin({ req, response, pending }) {
  const { origin, rpId } = resolveRelyingParty(req);
  const challenge = readChallenge(pending, rpId);

  const credentialId = String(response?.id || '').trim();
  if (!credentialId) {
    throw httpError('Security key response is incomplete.', 400);
  }

  const stored = db
    .prepare(
      `SELECT id, user_id, credential_id, public_key, counter, transports_json
       FROM user_webauthn_credentials
       WHERE credential_id = ? AND rp_id = ?`,
    )
    .get(credentialId, rpId);
  if (!stored) {
    throw httpError('That security key is not registered.', 401);
  }

  const userHandle = response?.response?.userHandle;
  if (userHandle && Buffer.from(fromBase64Url(userHandle)).toString('utf8') !== String(stored.user_id)) {
    throw httpError('That security key is not registered.', 401);
  }

  let verification;
  try {
    verification = await verifyAuthenticationResponse({
      response,
      expectedChallenge: challenge.challenge,
      expectedOrigin: origin,
      expectedRPID: rpId,
      requireUserVerification: false,
      credential: {
        id: stored.credential_id,
        publicKey: fromBase64Url(stored.public_key),
        counter: Number(stored.counter || 0),
        transports: parseTransports(stored),
      },
    });
  } catch (error) {
    throw httpError(error.message || 'Security key could not be verified.', 401);
  }

  if (!verification.verified) {
    throw httpError('Security key could not be verified.', 401);
  }

  db.prepare(
    `UPDATE user_webauthn_credentials
     SET counter = ?, user_verified = ?, last_used_at = datetime('now')
     WHERE id = ?`,
  ).run(
    Number(verification.authenticationInfo.newCounter || 0),
    verification.authenticationInfo.userVerified ? 1 : 0,
    stored.id,
  );

  return {
    userId: stored.user_id,
    // A key that verified the user (PIN or biometric) is already two factors:
    // something you have plus something you know or are.
    userVerified: verification.authenticationInfo.userVerified === true,
  };
}

function renameCredential(userId, credentialRowId, label) {
  const nextLabel = normalizeLabel(label, '');
  if (!nextLabel) {
    throw httpError('Security key name is required.', 400);
  }
  const result = db
    .prepare('UPDATE user_webauthn_credentials SET label = ? WHERE id = ? AND user_id = ?')
    .run(nextLabel, credentialRowId, userId);
  if (result.changes === 0) {
    throw httpError('Security key not found.', 404);
  }
  return { success: true, credentials: listCredentials(userId) };
}

function deleteCredential(userId, credentialRowId) {
  const result = db
    .prepare('DELETE FROM user_webauthn_credentials WHERE id = ? AND user_id = ?')
    .run(credentialRowId, userId);
  if (result.changes === 0) {
    throw httpError('Security key not found.', 404);
  }
  return { success: true, credentials: listCredentials(userId) };
}

module.exports = {
  beginLogin,
  beginRegistration,
  completeLogin,
  completeRegistration,
  deleteCredential,
  listCredentials,
  renameCredential,
};
