function requireAuth(req, res, next) {
  if (!req.session || !req.session.userId) {
    console.warn(`[Auth] Unauthorized request for ${req.method} ${req.originalUrl || req.url}`);
    const requestPath = req.originalUrl || req.url || req.path || '';
    if (requestPath.startsWith('/api/')) {
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
    const now = Date.now();
    const cacheMaxAgeMs = 5 * 60 * 1000;
    const cachedUser = req.session._cachedUser;
    const cachedAt = Number(req.session._cachedUserAt || 0);
    const cacheFresh = (
      cachedUser
      && Number(cachedUser.id) === Number(req.session.userId)
      && cachedAt > 0
      && (now - cachedAt) < cacheMaxAgeMs
    );

    if (cacheFresh) {
      const alive = db.prepare('SELECT id FROM users WHERE id = ?').get(req.session.userId);
      if (alive) {
        req.user = { ...cachedUser };
        return next();
      }
    }

    const user = db.prepare('SELECT id, username, email, created_at FROM users WHERE id = ?').get(req.session.userId);
    if (user) {
      req.user = { ...user };
      req.session._cachedUser = { ...user };
      req.session._cachedUserAt = now;
      console.log(`[Auth] Attached user ${user.id} (${user.username}) to ${req.method} ${req.originalUrl || req.url}`);
      return next();
    }

    console.warn(`[Auth] Session user ${req.session.userId} not found for ${req.method} ${req.originalUrl || req.url}; destroying session`);
    req.session.destroy(() => {});
    const requestPath = req.originalUrl || req.url || req.path || '';
    if (requestPath.startsWith('/api/')) {
      return res.status(401).json({ error: 'Session invalid' });
    }
    return res.redirect('/login');
  }
  next();
}

module.exports = { requireAuth, requireNoAuth, attachUser };
