'use strict';

const crypto = require('crypto');
const nodemailer = require('nodemailer');
const db = require('../../db/database');
const { resolvePublicBaseUrl } = require('../integrations/env');
const { hashPassword, validateNewPassword } = require('./credentials');

const TOKEN_BYTES = 32;
const DEFAULT_TOKEN_TTL_HOURS = 24;
const PASSWORD_RESET_WINDOW_MS = 15 * 60 * 1000;
const PASSWORD_RESET_MAX_ATTEMPTS = 12;
const passwordResetAttemptState = new Map();

function registerPasswordResetAttempt(hash) {
  const now = Date.now();
  const current = passwordResetAttemptState.get(hash);
  if (!current || (now - current.windowStartedAt) > PASSWORD_RESET_WINDOW_MS) {
    passwordResetAttemptState.set(hash, { windowStartedAt: now, attempts: 1 });
    return;
  }
  current.attempts += 1;
}

function assertPasswordResetAttemptAllowed(hash) {
  const now = Date.now();
  const current = passwordResetAttemptState.get(hash);
  if (!current) return;
  if ((now - current.windowStartedAt) > PASSWORD_RESET_WINDOW_MS) {
    passwordResetAttemptState.delete(hash);
    return;
  }
  if (current.attempts >= PASSWORD_RESET_MAX_ATTEMPTS) {
    const error = new Error('Too many password reset attempts. Try again later.');
    error.statusCode = 429;
    throw error;
  }
}

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

// Colors and type mirror the landing site (landing/css/styles.css). Mail
// clients drop CSS variables and most <style> rules, so the light palette is
// inlined; the dark block only applies where prefers-color-scheme works.
const EMAIL_FONTS = {
  sans: "Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif",
  serif: "Fraunces,'Iowan Old Style',Georgia,'Times New Roman',serif",
  mono: "'IBM Plex Mono',SFMono-Regular,Menlo,Consolas,monospace",
};

const EMAIL_FONT_LINK = 'https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,560&family=IBM+Plex+Mono:wght@500;600&family=Inter:wght@440;600;700&display=swap';

const EMAIL_DARK_STYLES = `
  :root { color-scheme: light dark; supported-color-schemes: light dark; }
  @media (prefers-color-scheme: dark) {
    .na-bg { background:#0e1511 !important; }
    .na-card { background:#171f1a !important; border-color:#263129 !important; }
    .na-ink { color:#ecefe5 !important; }
    .na-ink-2 { color:#aeb7a6 !important; }
    .na-ink-3 { color:#7e8877 !important; }
    .na-gold { color:#eac272 !important; }
    .na-dot { background:#e1b052 !important; }
    .na-line { border-color:#263129 !important; }
    .na-btn { background:#e1b052 !important; color:#0e1511 !important; }
  }`;

