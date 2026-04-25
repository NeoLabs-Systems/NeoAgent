const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');
const db = require('../db/database');
const { getDeploymentPolicy } = require('../utils/deployment');
const { requireValidEmail } = require('../services/account/email');
const {
  evaluatePasswordStrength,
  passwordStrengthError,
} = require('../services/account/password_policy');
const { getTwoFactorStatus, verifyLoginCode } = require('../services/account/two_factor');
const { recordCurrentSession, revokeAllSessionsForUser } = require('../services/account/sessions');
const {
  consumeEmailToken,
  consumePasswordResetToken,
  createEmailToken,
  getEmailConfig,
  isServiceEmailConfigured,
  requireSignupEmailConfirmation,
  sendEmailChangedNotice,
  sendPasswordChangedNotice,
  sendPasswordResetEmail,
  sendSignupConfirmation,
  sendUnusualLoginNotice,
} = require('../services/account/service_email');
const {
  claimApprovedChallenge,
  createChallenge,
  getChallengeStatusForPoll,
} = require('../services/account/qr_login');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: 'Too many attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

const qrLoginPollLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 180,
  message: { error: 'Too many QR login status checks, try again shortly' },
  standardHeaders: true,
  legacyHeaders: false,
});

const qrLoginClaimLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 40,
  message: { error: 'Too many QR login completion attempts, try again shortly' },
  standardHeaders: true,
  legacyHeaders: false,
});

const passwordResetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 8,
  message: { error: 'Too many password reset attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

function getAuthProviderManager(req) {
  return req.app?.locals?.authProviderManager;
}

function toUserPayload(user) {
  return {
    id: user.id,
    username: user.username,
    email: user.email || null,
    emailVerifiedAt: user.email_verified_at || null,
    createdAt: user.created_at || null,
    lastLogin: user.last_login || null,
    hasPassword: Number(user.password_login_enabled || 0) === 1,
  };
}

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

      const sessionInfo = recordCurrentSession(req, user.id, { login: true });
      res.json({
        success: true,
        redirect: '/app',
        user: toUserPayload(user),
      });
      if (sessionInfo?.unusual) {
        sendUnusualLoginNotice(user, sessionInfo).catch((noticeError) => {
          console.warn('Unusual login email notification failed:', noticeError.message);
        });
      }
    });
  });
}

function baseUrlFor(req) {
  const configured = req.app?.locals?.httpRuntimeConfig?.publicUrl || process.env.PUBLIC_URL || '';
  if (configured) return String(configured).replace(/\/+$/, '');
  return `${req.protocol}://${req.get('host')}`;
}

function readAuthenticatedUser(req) {
  if (!req.session || !req.session.userId) {
    return null;
  }
  const user = db.prepare(
    `SELECT id, username, email, email_verified_at, password_login_enabled, created_at, last_login
     FROM users
     WHERE id = ?`,
  ).get(req.session.userId);
  if (!user) {
    try {
      req.session.destroy(() => {});
    } catch (_) {}
    return null;
  }
  return user;
}

