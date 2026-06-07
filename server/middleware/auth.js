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

module.exports = { requireAuth, requireNoAuth };
