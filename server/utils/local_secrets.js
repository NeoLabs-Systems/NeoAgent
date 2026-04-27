'use strict';

const crypto = require('crypto');
const { getSessionSecret } = require('../services/account/session_secret');

const LOCAL_SECRET_PREFIX = 'enc:local:v1:';

function getLocalSecretMaterial() {
  const configured = String(process.env.NEOAGENT_DATA_ENCRYPTION_KEY || '').trim();
  if (configured) return configured;
  return getSessionSecret();
}

function deriveKey() {
  return crypto.createHash('sha256').update(getLocalSecretMaterial()).digest();
}

function isLocalEncryptedValue(value) {
  return String(value || '').startsWith(LOCAL_SECRET_PREFIX);
}

function encryptLocalValue(value) {
  const text = String(value || '');
  if (!text) return '';
  if (isLocalEncryptedValue(text)) return text;

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', deriveKey(), iv);
  const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${LOCAL_SECRET_PREFIX}${Buffer.concat([iv, tag, encrypted]).toString('base64')}`;
}

function decryptLocalValue(value) {
  const text = String(value || '');
  if (!text) return '';
  if (!isLocalEncryptedValue(text)) return text;

  try {
    const payload = Buffer.from(text.slice(LOCAL_SECRET_PREFIX.length), 'base64');
    const iv = payload.subarray(0, 12);
    const tag = payload.subarray(12, 28);
    const ciphertext = payload.subarray(28);
    const decipher = crypto.createDecipheriv('aes-256-gcm', deriveKey(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
  } catch {
    return '';
  }
}

module.exports = {
  decryptLocalValue,
  encryptLocalValue,
  isLocalEncryptedValue,
};
