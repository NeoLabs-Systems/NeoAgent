function requireAuth(req, res, next) {
  if (!req.session || !req.session.userId) {
    if (req.path.startsWith('/api/')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    return res.redirect('/login');
  }
  next();
}

function requireNoAuth(req, res, next) {
  if (req.session && req.session.userId) {
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
    } else {
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
