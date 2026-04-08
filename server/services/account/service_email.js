'use strict';

const crypto = require('crypto');
const nodemailer = require('nodemailer');
const db = require('../../db/database');
const { resolvePublicBaseUrl } = require('../integrations/env');

const TOKEN_BYTES = 32;
const DEFAULT_TOKEN_TTL_HOURS = 24;

function trimEnv(name) {
  return String(process.env[name] || '').trim();
}

function envBool(name, defaultValue = false) {
  const raw = trimEnv(name).toLowerCase();
  if (!raw) return defaultValue;
  return ['1', 'true', 'yes', 'on'].includes(raw);
}

function envNumber(name, defaultValue) {
  const value = Number(trimEnv(name));
  return Number.isFinite(value) && value > 0 ? value : defaultValue;
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex');
}

function sqliteDateFromMs(ms) {
  return new Date(ms).toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, '');
}

function publicBaseUrl() {
  return (trimEnv('NEOAGENT_EMAIL_PUBLIC_URL') || resolvePublicBaseUrl()).replace(/\/$/, '');
}

function getEmailConfig() {
  const host = trimEnv('NEOAGENT_EMAIL_SMTP_HOST');
  const port = envNumber('NEOAGENT_EMAIL_SMTP_PORT', 587);
  const from = trimEnv('NEOAGENT_EMAIL_FROM');
  const secureDefault = port === 465;
  const secure = envBool('NEOAGENT_EMAIL_SMTP_SECURE', secureDefault);
  const requireTls = envBool('NEOAGENT_EMAIL_SMTP_REQUIRE_TLS', !secure);
  const rejectUnauthorized = envBool('NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED', true);
  const missing = [];
  if (!host) missing.push('NEOAGENT_EMAIL_SMTP_HOST');
  if (!from) missing.push('NEOAGENT_EMAIL_FROM');
  const enabled = missing.length === 0;
  return {
    enabled,
    configured: enabled,
    missing,
    host,
    port,
    secure,
    requireTls,
    rejectUnauthorized,
    user: trimEnv('NEOAGENT_EMAIL_SMTP_USER'),
    pass: trimEnv('NEOAGENT_EMAIL_SMTP_PASS'),
    from,
    replyTo: trimEnv('NEOAGENT_EMAIL_REPLY_TO'),
    brandName: trimEnv('NEOAGENT_EMAIL_BRAND_NAME') || 'NeoAgent',
    supportUrl: trimEnv('NEOAGENT_EMAIL_SUPPORT_URL'),
    publicUrl: publicBaseUrl(),
    tokenTtlHours: envNumber('NEOAGENT_EMAIL_TOKEN_TTL_HOURS', DEFAULT_TOKEN_TTL_HOURS),
    notifyUnusualLogin: envBool('NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN', true),
    notifyAccountChanges: envBool('NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES', true),
  };
}

function isServiceEmailConfigured() {
  return getEmailConfig().configured;
}

function requireSignupEmailConfirmation() {
  const config = getEmailConfig();
  return config.enabled && envBool('NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION', true);
}

function requireEmailChangeConfirmation() {
  const config = getEmailConfig();
  return config.enabled && envBool('NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION', true);
}

function createTransport(config = getEmailConfig()) {
  if (!config.configured) {
    const error = new Error(`Service email is not configured: missing ${config.missing.join(', ')}`);
    error.statusCode = 503;
    throw error;
  }
  return nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    requireTLS: config.requireTls,
    auth: config.user || config.pass ? { user: config.user, pass: config.pass } : undefined,
    tls: { rejectUnauthorized: config.rejectUnauthorized },
  });
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderDetails(details) {
  if (!details || !details.length) return '';
  const rows = details.map((detail) => `
    <tr>
      <td style="padding:10px 0;color:#64748b;font-size:13px;">${escapeHtml(detail.label)}</td>
      <td style="padding:10px 0;color:#0f172a;font-size:13px;font-weight:600;text-align:right;">${escapeHtml(detail.value)}</td>
    </tr>
  `).join('');
  return `
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-top:22px;border-top:1px solid #e2e8f0;border-bottom:1px solid #e2e8f0;">
      ${rows}
    </table>
  `;
}

