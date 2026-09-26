'use strict';

const db = require('../../db/database');

function parseNonNegativeInt(value, fallback) {
  const parsed = parseInt(value, 10);
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
}

/** Pages through every account's subscription, newest change first. */
function listSubscriptions({ limit: rawLimit, offset: rawOffset, status: rawStatus } = {}) {
  const limit = Math.min(Math.max(parseNonNegativeInt(rawLimit, 50), 1), 200);
  const offset = parseNonNegativeInt(rawOffset, 0);
  const status = rawStatus ? String(rawStatus) : null;

  const subscriptions = db.prepare(`
    SELECT s.*, u.username, u.email, u.display_name,
           p.name AS plan_name, p.price_cents, p.currency
    FROM user_subscriptions s
    JOIN users u ON u.id = s.user_id
    JOIN billing_plans p ON p.id = s.plan_id
    WHERE ? IS NULL OR s.status = ?
    ORDER BY s.updated_at DESC
    LIMIT ? OFFSET ?
  `).all(status, status, limit, offset);

  const total = db.prepare(`
    SELECT COUNT(*) AS n FROM user_subscriptions s
    WHERE ? IS NULL OR s.status = ?
  `).get(status, status).n;

  return { subscriptions, total, limit, offset };
}

module.exports = { listSubscriptions };
