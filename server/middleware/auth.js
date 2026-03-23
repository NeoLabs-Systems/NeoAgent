function requireAuth(req, res, next) {
  if (!req.session || !req.session.userId) {
    console.warn(`[Auth] Unauthorized request for ${req.method} ${req.originalUrl || req.url}`);
    if (req.path.startsWith('/api/')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    return res.redirect('/login');
  }
  next();
}

function requireNoAuth(req, res, next) {
  if (req.session && req.session.userId) {
    console.log(`[Auth] Redirecting authenticated user ${req.session.userId} away from ${req.method} ${req.originalUrl || req.url}`);
    return res.redirect('/app');
  }
  next();
}

function attachUser(req, res, next) {
  if (req.session && req.session.userId) {
    const db = require('../db/database');
    const user = db.prepare('SELECT id, username, email, created_at FROM users WHERE id = ?').get(req.session.userId);
    if (user) {
      req.user = user;
      console.log(`[Auth] Attached user ${user.id} (${user.username}) to ${req.method} ${req.originalUrl || req.url}`);
    } else {
      console.warn(`[Auth] Session user ${req.session.userId} not found for ${req.method} ${req.originalUrl || req.url}; destroying session`);
      req.session.destroy(() => {});
      if (req.path.startsWith('/api/')) {
        return res.status(401).json({ error: 'Session invalid' });
      }
      return res.redirect('/login');
    }
  }
  next();
}

module.exports = { requireAuth, requireNoAuth, attachUser };