function renderEmail({ title, intro, actionUrl, actionLabel, details = [], footer, brandName = 'NeoAgent' }) {
  const safeTitle = escapeHtml(title);
  const safeIntro = escapeHtml(intro);
  const safeFooter = escapeHtml(footer || 'This mailbox is used only for NeoAgent service notifications.');
  const safeBrandName = escapeHtml(brandName);
  const action = actionUrl && actionLabel ? `
    <div style="margin-top:28px;">
      <a href="${escapeHtml(actionUrl)}" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:700;border-radius:8px;padding:13px 18px;">
        ${escapeHtml(actionLabel)}
      </a>
    </div>
    <p style="margin:18px 0 0;color:#64748b;font-size:12px;line-height:1.6;">If the button does not work, open this link:<br><span style="word-break:break-all;">${escapeHtml(actionUrl)}</span></p>
  ` : '';

  return `<!doctype html>
<html>
  <body style="margin:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#0f172a;">
    <div style="display:none;max-height:0;overflow:hidden;color:transparent;">${safeTitle}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8fafc;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden;box-shadow:0 18px 45px rgba(15,23,42,0.08);">
            <tr>
              <td style="padding:28px 28px 10px;">
                <div style="display:inline-block;border-radius:999px;background:#ccfbf1;color:#0f766e;font-weight:800;font-size:12px;letter-spacing:.08em;text-transform:uppercase;padding:8px 11px;">${safeBrandName}</div>
                <h1 style="margin:22px 0 0;font-size:25px;line-height:1.25;color:#0f172a;">${safeTitle}</h1>
                <p style="margin:14px 0 0;color:#475569;font-size:15px;line-height:1.65;">${safeIntro}</p>
                ${action}
                ${renderDetails(details)}
              </td>
            </tr>
            <tr>
              <td style="padding:20px 28px 28px;">
                <p style="margin:0;color:#64748b;font-size:12px;line-height:1.6;">${safeFooter}</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function renderText({ title, intro, actionUrl, actionLabel, details = [], footer }) {
  const lines = [title, '', intro];
  if (actionUrl && actionLabel) lines.push('', `${actionLabel}: ${actionUrl}`);
  if (details.length) {
    lines.push('');
    for (const detail of details) {
      lines.push(`${detail.label}: ${detail.value}`);
    }
  }
  lines.push('', footer || 'This mailbox is used only for NeoAgent service notifications.');
  return lines.join('\n');
}

async function sendServiceEmail(to, message) {
  const config = getEmailConfig();
  if (!config.enabled) return { skipped: true, reason: 'disabled' };
  const transport = createTransport(config);
  const footer = message.footer || (
    config.supportUrl
      ? `This mailbox is used only for ${config.brandName} service notifications. Support: ${config.supportUrl}`
      : `This mailbox is used only for ${config.brandName} service notifications.`
  );
  const themedMessage = { ...message, brandName: config.brandName, footer };
  const payload = {
    from: config.from,
    to,
    replyTo: config.replyTo || undefined,
    subject: themedMessage.subject,
    text: renderText(themedMessage),
    html: renderEmail(themedMessage),
  };
  return transport.sendMail(payload);
}

function createEmailToken(userId, type, email, ttlHours = getEmailConfig().tokenTtlHours) {
  const token = crypto.randomBytes(TOKEN_BYTES).toString('base64url');
  const hash = tokenHash(token);
  const expiresAt = sqliteDateFromMs(Date.now() + ttlHours * 60 * 60 * 1000);
  db.transaction(() => {
    db.prepare(`
      UPDATE user_email_tokens
      SET consumed_at = COALESCE(consumed_at, datetime('now'))
      WHERE user_id = ? AND type = ? AND consumed_at IS NULL
    `).run(userId, type);
    db.prepare(`
      INSERT INTO user_email_tokens (user_id, type, email, token_hash, expires_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(userId, type, email, hash, expiresAt);
  })();
  return { token, expiresAt };
}

