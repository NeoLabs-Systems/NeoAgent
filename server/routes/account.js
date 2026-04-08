'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcrypt');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { requireValidEmail } = require('../services/account/email');
const {
  beginSetup,
  disable,
  enable,
  getTwoFactorStatus,
  regenerateRecoveryCodes,
  verifyCurrentPassword,
} = require('../services/account/two_factor');
const {
  listSessions,
  recordCurrentSession,
  revokeSession,
} = require('../services/account/sessions');
const {
  createEmailToken,
  isServiceEmailConfigured,
  requireEmailChangeConfirmation,
  sendEmailChangeConfirmation,
  sendEmailChangedNotice,
  sendEmailChangeRequestedNotice,
  sendPasswordChangedNotice,
} = require('../services/account/service_email');

const accountLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { error: 'Too many account security attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

router.use(requireAuth);

function accountPayload(req) {
  recordCurrentSession(req, req.session.userId);
  const user = db
    .prepare('SELECT id, username, email, email_verified_at, created_at, last_login FROM users WHERE id = ?')
    .get(req.session.userId);
  return {
    user,
    twoFactor: getTwoFactorStatus(req.session.userId),
  };
}

function sendRouteError(res, err) {
  const statusCode = Number(err?.statusCode || err?.status || 500);
  if (statusCode >= 500) {
    console.error('[Account] Route error:', err);
  }
  res.status(statusCode).json({ error: sanitizeError(err) });
}

router.get('/', (req, res) => {
  try {
    res.json(accountPayload(req));
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.put('/email', accountLimiter, async (req, res) => {
  try {
    const email = requireValidEmail(req.body?.email);
    await verifyCurrentPassword(req.session.userId, req.body?.currentPassword);
    const user = db
      .prepare('SELECT id, username, email FROM users WHERE id = ?')
      .get(req.session.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    const previousEmail = user.email || null;
    if (previousEmail && previousEmail.toLowerCase() === email) {
      return res.json(accountPayload(req));
    }
    const existing = db
      .prepare('SELECT id FROM users WHERE lower(email) = ? AND id != ?')
      .get(email, req.session.userId);
    if (existing) {
      return res.status(409).json({ error: 'Email is already in use' });
    }

    if (requireEmailChangeConfirmation()) {
      if (!isServiceEmailConfigured()) {
        return res.status(503).json({ error: 'Service email is not configured for account confirmation' });
      }
      const { token } = createEmailToken(req.session.userId, 'email_change_confirmation', email);
      await sendEmailChangeConfirmation(user, email, token);
      sendEmailChangeRequestedNotice(user, email).catch((noticeError) => {
        console.warn('[Account] Email change requested notification failed:', noticeError.message);
      });
      return res.json({
        ...accountPayload(req),
        emailChangePending: true,
        pendingEmail: email,
      });
    }

    db.prepare('UPDATE users SET email = ?, email_verified_at = datetime(\'now\') WHERE id = ?')
      .run(email, req.session.userId);
    res.json(accountPayload(req));
    sendEmailChangedNotice(user, previousEmail, email).catch((noticeError) => {
      console.warn('[Account] Email changed notification failed:', noticeError.message);
    });
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.put('/password', accountLimiter, async (req, res) => {
  try {
    const currentPassword = String(req.body?.currentPassword || '');
    const nextPassword = String(req.body?.newPassword || '');
    if (nextPassword.length < 8) {
      return res.status(400).json({ error: 'Password min 8 chars' });
    }
    await verifyCurrentPassword(req.session.userId, currentPassword);
    const hash = await bcrypt.hash(nextPassword, 12);
    db.prepare('UPDATE users SET password = ? WHERE id = ?').run(hash, req.session.userId);
    const user = db
      .prepare('SELECT id, username, email FROM users WHERE id = ?')
      .get(req.session.userId);
    res.json(accountPayload(req));
    if (user) {
      sendPasswordChangedNotice(user).catch((noticeError) => {
        console.warn('[Account] Password changed notification failed:', noticeError.message);
      });
    }
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.post('/2fa/setup', accountLimiter, async (req, res) => {
  try {
    const setup = await beginSetup(req.session.userId, req.body?.currentPassword);
    res.json({
      ...setup,
      status: getTwoFactorStatus(req.session.userId),
    });
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.post('/2fa/enable', accountLimiter, async (req, res) => {
  try {
    res.json(await enable(req.session.userId, req.body?.code));
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.post('/2fa/disable', accountLimiter, async (req, res) => {
  try {
    res.json(await disable(req.session.userId, {
      currentPassword: req.body?.currentPassword,
      code: req.body?.code,
    }));
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.post('/2fa/recovery-codes', accountLimiter, async (req, res) => {
  try {
    res.json(await regenerateRecoveryCodes(req.session.userId, {
      currentPassword: req.body?.currentPassword,
      code: req.body?.code,
    }));
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.get('/sessions', (req, res) => {
  try {
    res.json({ sessions: listSessions(req, req.session.userId) });
  } catch (err) {
    sendRouteError(res, err);
  }
});

router.delete('/sessions/:id', accountLimiter, (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'Invalid session id' });
    }
    res.json({
      ...revokeSession(req, req.session.userId, id),
      sessions: listSessions(req, req.session.userId),
    });
  } catch (err) {
    sendRouteError(res, err);
  }
});

module.exports = router;
