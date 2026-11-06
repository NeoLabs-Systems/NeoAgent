'use strict';

const db = require('../../db/database');
const { recordAccessEvent } = require('../access/audit');
const { parseGrantedIds } = require('../ai/model_grants');
const { createServiceLogger } = require('../../utils/logger');
const { httpError } = require('../../utils/http_error');

const logger = createServiceLogger('Admin');
const MAX_GRANTS = 200;

function readUser(userId) {
  const user = db.prepare('SELECT id, allowed_models FROM users WHERE id = ?').get(userId);
  if (!user) throw httpError(404, 'User not found', 'NOT_FOUND');
  return user;
}

function getUserModelGrants(userId) {
  return { modelIds: parseGrantedIds(readUser(userId).allowed_models) };
}

/**
 * Replaces an account's granted models. `modelIds` null or [] clears them.
 * Every id must be a model the server has discovered (`catalogIds`), so a
 * typo can't quietly grant nothing.
 */
function setUserModelGrants(userId, modelIds, { actorUserId, catalogIds }) {
  if (modelIds !== null && !Array.isArray(modelIds)) {
    throw httpError(400, 'modelIds must be an array of model ids, or null');
  }
  const wanted = Array.from(new Set((modelIds || []).map((id) => String(id).trim()).filter(Boolean)));
  if (wanted.length > MAX_GRANTS) {
    throw httpError(400, `At most ${MAX_GRANTS} models can be granted to one account`);
  }
  const known = new Set(catalogIds);
  const unknown = wanted.filter((id) => !known.has(id));
  if (unknown.length > 0) {
    throw httpError(400, `Unknown model ids: ${unknown.slice(0, 10).join(', ')}`, 'UNKNOWN_MODEL');
  }

  const user = readUser(userId);
  const before = new Set(parseGrantedIds(user.allowed_models));
  const granted = wanted.filter((id) => !before.has(id));
  const revoked = [...before].filter((id) => !wanted.includes(id));

  db.transaction(() => {
    db.prepare('UPDATE users SET allowed_models = ? WHERE id = ?')
      .run(wanted.length ? JSON.stringify(wanted) : null, user.id);
    if (granted.length || revoked.length) {
      recordAccessEvent('account.models_changed', {
        actorUserId,
        subjectUserId: user.id,
        detail: { granted, revoked },
      });
    }
  })();
  if (granted.length || revoked.length) {
    logger.info(`Admin ${actorUserId} changed the models of account ${user.id}: +${granted.length} -${revoked.length}`);
  }
  return { ok: true, modelIds: wanted };
}

module.exports = { getUserModelGrants, setUserModelGrants };