function confirmationUrl(token) {
  const url = new URL('/api/auth/email/confirm', publicBaseUrl());
  url.searchParams.set('token', token);
  return url.toString();
}

function passwordResetUrl(token) {
  const url = new URL('/api/auth/password/reset', publicBaseUrl());
  url.searchParams.set('token', token);
  return url.toString();
}

function consumeEmailToken(token) {
  const hash = tokenHash(token);
  const row = db.prepare(`
    SELECT t.*, u.username, u.email AS current_email
    FROM user_email_tokens t
    JOIN users u ON u.id = t.user_id
    WHERE t.token_hash = ?
      AND t.consumed_at IS NULL
      AND datetime(t.expires_at) > datetime('now')
  `).get(hash);
  if (!row) {
    const error = new Error('Email confirmation link is invalid or expired');
    error.statusCode = 400;
    throw error;
  }

  if (row.type === 'signup_confirmation') {
    db.transaction(() => {
      db.prepare(`
        UPDATE users
        SET email_verified_at = datetime('now')
        WHERE id = ? AND lower(email) = lower(?)
      `).run(row.user_id, row.email);
      db.prepare('UPDATE user_email_tokens SET consumed_at = datetime(\'now\') WHERE id = ?').run(row.id);
    })();
  } else if (row.type === 'email_change_confirmation') {
    const existing = db.prepare('SELECT id FROM users WHERE lower(email) = lower(?) AND id != ?')
      .get(row.email, row.user_id);
    if (existing) {
      const error = new Error('Email is already in use');
      error.statusCode = 409;
      throw error;
    }
    db.transaction(() => {
      db.prepare(`
        UPDATE users
        SET email = ?, email_verified_at = datetime('now')
        WHERE id = ?
      `).run(row.email, row.user_id);
      db.prepare(`
        UPDATE user_email_tokens
        SET consumed_at = datetime('now')
        WHERE user_id = ? AND type = 'email_change_confirmation' AND consumed_at IS NULL
      `).run(row.user_id);
    })();
  } else {
    const error = new Error('Unsupported email confirmation type');
    error.statusCode = 400;
    throw error;
  }

  return {
    type: row.type,
    email: row.email,
    previousEmail: row.current_email || null,
    user: { id: row.user_id, username: row.username },
  };
}

function consumePasswordResetToken(token, passwordHash) {
  const hash = tokenHash(token);
  const row = db.prepare(`
    SELECT t.*, u.username, u.email AS current_email
    FROM user_email_tokens t
    JOIN users u ON u.id = t.user_id
    WHERE t.token_hash = ?
      AND t.type = 'password_reset'
      AND t.consumed_at IS NULL
      AND datetime(t.expires_at) > datetime('now')
  `).get(hash);
  if (!row) {
    const error = new Error('Password reset link is invalid or expired');
    error.statusCode = 400;
    throw error;
  }

  db.transaction(() => {
    db.prepare('UPDATE users SET password = ? WHERE id = ?')
      .run(passwordHash, row.user_id);
    db.prepare(`
      UPDATE user_email_tokens
      SET consumed_at = datetime('now')
      WHERE user_id = ? AND type = 'password_reset' AND consumed_at IS NULL
    `).run(row.user_id);
  })();

  return {
    email: row.email,
    user: { id: row.user_id, username: row.username, email: row.current_email },
  };
}

async function sendSignupConfirmation(user, token) {
  const url = confirmationUrl(token);
  return sendServiceEmail(user.email, {
    subject: 'Confirm your NeoAgent email',
    title: 'Confirm your email',
    intro: `Confirm this email address to finish creating the NeoAgent account ${user.username}.`,
    actionUrl: url,
    actionLabel: 'Confirm email',
    details: [
      { label: 'Account', value: user.username },
      { label: 'Expires', value: `${getEmailConfig().tokenTtlHours} hours` },
    ],
  });
}

