const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');
const db = require('../db/database');
const { requireNoAuth } = require('../middleware/auth');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: 'Too many attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false
});

router.get('/api/auth/status', (req, res) => {
  const count = db.prepare('SELECT COUNT(*) as count FROM users').get();
  res.json({ hasUser: count.count > 0 });
});

router.post('/api/auth/register', authLimiter, async (req, res) => {
  try {
    const userCount = db.prepare('SELECT COUNT(*) as count FROM users').get();
    if (userCount.count > 0) {
      return res.status(403).json({ error: 'Registration is closed' });
    }

    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }
    if (username.length < 3 || password.length < 8) {
      return res.status(400).json({ error: 'Username min 3 chars, password min 8' });
    }

    const hash = await bcrypt.hash(password, 12);
    const result = db.prepare('INSERT INTO users (username, password) VALUES (?, ?)').run(username, hash);

    req.session.regenerate((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      req.session.userId = result.lastInsertRowid;
      req.session.username = username;
      req.session.save((err) => {
        if (err) return res.status(500).json({ error: 'Session save error' });
        res.json({ success: true, redirect: '/app', user: { id: result.lastInsertRowid, username } });
      });
    });
  } catch (err) {
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

    db.prepare('UPDATE users SET last_login = datetime(\'now\') WHERE id = ?').run(user.id);

    req.session.regenerate((err) => {
      if (err) return res.status(500).json({ error: 'Session error' });
      req.session.userId = user.id;
      req.session.username = user.username;
      req.session.save((err) => {
        if (err) return res.status(500).json({ error: 'Session save error' });
        res.json({ success: true, redirect: '/app', user: { id: user.id, username: user.username } });
      });
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
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
