'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');

function listPlans({ includeInactive = false } = {}) {
  const sql = includeInactive
    ? 'SELECT * FROM billing_plans ORDER BY sort_order ASC, created_at ASC'
    : 'SELECT * FROM billing_plans WHERE is_active = 1 ORDER BY sort_order ASC, created_at ASC';
  return db.prepare(sql).all().map(parsePlan);
}

function getPlan(planId) {
  const row = db.prepare('SELECT * FROM billing_plans WHERE id = ?').get(planId);
  return row ? parsePlan(row) : null;
}

function getFreePlan() {
  const row = db.prepare(
    'SELECT * FROM billing_plans WHERE price_cents = 0 AND is_active = 1 ORDER BY sort_order ASC LIMIT 1',
  ).get();
  return row ? parsePlan(row) : null;
}

function validatePlanData(data, requireName = true) {
  if (requireName && !data.name?.trim()) {
    throw Object.assign(new Error('Plan name is required.'), { statusCode: 400 });
  }
  if (data.price_cents !== undefined && (!Number.isInteger(data.price_cents) || data.price_cents < 0)) {
    throw Object.assign(new Error('price_cents must be a non-negative integer.'), { statusCode: 400 });
  }
  if (data.currency !== undefined && !/^[a-z]{3}$/i.test(data.currency)) {
    throw Object.assign(new Error('currency must be a 3-letter ISO code.'), { statusCode: 400 });
  }
  if (data.interval !== undefined && data.interval !== null && !['month', 'year'].includes(data.interval)) {
    throw Object.assign(new Error('interval must be "month", "year", or null.'), { statusCode: 400 });
  }
  if (data.id !== undefined && !/^[a-zA-Z0-9_-]+$/.test(data.id)) {
    throw Object.assign(new Error('Plan ID may only contain letters, numbers, underscores, and hyphens.'), { statusCode: 400 });
  }
}

function createPlan(data) {
  validatePlanData(data, true);
  const id = data.id || `plan_${randomUUID().replace(/-/g, '').slice(0, 12)}`;
  const now = new Date().toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
  db.prepare(`
    INSERT INTO billing_plans
      (id, name, description, price_cents, currency, interval, stripe_price_id,
       token_limit_4h, token_limit_weekly, allowed_models_json, features_json,
       is_active, sort_order, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    data.name,
    data.description || '',
    data.price_cents ?? 0,
    data.currency || 'usd',
    data.interval ?? 'month',
    data.stripe_price_id ?? null,
    data.token_limit_4h ?? null,
    data.token_limit_weekly ?? null,
    JSON.stringify(data.allowed_models ?? []),
    JSON.stringify(data.features ?? []),
    data.is_active !== false ? 1 : 0,
    data.sort_order ?? 0,
    now,
    now,
  );
  return getPlan(id);
}

function updatePlan(planId, data) {
  validatePlanData(data, false);
  const now = new Date().toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
  const fields = [];
  const values = [];

  if (data.name !== undefined) { fields.push('name = ?'); values.push(data.name); }
  if (data.description !== undefined) { fields.push('description = ?'); values.push(data.description); }
  if (data.price_cents !== undefined) { fields.push('price_cents = ?'); values.push(data.price_cents); }
  if (data.currency !== undefined) { fields.push('currency = ?'); values.push(data.currency); }
  if (data.interval !== undefined) { fields.push('interval = ?'); values.push(data.interval); }
  if (data.stripe_price_id !== undefined) { fields.push('stripe_price_id = ?'); values.push(data.stripe_price_id); }
  if (data.token_limit_4h !== undefined) { fields.push('token_limit_4h = ?'); values.push(data.token_limit_4h); }
  if (data.token_limit_weekly !== undefined) { fields.push('token_limit_weekly = ?'); values.push(data.token_limit_weekly); }
  if (data.allowed_models !== undefined) { fields.push('allowed_models_json = ?'); values.push(JSON.stringify(data.allowed_models)); }
  if (data.features !== undefined) { fields.push('features_json = ?'); values.push(JSON.stringify(data.features)); }
  if (data.is_active !== undefined) { fields.push('is_active = ?'); values.push(data.is_active ? 1 : 0); }
  if (data.sort_order !== undefined) { fields.push('sort_order = ?'); values.push(data.sort_order); }

  if (!fields.length) return getPlan(planId);

  fields.push('updated_at = ?');
  values.push(now);
  values.push(planId);

  db.prepare(`UPDATE billing_plans SET ${fields.join(', ')} WHERE id = ?`).run(...values);
  return getPlan(planId);
}

function deletePlan(planId) {
  const now = new Date().toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
  db.prepare('UPDATE billing_plans SET is_active = 0, updated_at = ? WHERE id = ?').run(now, planId);
}

function parsePlan(row) {
  return {
    ...row,
    allowed_models: tryParseJson(row.allowed_models_json, []),
    features: tryParseJson(row.features_json, []),
    is_active: Boolean(row.is_active),
  };
}

function tryParseJson(str, fallback) {
  try { return JSON.parse(str); } catch { return fallback; }
}

module.exports = { listPlans, getPlan, getFreePlan, createPlan, updatePlan, deletePlan };
