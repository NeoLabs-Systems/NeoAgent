'use strict';

const db = require('../../db/database');
const { modelMatchesConfiguredId } = require('./model_identity');

// Models an admin has granted to one account beyond what the server enables
// for everyone. A grant only lifts the server-wide "disabled" switch for that
// account: the model still needs a provider the server can reach, and runs on
// it still count toward the account's rate limits.

function parseGrantedIds(raw) {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed)
      ? parsed.map((id) => String(id).trim()).filter(Boolean)
      : [];
  } catch {
    return [];
  }
}

function getGrantedModelIds(userId) {
  if (!Number.isInteger(Number(userId)) || Number(userId) <= 0) return [];
  const row = db.prepare('SELECT allowed_models FROM users WHERE id = ?').get(Number(userId));
  return parseGrantedIds(row?.allowed_models);
}

/**
 * Whether the server-wide switch keeps this account from a model, and whether
 * an admin grant is what lets the account use it anyway.
 */
function modelAccess(model, disabledSet, grantedSet) {
  const disabledForEveryone = modelMatchesConfiguredId(model, disabledSet);
  const adminGranted = disabledForEveryone && modelMatchesConfiguredId(model, grantedSet);
  return { blocked: disabledForEveryone && !adminGranted, adminGranted };
}

module.exports = { getGrantedModelIds, modelAccess, parseGrantedIds };
