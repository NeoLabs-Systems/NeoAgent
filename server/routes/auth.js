const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');
const db = require('../db/database');
const { requireNoAuth } = require('../middleware/auth');
const { getDeploymentPolicy } = require('../utils/deployment');
const { requireValidEmail } = require('../services/account/email');
const { getTwoFactorStatus, verifyLoginCode } = require('../services/account/two_factor');
const { recordCurrentSession } = require('../services/account/sessions');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: 'Too many attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false
});

function establishSession(req, res, user) {
  req.session.regenerate((regenerateError) => {
    if (regenerateError) {
      console.error('Auth session regenerate error:', regenerateError);
      return res.status(500).json({ error: 'Session error' });
    }

    req.session.userId = user.id;
    req.session.username = user.username;
    req.session.save((saveError) => {
      if (saveError) {
        console.error('Auth session save error:', saveError);
        return res.status(500).json({ error: 'Session save error' });
      }

      recordCurrentSession(req, user.id);
      return res.json({
        success: true,
        redirect: '/app',
        user: { id: user.id, username: user.username, email: user.email || null }
      });
    });
  });
}

function establishPendingTwoFactorSession(req, res, user) {
  req.session.regenerate((regenerateError) => {
    if (regenerateError) {
      console.error('Auth 2FA session regenerate error:', regenerateError);
      return res.status(500).json({ error: 'Session error' });
    }

    req.session.pendingTwoFactorUserId = user.id;
    req.session.pendingTwoFactorUsername = user.username;
    req.session.pendingTwoFactorStartedAt = Date.now();
    req.session.save((saveError) => {
      if (saveError) {
        console.error('Auth 2FA session save error:', saveError);
        return res.status(500).json({ error: 'Session save error' });
      }

      return res.json({
        success: false,
        requiresTwoFactor: true,
        user: { id: user.id, username: user.username, email: user.email || null }
      });
    });
  });
}

router.get('/api/auth/status', (req, res) => {
  const count = db.prepare('SELECT COUNT(*) as count FROM users').get();
  const policy = getDeploymentPolicy();
  res.json({
    hasUser: count.count > 0,
    registrationOpen: policy.registrationOpen || count.count === 0,
    deploymentProfile: policy.profile,
  });
});

router.post('/api/auth/register', authLimiter, async (req, res) => {
  try {
    const policy = getDeploymentPolicy();

    const { username, password } = req.body;
    const email = requireValidEmail(req.body?.email);
    if (!username || !password) {
      return res.status(400).json({ error: 'Username, email, and password required' });
    }
    if (username.length < 3 || password.length < 8) {
      return res.status(400).json({ error: 'Username min 3 chars, password min 8' });
    }

    const hash = await bcrypt.hash(password, 12);
    const createUser = db.transaction(() => {
      const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get();
      if (userCount.count > 0 && !policy.registrationOpen) {
        const error = new Error('Registration is closed');
        error.code = 'REGISTRATION_CLOSED';
        throw error;
      }
      const emailTaken = db.prepare('SELECT id FROM users WHERE lower(email) = ?').get(email);
      if (emailTaken) {
        const error = new Error('Email is already in use');
        error.code = 'EMAIL_TAKEN';
        throw error;
      }
      return db.prepare('INSERT INTO users (username, email, password) VALUES (?, ?, ?)').run(username, email, hash);
    });
    const result = createUser();

    establishSession(req, res, {
      id: result.lastInsertRowid,
      username,
      email
    });
  } catch (err) {
    if (err?.statusCode) {
      return res.status(err.statusCode).json({ error: err.message });
    }
    if (err?.code === 'REGISTRATION_CLOSED') {
      return res.status(403).json({ error: 'Registration is closed' });
    }
    if (err?.code === 'EMAIL_TAKEN') {
      return res.status(409).json({ error: 'Email is already in use' });
    }
    if (String(err?.code || '').startsWith('SQLITE_CONSTRAINT')) {
      if (String(err?.message || '').toLowerCase().includes('users.email')) {
        return res.status(409).json({ error: 'Email is already in use' });
      }
      return res.status(409).json({ error: 'Username is already taken' });
    }
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

router.post('/api/auth/login', authLimiter, async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (getTwoFactorStatus(user.id).enabled) {
      return establishPendingTwoFactorSession(req, res, user);
    }

    try {
      db.prepare('UPDATE users SET last_login = datetime(\'now\') WHERE id = ?').run(user.id);
    } catch (updateError) {
      // Keep login functional even if analytics-style metadata cannot be written.
      console.warn('Login last_login update failed:', updateError);
    }

    establishSession(req, res, user);
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

router.post('/api/auth/login/2fa', authLimiter, async (req, res) => {
  try {
    const pendingUserId = req.session?.pendingTwoFactorUserId;
    const startedAt = Number(req.session?.pendingTwoFactorStartedAt || 0);
    if (!pendingUserId || !startedAt || Date.now() - startedAt > 10 * 60 * 1000) {
      return res.status(401).json({ error: 'Two-factor challenge expired' });
    }

    const code = req.body?.code;
    if (!code) {
      return res.status(400).json({ error: 'Two-factor code required' });
    }

    const valid = await verifyLoginCode(pendingUserId, code);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid 2FA code' });
    }

    const user = db.prepare('SELECT id, username, email FROM users WHERE id = ?').get(pendingUserId);
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    try {
      db.prepare('UPDATE users SET last_login = datetime(\'now\') WHERE id = ?').run(user.id);
    } catch (updateError) {
      console.warn('Login last_login update failed:', updateError);
    }

    establishSession(req, res, user);
  } catch (err) {
    console.error('2FA login error:', err);
    res.status(500).json({ error: 'Two-factor login failed' });
  }
});

router.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ error: 'Logout failed' });
    res.clearCookie('neoagent.sid');
    res.json({ success: true });
  });
});

router.get('/api/auth/me', (req, res) => {
  if (!req.session || !req.session.userId) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  const user = db.prepare('SELECT id, username, email, created_at, last_login FROM users WHERE id = ?').get(req.session.userId);
  if (!user) return res.status(401).json({ error: 'User not found' });
  res.json({ user });
});

module.exports = router;