function sendEmailConfirmationPage(res, { ok, title, message }) {
  const safeTitle = escapeHtml(title);
  const safeMessage = escapeHtml(message);
  const accent = ok ? '#0f766e' : '#b45309';
  res.status(ok ? 200 : 400).send(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${safeTitle}</title>
  </head>
  <body style="margin:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#0f172a;">
    <main style="min-height:100vh;display:grid;place-items:center;padding:24px;">
      <section style="max-width:520px;width:100%;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;padding:32px;box-shadow:0 18px 45px rgba(15,23,42,0.08);">
        <div style="display:inline-block;border-radius:999px;background:#ccfbf1;color:#0f766e;font-weight:800;font-size:12px;letter-spacing:.08em;text-transform:uppercase;padding:8px 11px;">NeoAgent</div>
        <h1 style="margin:22px 0 0;font-size:26px;line-height:1.25;">${safeTitle}</h1>
        <p style="margin:14px 0 0;color:#475569;font-size:15px;line-height:1.65;">${safeMessage}</p>
        <a href="/" style="display:inline-block;margin-top:26px;background:${accent};color:#ffffff;text-decoration:none;font-weight:700;border-radius:8px;padding:13px 18px;">Open NeoAgent</a>
      </section>
    </main>
  </body>
</html>`);
}

function escapeHtml(value) {
  return String(value || '').replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[ch]));
}

function sendPasswordResetPage(res, { token, error = '', success = false } = {}) {
  const safeToken = escapeHtml(token || '');
  const safeError = escapeHtml(error || '');
  const title = success ? 'Password changed' : 'Reset password';
  const message = success
    ? 'Your NeoAgent password has been changed. You can return to the app and sign in.'
    : 'Enter a new password for your NeoAgent account.';
  res.status(error ? 400 : 200).send(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
  </head>
  <body style="margin:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#0f172a;">
    <main style="min-height:100vh;display:grid;place-items:center;padding:24px;">
      <section style="max-width:520px;width:100%;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;padding:32px;box-shadow:0 18px 45px rgba(15,23,42,0.08);">
        <div style="display:inline-block;border-radius:999px;background:#ccfbf1;color:#0f766e;font-weight:800;font-size:12px;letter-spacing:.08em;text-transform:uppercase;padding:8px 11px;">NeoAgent</div>
        <h1 style="margin:22px 0 0;font-size:26px;line-height:1.25;">${title}</h1>
        <p style="margin:14px 0 0;color:#475569;font-size:15px;line-height:1.65;">${message}</p>
        ${safeError ? `<p style="margin:18px 0 0;color:#b91c1c;background:#fee2e2;border:1px solid #fecaca;border-radius:8px;padding:12px;font-size:13px;">${safeError}</p>` : ''}
        ${success ? `
          <a href="/" style="display:inline-block;margin-top:26px;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:700;border-radius:8px;padding:13px 18px;">Open NeoAgent</a>
        ` : `
          <form method="post" action="/api/auth/password/reset" style="margin-top:24px;">
            <input type="hidden" name="token" value="${safeToken}">
            <label style="display:block;font-weight:700;font-size:13px;margin-bottom:8px;">New password</label>
            <input name="password" type="password" autocomplete="new-password" minlength="8" required style="width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:13px 12px;font-size:15px;">
            <label style="display:block;font-weight:700;font-size:13px;margin:16px 0 8px;">Confirm new password</label>
            <input name="confirmPassword" type="password" autocomplete="new-password" minlength="8" required style="width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:13px 12px;font-size:15px;">
            <button type="submit" style="margin-top:22px;width:100%;background:#0f766e;color:#ffffff;border:0;border-radius:8px;padding:14px 18px;font-weight:800;font-size:15px;cursor:pointer;">Change password</button>
          </form>
        `}
      </section>
    </main>
  </body>
</html>`);
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
        user: toUserPayload(user),
      });
    });
  });
}

function updateLastLogin(userId) {
  try {
    db.prepare('UPDATE users SET last_login = datetime(\'now\') WHERE id = ?').run(userId);
  } catch (updateError) {
    console.warn('Login last_login update failed:', updateError);
  }
}

router.get('/api/auth/status', (req, res) => {
  const count = db.prepare('SELECT COUNT(*) as count FROM users').get();
  const policy = getDeploymentPolicy();
  const emailConfig = getEmailConfig();
  const authProviderManager = getAuthProviderManager(req);
  const currentUser = readAuthenticatedUser(req);
  if (!currentUser) {
    return res.json({
      hasUser: count.count > 0,
      registrationOpen: policy.registrationOpen || count.count === 0,
      deploymentProfile: policy.profile,
      authenticated: false,
      user: null,
      email: {
        enabled: emailConfig.enabled,
        configured: emailConfig.configured,
        signupConfirmationRequired: requireSignupEmailConfirmation(),
      },
      providers: authProviderManager ? authProviderManager.listProviders() : [],
    });
  }
  res.json({
    hasUser: count.count > 0,
    registrationOpen: policy.registrationOpen || count.count === 0,
    deploymentProfile: policy.profile,
    authenticated: Boolean(currentUser),
    user: currentUser ? toUserPayload(currentUser) : null,
    email: {
      enabled: emailConfig.enabled,
      configured: emailConfig.configured,
      signupConfirmationRequired: requireSignupEmailConfirmation(),
    },
    providers: authProviderManager ? authProviderManager.listProviders() : [],
  });
});

