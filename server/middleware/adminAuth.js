'use strict';

const crypto = require('crypto');

/**
 * Constant-time string comparison — prevents timing attacks on API key checks.
 */
function safeEqual(a, b) {
  if (!a || !b) return false;
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) {
    // Lengths differ — do a dummy compare anyway to keep timing consistent
    crypto.timingSafeEqual(bufA, Buffer.alloc(bufA.length));
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Allows admin access via either:
 *   1. Browser session  (`req.session.isAdmin === true`)
 *   2. API key          (`Authorization: Bearer <ADMIN_API_KEY>`)
 *
 * When ADMIN_API_KEY is absent or empty, Bearer auth is disabled entirely.
 */
function requireAdminAuth(req, res, next) {
  // 1. Session-based auth (admin web dashboard)
  if (req.session?.isAdmin === true) return next();

  // 2. API key auth (programmatic / scripts)
  const configuredKey = process.env.ADMIN_API_KEY;
  if (configuredKey) {
    const authHeader = String(req.headers.authorization || '');
    if (authHeader.startsWith('Bearer ')) {
      const provided = authHeader.slice(7).trim();
      if (safeEqual(provided, configuredKey)) return next();
    }
  }

  // 3. Reject
  if (req.path.startsWith('/api/')) {
    return res.status(401).json({ error: 'Admin authentication required' });
  }
  return res.redirect('/admin/login');
}

module.exports = { requireAdminAuth };
