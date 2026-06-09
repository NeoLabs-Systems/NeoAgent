'use strict';

function requireAdminAuth(req, res, next) {
  if (req.session?.isAdmin === true) return next();
  if (req.path.startsWith('/api/')) {
    return res.status(401).json({ error: 'Admin authentication required' });
  }
  return res.redirect('/admin/login');
}

module.exports = { requireAdminAuth };