router.get('/api/auth/providers', (req, res) => {
  const authProviderManager = getAuthProviderManager(req);
  if (!authProviderManager) {
    return res.json({ providers: [] });
  }
  return res.json({ providers: authProviderManager.listProviders() });
});

router.post('/api/auth/providers/:provider/begin', authLimiter, async (req, res) => {
  try {
    const authProviderManager = getAuthProviderManager(req);
    if (!authProviderManager) {
      throw new Error('Provider sign-in is not available.');
    }
    const mode = String(req.body?.mode || '').trim().toLowerCase();
    const result = await authProviderManager.beginAuthorization({
      providerKey: req.params.provider,
      mode,
      userId: mode === 'link' ? req.session?.userId || null : null,
    });
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message || 'Provider sign-in failed.' });
  }
});

router.get('/api/auth/providers/complete', async (req, res) => {
  try {
    const authProviderManager = getAuthProviderManager(req);
    if (!authProviderManager) {
      throw new Error('Provider sign-in is not available.');
    }
    const state = String(req.query?.state || '').trim();
    const completion = authProviderManager.consumeAuthorization(state);
    if (completion.status === 'pending') {
      return res.json(completion);
    }
    if (completion.mode === 'link') {
      return res.json({
        success: true,
        status: 'completed',
        mode: completion.mode,
        provider: completion.provider,
        result: completion.result,
      });
    }

    const user = db.prepare(
      `SELECT id, username, email, email_verified_at, password_login_enabled, created_at, last_login
       FROM users
       WHERE id = ?`,
    ).get(completion.result.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (getTwoFactorStatus(user.id).enabled) {
      return establishPendingTwoFactorSession(req, res, user);
    }
    updateLastLogin(user.id);
    return establishSession(req, res, user);
  } catch (error) {
    const statusCode = Number(error?.statusCode || 400);
    return res.status(statusCode).json({ error: error.message || 'Provider sign-in failed.' });
  }
});

router.post('/api/auth/register', authLimiter, async (req, res) => {
  try {
    const policy = getDeploymentPolicy();
    const username = String(req.body?.username || '').trim();
    const password = String(req.body?.password || '');
    const email = requireValidEmail(req.body?.email);
    if (!username || !password) {
      return res.status(400).json({ error: 'Username, email, and password required' });
    }
    if (username.length < 3 || password.length < 8) {
      return res.status(400).json({ error: 'Username min 3 chars, password min 8' });
    }

    const passwordStrength = evaluatePasswordStrength(password, { username, email });
    if (!passwordStrength.isAcceptable) {
      return res.status(400).json({ error: passwordStrengthError(passwordStrength) });
    }

    const confirmationRequired = requireSignupEmailConfirmation();
    if (confirmationRequired && !isServiceEmailConfigured()) {
      return res.status(503).json({ error: 'Service email is not configured for account confirmation' });
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
      return db.prepare(`
        INSERT INTO users (username, email, email_verified_at, password, password_login_enabled)
        VALUES (?, ?, CASE WHEN ? THEN NULL ELSE datetime('now') END, ?, 1)
      `).run(username, email, confirmationRequired ? 1 : 0, hash);
    });
    const result = createUser();

    if (confirmationRequired) {
      const user = { id: result.lastInsertRowid, username, email };
      const { token } = createEmailToken(user.id, 'signup_confirmation', email);
      try {
        await sendSignupConfirmation(user, token);
      } catch (sendError) {
        db.transaction(() => {
          db.prepare('DELETE FROM user_email_tokens WHERE user_id = ?').run(user.id);
          db.prepare('DELETE FROM users WHERE id = ?').run(user.id);
        })();
        console.error('Signup confirmation email failed:', sendError);
        return res.status(503).json({ error: 'Could not send confirmation email' });
      }
      return res.status(202).json({
        success: false,
        requiresEmailConfirmation: true,
        message: 'Check your email to confirm your NeoAgent account.',
      });
    }

    establishSession(req, res, {
      id: result.lastInsertRowid,
      username,
      email,
      email_verified_at: new Date().toISOString(),
      password_login_enabled: 1,
      created_at: new Date().toISOString(),
      last_login: null,
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
    const username = String(req.body?.username || '').trim();
    const password = String(req.body?.password || '');
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    const user = db.prepare(
      `SELECT id, username, email, email_verified_at, password, password_login_enabled, created_at, last_login
       FROM users
       WHERE username = ?`,
    ).get(username);
    if (!user || Number(user.password_login_enabled || 0) !== 1) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (requireSignupEmailConfirmation() && !user.email_verified_at) {
      return res.status(403).json({
        error: 'Email confirmation required before sign in',
        requiresEmailConfirmation: true,
      });
    }

    if (getTwoFactorStatus(user.id).enabled) {
      return establishPendingTwoFactorSession(req, res, user);
    }

    updateLastLogin(user.id);
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

    const user = db.prepare(
      `SELECT id, username, email, email_verified_at, password_login_enabled, created_at, last_login
       FROM users
       WHERE id = ?`,
    ).get(pendingUserId);
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    if (requireSignupEmailConfirmation() && !user.email_verified_at) {
      return res.status(403).json({
        error: 'Email confirmation required before sign in',
        requiresEmailConfirmation: true,
      });
    }

    updateLastLogin(user.id);
    establishSession(req, res, user);
  } catch (err) {
    console.error('2FA login error:', err);
    res.status(500).json({ error: 'Two-factor login failed' });
  }
});

router.get('/api/auth/email/confirm', async (req, res) => {
  try {
    const token = String(req.query?.token || '').trim();
    if (!token) {
      return sendEmailConfirmationPage(res, {
        ok: false,
        title: 'Confirmation link missing',
        message: 'Open the full confirmation link from your NeoAgent email.',
      });
    }
    const result = consumeEmailToken(token);
    if (result.type === 'email_change_confirmation') {
      sendEmailChangedNotice(result.user, result.previousEmail, result.email).catch((noticeError) => {
        console.warn('Email changed notification failed:', noticeError.message);
      });
    }
    return sendEmailConfirmationPage(res, {
      ok: true,
      title: 'Email confirmed',
      message: 'Your NeoAgent email is confirmed. You can return to the app and sign in.',
    });
  } catch (err) {
    return sendEmailConfirmationPage(res, {
      ok: false,
      title: 'Could not confirm email',
      message: err?.message || 'This confirmation link is invalid or expired.',
    });
  }
});

router.post('/api/auth/password/forgot', authLimiter, async (req, res) => {
  const message = 'If that account has a confirmed email, NeoAgent will send a password reset link.';
  const startedAt = Date.now();
  const minimumLatencyMs = 350;

  async function finish() {
    const elapsed = Date.now() - startedAt;
    if (elapsed < minimumLatencyMs) {
      await new Promise((resolve) => setTimeout(resolve, minimumLatencyMs - elapsed));
    }
    return res.json({ success: true, message });
  }

  try {
    if (!isServiceEmailConfigured()) {
      return finish();
    }
    const account = String(req.body?.account || '').trim().toLowerCase();
    if (account) {
      const user = db.prepare(`
        SELECT id, username, email
        FROM users
        WHERE email IS NOT NULL
          AND trim(email) != ''
          AND (lower(username) = ? OR lower(email) = ?)
      `).get(account, account);
      if (user?.email) {
        const { token } = createEmailToken(user.id, 'password_reset', user.email);
        await sendPasswordResetEmail(user, token);
      }
    }
    return finish();
  } catch (err) {
    console.error('Forgot password error:', err);
    return finish();
  }
});

router.post('/api/auth/qr-login/challenge', authLimiter, (req, res) => {
  try {
    const challenge = createChallenge(req, {
      requestMetadata: req.body?.requestMetadata,
    });
    const payload = new URL('neoagent://qr-login');
    payload.searchParams.set('v', '1');
    payload.searchParams.set('backend', baseUrlFor(req));
    payload.searchParams.set('challenge', challenge.challengeId);
    payload.searchParams.set('secret', challenge.approveSecret);
    res.json({
      challengeId: challenge.challengeId,
      pollToken: challenge.pollToken,
      expiresAt: challenge.expiresAt,
      status: challenge.status,
      qrPayload: payload.toString(),
      backendUrl: baseUrlFor(req),
    });
  } catch (error) {
    res.status(Number(error?.statusCode || 500)).json({
      error: error?.message || 'Could not create QR login request.',
    });
  }
});

router.post('/api/auth/qr-login/challenge/:id/status', qrLoginPollLimiter, (req, res) => {
  try {
    const pollToken = String(req.body?.token || '').trim();
    if (!pollToken) {
      return res.status(400).json({ error: 'QR login poll token is required.' });
    }
    res.json(
      getChallengeStatusForPoll({
        challengeId: req.params.id,
        pollToken,
      }),
    );
  } catch (error) {
    res.status(Number(error?.statusCode || 500)).json({
      error: error?.message || 'Could not read QR login status.',
    });
  }
});

router.post('/api/auth/qr-login/challenge/:id/claim', qrLoginClaimLimiter, (req, res) => {
  try {
    const pollToken = String(req.body?.token || '').trim();
    if (!pollToken) {
      return res.status(400).json({ error: 'QR login poll token is required.' });
    }
    const result = claimApprovedChallenge({
      challengeId: req.params.id,
      pollToken,
    });
    updateLastLogin(result.user.id);
    return establishSession(req, res, result.user);
  } catch (error) {
    const statusCode = Number(error?.statusCode || 500);
    return res.status(statusCode).json({
      error: error?.message || 'Could not complete QR login.',
    });
  }
});

router.get('/api/auth/password/reset', (req, res) => {
  const token = String(req.query?.token || '').trim();
  if (!token) {
    return sendPasswordResetPage(res, {
      token: '',
      error: 'Open the full password reset link from your NeoAgent email.',
    });
  }
  return sendPasswordResetPage(res, { token });
});

router.post('/api/auth/password/reset', passwordResetLimiter, async (req, res) => {
  const token = String(req.body?.token || '').trim();
  const password = String(req.body?.password || '');
  const confirmPassword = String(req.body?.confirmPassword || '');
  try {
    if (!token) {
      return sendPasswordResetPage(res, {
        token,
        error: 'Open the full password reset link from your NeoAgent email.',
      });
    }
    const passwordStrength = evaluatePasswordStrength(password);
    if (!passwordStrength.hasMinimumLength) {
      return sendPasswordResetPage(res, {
        token,
        error: 'Use a password with at least 8 characters.',
      });
    }
    if (!passwordStrength.isAcceptable) {
      return sendPasswordResetPage(res, {
        token,
        error: passwordStrengthError(passwordStrength),
      });
    }
    if (password !== confirmPassword) {
      return sendPasswordResetPage(res, {
        token,
        error: 'Passwords do not match.',
      });
    }
    const hash = await bcrypt.hash(password, 12);
    const result = consumePasswordResetToken(token, hash);
    db.prepare('UPDATE users SET password_login_enabled = 1 WHERE id = ?').run(result.user.id);
    revokeAllSessionsForUser(result.user.id);
    sendPasswordChangedNotice(result.user).catch((noticeError) => {
      console.warn('Password reset notification failed:', noticeError.message);
    });
    return sendPasswordResetPage(res, { success: true });
  } catch (err) {
    return sendPasswordResetPage(res, {
      token,
      error: err?.message || 'This password reset link is invalid or expired.',
    });
  }
});

router.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ error: 'Logout failed' });
    const secureCookies = req.app?.locals?.httpRuntimeConfig?.secureCookies === true;
    res.clearCookie('neoagent.sid', {
      path: '/',
      httpOnly: true,
      sameSite: 'lax',
      secure: secureCookies,
    });
    res.json({ success: true });
  });
});

router.get('/api/auth/me', (req, res) => {
  const user = readAuthenticatedUser(req);
  if (!user) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  res.json({ user: toUserPayload(user) });
});

module.exports = router;
