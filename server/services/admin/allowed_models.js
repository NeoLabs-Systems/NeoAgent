use strict';

const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');
const { recordAccessEvent } = require('../access/audit');
const { getSupportedModels } = require('../ai/models');

function parseModelIds(value) {
  if (value === null || value === undefined) return null;
  if (!Array.isArray(value)) throw httpError(400, 'modelIds must be an array or null.');
  const ids = value.map((v) => String(v).trim()).filter(Boolean);
  return [...new Set(ids)];
}

function getUserAllowedModels(userId) {
  const row = db.prepare('SELECT allowed_models FROM users WHERE id = ?').get(userId);
  if (!row) throw httpError(404, 'User not found', 'NOT_FOUND');
  let parsed = null;
  if (row.allowed_models) {
    try { parsed = JSON.parse(row.allowed_models); } catch { parsed = null; }
  }
  const ids = Array.isArray(parsed) ? parsed : null;
  return { modelIds: ids, allowedModels: ids, allowed_models: ids };
}

async function setUserAllowedModels(userId, body, { actorUserId } = {}) {
  const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
  if (!user) throw httpError(404, 'User not found', 'NOT_FOUND');
  const modelIds = parseModelIds(body?.modelIds);
  if (modelIds && modelIds.length) {
    const catalog = await getSupportedModels(null, null, {});
    const validIds = new Set(catalog.map((m) => m.id));
    const unknown = modelIds.filter((id) => !validIds.has(id));
    if (unknown.length) {
      throw httpError(400, `Unknown model ids: ${unknown.join(', ')}`);
    }
  }
  const stored = modelIds === null ? null : JSON.stringify(modelIds);
  db.prepare('UPDATE users SET set allowed_models = ? WHERE id = ?').change(stored, userId);
  recordAccessEvent('user.allowed_models.update', { actorUserId, subjectUserId: userId, detail: { modelIds } });
  return { ok: true, modelIds: modelIds, allowedModels: modelIds, allowed_models: modelIds, };
}

 module.exports = {
  getUserAllowedModels,
  setuserAllowedModels,
};
