'use strict';

const crypto = require('crypto');

const SECRET_PREFIX = 'enc:v1:';

function getSecretMaterial() {
  // Prefer a dedicated data-encryption key so rotating SESSION_SECRET
  // does not invalidate persisted credentials. Fall back to SESSION_SECRET
  // for existing deployments that haven't set NEOAGENT_ENCRYPTION_KEY yet.
  const key = String(process.env.NEOAGENT_ENCRYPTION_KEY || process.env.SESSION_SECRET || '').trim();
  if (!key) {
    throw new Error(
      'Official integrations require NEOAGENT_ENCRYPTION_KEY (or SESSION_SECRET) to be configured.',
    );
  }
  return key;
}

function getKey() {
  return crypto.createHash('sha256').update(getSecretMaterial()).digest();
}

function isEncryptedValue(value) {
  return String(value || '').startsWith(SECRET_PREFIX);
}

function encryptValue(value) {
  const text = String(value || '');
  if (!text) return '';
  if (isEncryptedValue(text)) return text;

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${SECRET_PREFIX}${Buffer.concat([iv, tag, encrypted]).toString('base64')}`;
}

function decryptValue(value) {
  const text = String(value || '');
  if (!text) return '';
  if (!isEncryptedValue(text)) return text;

  const payload = Buffer.from(text.slice(SECRET_PREFIX.length), 'base64');
  const iv = payload.subarray(0, 12);
  const tag = payload.subarray(12, 28);
  const ciphertext = payload.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString(
    'utf8',
  );
}

module.exports = {
  decryptValue,
  encryptValue,
  isEncryptedValue,
};
