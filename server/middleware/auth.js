const { isAdminUser } = require('../services/access/admin');

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

// Admin is read from the account row on every request (never cached in the
// session), so revoking it locks the account out of admin routes immediately.
function requireAdmin(req, res, next) {
  if (!req.session?.userId || !isAdminUser(req.session.userId)) {
    return res.status(403).json({ error: 'Admin access required', code: 'ADMIN_REQUIRED' });
  }
  next();
}

// With secure cookies on (the default when PUBLIC_URL is https), a request that
// arrived over plain http never gets its session cookie back: express-session
// silently skips Set-Cookie. Refuse up front instead of "signing in" an account
// that is logged out again on the next request.
function requireSessionTransport(req, res, next) {
  if (req.session?.cookie?.secure !== true || req.secure) return next();
  const publicUrl = String(req.app?.locals?.httpRuntimeConfig?.publicUrl || '');
  const httpsUrl = publicUrl.startsWith('https://')
    ? new URL(publicUrl).origin
    : `https://${req.get('host')}`;
  return res.status(400).json({
    error: `Sign-in needs a secure connection. Open ${httpsUrl} instead.`,
    code: 'INSECURE_TRANSPORT',
    httpsUrl,
  });
}

function requireNoAuth(req, res, next) {
  if (req.session && req.session.userId) {
    console.log(`[Auth] Redirecting authenticated user ${req.session.userId} away from ${req.method} ${req.originalUrl || req.url}`);
    return res.redirect('/app');
  }
  next();
}

module.exports = { requireAuth, requireAdmin, requireNoAuth, requireSessionTransport };
