'use strict';

const { safeEqual } = require('../utils/security');

function requireAdminAuth(req, res, next) {
  if (req.session?.isAdmin === true) return next();

  const configuredKey = process.env.ADMIN_API_KEY;
  if (configuredKey) {
    const authHeader = String(req.headers.authorization || '');
    if (authHeader.startsWith('Bearer ')) {
      const provided = authHeader.slice(7).trim();
      if (safeEqual(provided, configuredKey)) return next();
    }
  }

  if (req.path.startsWith('/api/')) {
    return res.status(401).json({ error: 'Admin authentication required' });
  }
  return res.redirect('/admin/login');
}

module.exports = { requireAdminAuth };