function renderDetails(details) {
  if (!details || !details.length) return '';
  const rows = details.map((detail, index) => {
    const border = index === 0 ? '' : 'border-top:1px solid #e6e2d6;';
    return `
    <tr>
      <td class="na-line na-ink-3" style="${border}padding:12px 12px 12px 0;color:#7e8470;font-family:${EMAIL_FONTS.mono};font-size:11px;font-weight:500;letter-spacing:.12em;text-transform:uppercase;vertical-align:top;white-space:nowrap;">${escapeHtml(detail.label)}</td>
      <td class="na-line na-ink" style="${border}padding:12px 0;color:#1c2117;font-size:13.5px;font-weight:600;text-align:right;word-break:break-word;">${escapeHtml(detail.value)}</td>
    </tr>`;
  }).join('');
  return `
    <table role="presentation" class="na-line" width="100%" cellspacing="0" cellpadding="0" style="margin-top:28px;border-top:1px solid #e6e2d6;border-bottom:1px solid #e6e2d6;">
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
    <table role="presentation" cellspacing="0" cellpadding="0" style="margin-top:28px;">
      <tr>
        <td class="na-btn" style="border-radius:999px;background:#1c2117;">
          <a href="${escapeHtml(actionUrl)}" class="na-btn" style="display:inline-block;padding:13px 22px;border-radius:999px;background:#1c2117;color:#fdfcf8;font-family:${EMAIL_FONTS.sans};font-size:14.5px;font-weight:600;letter-spacing:-0.01em;text-decoration:none;">${escapeHtml(actionLabel)} &rarr;</a>
        </td>
      </tr>
    </table>
    <p class="na-ink-3" style="margin:18px 0 0;color:#7e8470;font-size:12px;line-height:1.6;">If the button does not work, open this link:<br><a href="${escapeHtml(actionUrl)}" class="na-gold" style="color:#8a5f1c;word-break:break-all;">${escapeHtml(actionUrl)}</a></p>
  ` : '';

  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="color-scheme" content="light dark">
    <meta name="supported-color-schemes" content="light dark">
    <title>${safeTitle}</title>
    <link href="${EMAIL_FONT_LINK}" rel="stylesheet">
    <style>${EMAIL_DARK_STYLES}
    </style>
  </head>
  <body class="na-bg" style="margin:0;padding:0;background:#f4f1e8;font-family:${EMAIL_FONTS.sans};color:#1c2117;-webkit-font-smoothing:antialiased;">
    <div style="display:none;max-height:0;overflow:hidden;color:transparent;">${safeTitle}</div>
    <table role="presentation" class="na-bg" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f1e8;padding:40px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;">
            <tr>
              <td style="padding:0 6px 18px;">
                <span class="na-ink" style="color:#1c2117;font-family:${EMAIL_FONTS.sans};font-size:17px;font-weight:700;letter-spacing:-0.03em;">${safeBrandName}</span>
              </td>
            </tr>
          </table>
          <table role="presentation" class="na-card" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fdfcf8;border:1px solid #e6e2d6;border-radius:26px;box-shadow:0 18px 48px -24px rgba(28,33,23,0.28),0 8px 20px -12px rgba(28,33,23,0.12);">
            <tr>
              <td style="padding:34px 32px 30px;">
                <table role="presentation" cellspacing="0" cellpadding="0">
                  <tr>
                    <td style="padding-right:9px;vertical-align:middle;"><div class="na-dot" style="width:6px;height:6px;border-radius:999px;background:#b07d2b;box-shadow:0 0 0 4px rgba(176,125,43,0.14);"></div></td>
                    <td class="na-gold" style="vertical-align:middle;color:#8a5f1c;font-family:${EMAIL_FONTS.mono};font-size:11px;font-weight:600;letter-spacing:.16em;text-transform:uppercase;">Account</td>
                  </tr>
                </table>
                <h1 class="na-ink" style="margin:18px 0 0;color:#1c2117;font-family:${EMAIL_FONTS.serif};font-size:30px;font-weight:560;line-height:1.1;letter-spacing:-0.015em;">${safeTitle}</h1>
                <p class="na-ink-2" style="margin:14px 0 0;color:#49503f;font-size:15.5px;line-height:1.65;">${safeIntro}</p>
                ${action}
                ${renderDetails(details)}
              </td>
            </tr>
          </table>
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;">
            <tr>
              <td style="padding:20px 6px 0;">
                <p class="na-ink-3" style="margin:0;color:#7e8470;font-size:12px;line-height:1.6;">${safeFooter}</p>
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

function invalidPasswordResetLinkError() {
  const error = new Error('Password reset link is invalid or expired');
  error.statusCode = 400;
  return error;
}

// Sets the new password if the token is still live. The password is checked
// against the account's own username and email, like at sign-up.
async function consumePasswordResetToken(token, password) {
  const hash = tokenHash(token);
  assertPasswordResetAttemptAllowed(hash);
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
    registerPasswordResetAttempt(hash);
    throw invalidPasswordResetLinkError();
  }

  validateNewPassword(password, { username: row.username, email: row.current_email });
  const passwordHash = await hashPassword(password);
  // The token is claimed inside the write so two submissions racing past the
  // lookup above cannot both set a password.
  const applied = db.transaction(() => {
    const claimed = db.prepare(`
      UPDATE user_email_tokens SET consumed_at = datetime('now')
      WHERE id = ? AND consumed_at IS NULL
    `).run(row.id);
    if (claimed.changes === 0) return false;
    db.prepare('UPDATE users SET password = ?, password_login_enabled = 1 WHERE id = ?')
      .run(passwordHash, row.user_id);
    db.prepare(`
      UPDATE user_email_tokens
      SET consumed_at = datetime('now')
      WHERE user_id = ? AND type = 'password_reset' AND consumed_at IS NULL
    `).run(row.user_id);
    return true;
  })();
  if (!applied) throw invalidPasswordResetLinkError();

  passwordResetAttemptState.delete(hash);

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