async function sendEmailChangeConfirmation(user, newEmail, token) {
  const url = confirmationUrl(token);
  return sendServiceEmail(newEmail, {
    subject: 'Confirm your new NeoAgent email',
    title: 'Confirm your new email',
    intro: `Confirm this address before NeoAgent changes the account email for ${user.username}.`,
    actionUrl: url,
    actionLabel: 'Confirm new email',
    details: [
      { label: 'Account', value: user.username },
      { label: 'New email', value: newEmail },
    ],
  });
}

async function sendUnusualLoginNotice(user, sessionInfo) {
  const config = getEmailConfig();
  if (!config.configured || !config.notifyUnusualLogin || !user.email) return;
  return sendServiceEmail(user.email, {
    subject: 'New NeoAgent sign-in',
    title: 'New sign-in detected',
    intro: 'A sign-in to your NeoAgent account used a new device or network pattern.',
    details: [
      { label: 'Account', value: user.username },
      { label: 'Location', value: sessionInfo.location || 'Unknown' },
      { label: 'IP address', value: sessionInfo.ipAddress || 'Unknown' },
      { label: 'Device', value: sessionInfo.userAgent || 'Unknown' },
      { label: 'Time', value: new Date().toISOString() },
    ],
  });
}

async function sendPasswordChangedNotice(user) {
  const config = getEmailConfig();
  if (!config.configured || !config.notifyAccountChanges || !user.email) return;
  return sendServiceEmail(user.email, {
    subject: 'NeoAgent password changed',
    title: 'Your password was changed',
    intro: `The password for ${user.username} was changed. If this was not you, rotate your password and revoke unknown sessions.`,
    details: [
      { label: 'Account', value: user.username },
      { label: 'Time', value: new Date().toISOString() },
    ],
  });
}

async function sendPasswordResetEmail(user, token) {
  const url = passwordResetUrl(token);
  return sendServiceEmail(user.email, {
    subject: 'Reset your NeoAgent password',
    title: 'Reset your password',
    intro: `Use this link to set a new password for ${user.username}. Ignore this email if you did not request a reset.`,
    actionUrl: url,
    actionLabel: 'Reset password',
    details: [
      { label: 'Account', value: user.username },
      { label: 'Expires', value: `${getEmailConfig().tokenTtlHours} hours` },
    ],
  });
}

async function sendEmailChangedNotice(user, previousEmail, newEmail) {
  const config = getEmailConfig();
  if (!config.configured || !config.notifyAccountChanges) return;
  const details = [
    { label: 'Account', value: user.username },
    { label: 'New email', value: newEmail },
    { label: 'Time', value: new Date().toISOString() },
  ];
  if (previousEmail) {
    await sendServiceEmail(previousEmail, {
      subject: 'NeoAgent email changed',
      title: 'Your account email was changed',
      intro: `The email address for ${user.username} was changed.`,
      details,
    });
  }
  if (newEmail && newEmail !== previousEmail) {
    await sendServiceEmail(newEmail, {
      subject: 'NeoAgent email changed',
      title: 'This email is now linked',
      intro: `This address is now linked to the NeoAgent account ${user.username}.`,
      details,
    });
  }
}

async function sendEmailChangeRequestedNotice(user, requestedEmail) {
  const config = getEmailConfig();
  if (!config.configured || !config.notifyAccountChanges || !user.email) return;
  return sendServiceEmail(user.email, {
    subject: 'NeoAgent email change requested',
    title: 'Email change requested',
    intro: `A request was made to change the email for ${user.username}. The change will not apply until the new address is confirmed.`,
    details: [
      { label: 'Account', value: user.username },
      { label: 'Requested email', value: requestedEmail },
      { label: 'Time', value: new Date().toISOString() },
    ],
  });
}

module.exports = {
  consumeEmailToken,
  consumePasswordResetToken,
  createEmailToken,
  getEmailConfig,
  isServiceEmailConfigured,
  requireEmailChangeConfirmation,
  requireSignupEmailConfirmation,
  sendEmailChangedNotice,
  sendEmailChangeConfirmation,
  sendEmailChangeRequestedNotice,
  sendPasswordChangedNotice,
  sendPasswordResetEmail,
  sendServiceEmail,
  sendSignupConfirmation,
  sendUnusualLoginNotice,
};
