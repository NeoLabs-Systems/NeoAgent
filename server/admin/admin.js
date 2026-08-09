'use strict';

// ── Shared UI Helpers ──────────────────────────────────────────────────────

function showToast(message, type = 'info') {
  // type: 'info' | 'success' | 'error'
  let stack = document.getElementById('admin-toast-stack');
  if (!stack) {
    stack = document.createElement('div');
    stack.id = 'admin-toast-stack';
    stack.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:99999;display:flex;flex-direction:column;gap:10px;pointer-events:none;';
    document.body.appendChild(stack);
  }
  const toast = document.createElement('div');
  const colors = { info: 'var(--info,#3b82f6)', success: 'var(--success,#22c55e)', error: 'var(--danger,#ef4444)' };
  toast.style.cssText = `background:var(--bg-primary,#1a1a1a);border:1px solid ${colors[type] || colors.info};border-radius:10px;padding:12px 18px;color:var(--text,#fff);font-size:13px;box-shadow:0 6px 24px rgba(0,0,0,0.4);pointer-events:auto;max-width:360px;line-height:1.5;opacity:0;transform:translateY(8px);transition:opacity 0.18s,transform 0.18s;`;
  toast.textContent = message;
  stack.appendChild(toast);
  requestAnimationFrame(() => { toast.style.opacity = '1'; toast.style.transform = 'translateY(0)'; });
  const remove = () => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(8px)';
    setTimeout(() => toast.remove(), 200);
  };
  toast.onclick = remove;
  setTimeout(remove, 4000);
}

function showConfirmModal({ title, body, confirmLabel = 'Confirm', confirmClass = 'btn-danger', onConfirm }) {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.6);display:flex;align-items:center;justify-content:center;z-index:99990;backdrop-filter:blur(2px);';
    const modal = document.createElement('div');
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-labelledby', 'admin-modal-title');
    modal.style.cssText = 'width:440px;max-width:calc(100vw - 32px);background:var(--bg-primary,#1a1a1a);border:1px solid var(--border,#2a2a2a);border-radius:12px;padding:28px;box-shadow:0 16px 48px rgba(0,0,0,0.6);';
    modal.innerHTML = `
      <div id="admin-modal-title" style="font-size:16px;font-weight:700;color:var(--text);margin-bottom:12px;"></div>
      <div style="font-size:13px;color:var(--text-muted);line-height:1.6;margin-bottom:24px;">${body}</div>
      <div style="display:flex;gap:10px;justify-content:flex-end;">
        <button class="btn btn-ghost" id="admin-modal-cancel" style="padding:8px 16px;">Cancel</button>
        <button class="btn ${confirmClass}" id="admin-modal-confirm" style="padding:8px 16px;">${confirmLabel}</button>
      </div>
    `;
    modal.querySelector('#admin-modal-title').textContent = title;
    overlay.appendChild(modal);
    document.body.appendChild(overlay);
    const cancel = () => { overlay.remove(); resolve(false); };
    const confirm = () => { overlay.remove(); resolve(true); if (onConfirm) onConfirm(); };
    modal.querySelector('#admin-modal-cancel').onclick = cancel;
    modal.querySelector('#admin-modal-confirm').onclick = confirm;
    overlay.addEventListener('click', (e) => { if (e.target === overlay) cancel(); });
    document.addEventListener('keydown', function handler(e) {
      if (e.key === 'Escape') { cancel(); document.removeEventListener('keydown', handler); }
    });
    modal.querySelector('#admin-modal-confirm').focus();
  });
}

// ── State ──────────────────────────────────────────────────────────────────

let currentPage = 'overview';
let localLogs   = [];
let logsCleared = false;

// ── Navigation ─────────────────────────────────────────────────────────────

function showPage(page, btn) {
  document.querySelectorAll('.page').forEach((el) => el.classList.remove('active'));
  document.querySelectorAll('.nav-item[data-page]').forEach((el) => el.classList.remove('active'));
  const section = document.getElementById('page-' + page);
  if (section) section.classList.add('active');
  if (btn) btn.classList.add('active');
  currentPage = page;

  const billingLoader = typeof loadBilling !== 'undefined' ? loadBilling : null;
  const loaders = { overview: loadHealth, logs: loadLogs, issues: loadIssues, updates: loadVersion, config: loadConfig, providers: loadProviders, models: loadModels, analytics: loadAnalytics, users: loadUsers, sql: loadSql, access: loadAccess, billing: billingLoader, integrations: loadIntegrationsConfig };
  loaders[page]?.();
}

// ── Theme ──────────────────────────────────────────────────────────────────

function applyTheme(isLight) {
  document.documentElement.setAttribute('data-theme', isLight ? 'light' : 'dark');
}

function initTheme() {
  const mq = window.matchMedia('(prefers-color-scheme: light)');
  applyTheme(mq.matches);
  mq.addEventListener('change', (e) => applyTheme(e.matches));
}

async function signOut() {
  await fetch('/admin/api/logout', { method: 'POST' }).catch(() => {});
  window.location.replace('/admin/login');
}

// ── HTTP helpers ───────────────────────────────────────────────────────────

async function api(path, opts = {}) {
  const res = await fetch(path, opts);
  if (res.status === 401) {
    window.location.replace('/admin/login');
    throw new Error('unauthorized');
  }
  return res;
}

function esc(str) {
  return String(str ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

function fmtTime(iso) {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleTimeString(); } catch { return iso; }
}

function fmtUptime(s) {
  if (!s) return '—';
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : m > 0 ? `${m}m ${Math.floor(s % 60)}s` : `${Math.floor(s)}s`;
}

function setTs(id, label) {
  const el = document.getElementById(id);
  if (el) el.textContent = `${label} ${new Date().toLocaleTimeString()}`;
}

// ── Overview ───────────────────────────────────────────────────────────────

async function loadHealth() {
  const grid = document.getElementById('health-grid');
  if (!grid) return;
  try {
    const data = await api('/admin/api/health').then((r) => r.json());
    if (!data.results?.length) {
      grid.innerHTML = '<div class="empty">No health data available</div>';
      return;
    }
    grid.innerHTML = data.results.map((item) => `
      <div class="status-tile">
        <div class="status-dot ${item.passed ? 'ok' : 'fail'}" aria-hidden="true"></div>
        <div>
          <div class="status-label">${esc(item.label)}</div>
          <div class="status-detail">${esc(item.detail || '')}</div>
        </div>
      </div>`).join('');
    setTs('overview-ts', 'Updated');
  } catch (err) {
    if (err.message !== 'unauthorized') {
      grid.innerHTML = '<div class="empty">Failed to load health data</div>';
    }
  }
}

// ── Logs ───────────────────────────────────────────────────────────────────

async function loadLogs() {
  if (logsCleared) { renderLogs(localLogs); return; }
  try {
    const data = await api('/admin/api/logs').then((r) => r.json());
    localLogs = data.logs || [];
    renderLogs(localLogs);
    setTs('logs-ts', 'Updated');
  } catch (err) {
    if (err.message !== 'unauthorized') {
      document.getElementById('log-table').innerHTML = '<div class="empty">Failed to load logs</div>';
    }
  }
}

function renderLogs(logs) {
  const count = document.getElementById('log-count');
  const table = document.getElementById('log-table');
  if (!table) return;
  if (count) count.textContent = `${logs.length} entr${logs.length === 1 ? 'y' : 'ies'}`;
  if (!logs.length) { table.innerHTML = '<div class="empty">No log entries</div>'; return; }
  table.innerHTML = logs.map((e) => {
    const level = e.type || 'log';
    const msgClass = (level === 'error' || level === 'warn') ? `log-msg-${level}` : '';
    return `<div class="log-row">
      <div class="log-cell log-ts">${esc(fmtTime(e.timestamp))}</div>
      <div class="log-cell log-level-${esc(level)}">${esc(level)}</div>
      <div class="log-cell msg ${msgClass}">${esc(e.message || '')}</div>
    </div>`;
  }).join('');
  table.scrollTop = table.scrollHeight;
}

function clearLogs() {
  logsCleared = true;
  localLogs   = [];
  renderLogs([]);
}

function copyLogs() {
  const text = localLogs
    .map((e) => `[${e.timestamp || ''}] [${e.type || 'log'}] ${e.message || ''}`)
    .join('\n');
  navigator.clipboard.writeText(text).catch(() => {});
}

// ── Issues ─────────────────────────────────────────────────────────────────

// Distil the raw log stream down to critical, actionable issues: error-level
// entries grouped by message so a repeated failure shows up once with a count.
function groupIssues(logs) {
  const groups = new Map();
  for (const entry of logs) {
    if ((entry.type || 'log') !== 'error') continue;
    const message = String(entry.message || '').trim();
    if (!message) continue;
    const existing = groups.get(message);
    if (existing) {
      existing.count += 1;
      if (entry.timestamp && entry.timestamp > existing.last) existing.last = entry.timestamp;
    } else {
      groups.set(message, { message, count: 1, last: entry.timestamp || '' });
    }
  }
  return Array.from(groups.values()).sort((a, b) => String(b.last).localeCompare(String(a.last)));
}

function renderIssues(issues) {
  const table = document.getElementById('issue-table');
  const count = document.getElementById('issue-count');
  const badge = document.getElementById('issues-badge');
  if (count) count.textContent = `${issues.length} issue${issues.length === 1 ? '' : 's'}`;
  if (badge) {
    if (issues.length) { badge.hidden = false; badge.textContent = String(issues.length); }
    else { badge.hidden = true; }
  }
  if (!table) return;
  if (!issues.length) { table.innerHTML = '<div class="empty">No critical issues 🎉</div>'; return; }
  table.innerHTML = issues.map((i) => `
    <div class="issue-row">
      <div class="issue-msg">${esc(i.message)}</div>
      <div class="issue-meta">
        ${i.count > 1 ? `<span class="issue-count">×${i.count}</span><br>` : ''}
        ${esc(fmtTime(i.last))}
      </div>
    </div>`).join('');
}

async function loadIssues() {
  try {
    const data = await api('/admin/api/logs').then((r) => r.json());
    localLogs = data.logs || localLogs;
    renderIssues(groupIssues(localLogs));
    setTs('issues-ts', 'Updated');
  } catch (err) {
    if (err.message !== 'unauthorized') {
      const table = document.getElementById('issue-table');
      if (table) table.innerHTML = '<div class="empty">Failed to load issues</div>';
    }
  }
}

// ── Updates ────────────────────────────────────────────────────────────────

async function loadVersion() {
  const vEl = document.getElementById('version-content');
  const uEl = document.getElementById('update-content');
  if (!vEl || !uEl) return;
  try {
    const d = await api('/admin/api/version').then((r) => r.json());
    const st = d.updateStatus || {};
    const running = st.state === 'running';
    const canUpdate = d.allowSelfUpdate !== false;
    const ch = d.releaseChannel || 'stable';

    vEl.innerHTML = `
      <div class="kv-row"><span class="kv-key">Version</span><span class="kv-val">${esc(d.version || d.packageVersion || '—')}</span></div>
      <div class="kv-row"><span class="kv-key">Git SHA</span><span class="kv-val">${esc(d.gitSha ? d.gitSha.slice(0, 10) : '—')}</span></div>
      <div class="kv-row"><span class="kv-key">Branch</span><span class="kv-val">${esc(d.gitBranch || '—')}</span></div>
      <div class="kv-row"><span class="kv-key">Node.js</span><span class="kv-val">${esc(d.nodeVersion || '—')}</span></div>
      <div class="kv-row"><span class="kv-key">Uptime</span><span class="kv-val">${esc(fmtUptime(d.uptime))}</span></div>
      <div class="kv-row"><span class="kv-key">Deployment</span><span class="kv-val">${esc(d.deploymentMode || '—')}</span></div>
    `;

    const badgeClass = st.state === 'idle'    ? 'badge-idle'
                     : st.state === 'running' ? 'badge-running'
                     : st.state === 'failed'  ? 'badge-err'
                     : 'badge-ok';

    uEl.innerHTML = `
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px;flex-wrap:wrap;">
        <span class="badge ${badgeClass}">${esc(st.state || 'idle')}</span>
        ${st.message ? `<span style="font-size:13px;color:var(--text-muted)">${esc(st.message)}</span>` : ''}
      </div>
      ${running ? `
        <div class="progress-track">
          <div class="progress-fill" style="width:${st.progress || 0}%"></div>
        </div>
        <p style="font-size:12px;color:var(--text-muted);margin-bottom:16px">
          ${st.progress || 0}% — ${esc(st.phase || '')}
        </p>` : ''}
      ${canUpdate ? `
        <div class="update-controls">
          <div class="field">
            <label for="channel-select">Release channel</label>
            <select id="channel-select" onchange="saveChannel(this.value)" ${running ? 'disabled' : ''} style="width:auto;min-width:120px;">
              <option value="stable" ${ch === 'stable' ? 'selected' : ''}>Stable</option>
              <option value="beta"   ${ch === 'beta'   ? 'selected' : ''}>Beta</option>
            </select>
          </div>
          <button id="update-btn" class="btn btn-primary" onclick="triggerUpdate()" ${running ? 'disabled' : ''}>
            <svg viewBox="0 0 20 20" fill="currentColor" style="width:13px;height:13px;" aria-hidden="true">
              <path fill-rule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd"/>
            </svg>
            ${running ? 'Updating…' : 'Trigger update'}
          </button>
        </div>` : `
        <p style="font-size:13px;color:var(--text-muted)">Updates are managed for this deployment.</p>`}
    `;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      vEl.innerHTML = '<div class="empty">Failed to load version info</div>';
      uEl.innerHTML = '';
    }
  }
}

async function saveChannel(channel) {
  try {
    await api('/admin/api/update/channel', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ channel }),
    });
  } catch {}
}

async function triggerUpdate() {
  const btn = document.getElementById('update-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'Starting…'; }
  try {
    const res = await api('/admin/api/update', { method: 'POST' });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      showToast(body.error || 'Failed to start update', 'error');
    }
    setTimeout(loadVersion, 1200);
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Failed to trigger update', 'error');
  }
}

// ── Configuration ──────────────────────────────────────────────────────────

async function loadConfig() {
  const el = document.getElementById('config-content');
  if (!el) return;
  loadEmailConfig();
  loadGeneralConfig();
  loadVmConfig();
  loadBillingSetupConfig();
  try {
    const data = await api('/admin/api/config').then((r) => r.json());
    const cfg  = data.config || {};
    const keys = Object.keys(cfg);
    if (!keys.length) { el.innerHTML = '<div class="empty">No configuration data</div>'; return; }
    el.innerHTML = `<table class="config-table"><tbody>${
      keys.map((k) => {
        const v = cfg[k];
        const display = v
          ? `<span>${esc(v)}</span>`
          : `<span class="config-empty">—</span>`;
        return `<tr><td>${esc(k)}</td><td>${display}</td></tr>`;
      }).join('')
    }</tbody></table>`;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load configuration</div>';
    }
  }
}

async function loadEmailConfig() {
  const el = document.getElementById('email-config-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/config/email').then((r) => r.json());
    const s = data.settings || {};
    const status = data.configured
      ? '<span class="badge badge-ok">configured</span><span>Account emails are enabled.</span>'
      : `<span class="badge badge-idle">not configured</span><span>Missing: ${esc((data.missing || []).join(', '))}</span>`;

    el.innerHTML = `
      <div class="email-settings-status">${status}</div>
      <form id="email-settings-form" onsubmit="saveEmailConfig(event)">
        <div class="email-settings-grid">
          <div class="field field-wide">
            <label for="email-from">Sender address</label>
            <input type="text" id="email-from" value="${esc(s.from)}" autocomplete="off">
          </div>
          <div class="field">
            <label for="email-smtp-host">SMTP host</label>
            <input type="text" id="email-smtp-host" value="${esc(s.smtpHost)}" autocomplete="off" spellcheck="false">
          </div>
          <div class="field">
            <label for="email-smtp-port">SMTP port</label>
            <input type="text" inputmode="numeric" id="email-smtp-port" value="${esc(s.smtpPort)}" autocomplete="off">
          </div>
          <div class="field">
            <label for="email-smtp-user">SMTP username</label>
            <input type="text" id="email-smtp-user" value="${esc(s.smtpUser)}" autocomplete="off" spellcheck="false">
          </div>
          <div class="field">
            <label for="email-smtp-password">SMTP password</label>
            <input type="password" id="email-smtp-password" value="" autocomplete="new-password">
            <div style="font-size:11px;color:var(--text-muted);margin-top:6px;">
              ${s.smtpPasswordConfigured ? 'A password is stored. Leave blank to keep it.' : 'No password is stored.'}
            </div>
          </div>
          <div class="field">
            <label for="email-reply-to">Reply-To address</label>
            <input type="text" id="email-reply-to" value="${esc(s.replyTo)}" autocomplete="off">
          </div>
          <div class="field">
            <label for="email-brand-name">Brand name</label>
            <input type="text" id="email-brand-name" value="${esc(s.brandName)}" autocomplete="off">
          </div>
          <div class="field">
            <label for="email-public-url">Public URL override</label>
            <input type="text" id="email-public-url" value="${esc(s.publicUrl)}" autocomplete="off" spellcheck="false">
          </div>
          <div class="field">
            <label for="email-support-url">Support URL</label>
            <input type="text" id="email-support-url" value="${esc(s.supportUrl)}" autocomplete="off" spellcheck="false">
          </div>
          <div class="field">
            <label for="email-token-ttl">Link lifetime (hours)</label>
            <input type="text" inputmode="numeric" id="email-token-ttl" value="${esc(s.tokenTtlHours)}" autocomplete="off">
          </div>
        </div>
        <div class="email-settings-checks">
          ${emailConfigCheckbox('email-smtp-secure', 'Implicit TLS', s.smtpSecure)}
          ${emailConfigCheckbox('email-smtp-require-tls', 'Require STARTTLS', s.smtpRequireTls)}
          ${emailConfigCheckbox('email-smtp-reject-unauthorized', 'Reject invalid TLS certificates', s.smtpRejectUnauthorized)}
          ${emailConfigCheckbox('email-signup-confirmation', 'Require signup confirmation', s.requireSignupConfirmation)}
          ${emailConfigCheckbox('email-change-confirmation', 'Require email change confirmation', s.requireEmailChangeConfirmation)}
          ${emailConfigCheckbox('email-notify-login', 'Notify on unusual login', s.notifyUnusualLogin)}
          ${emailConfigCheckbox('email-notify-account', 'Notify on account changes', s.notifyAccountChanges)}
        </div>
        <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
          <button class="btn btn-primary" type="submit">Save Email Settings</button>
          ${s.smtpPasswordConfigured ? '<button class="btn btn-danger" type="button" onclick="clearEmailPassword(this)">Remove SMTP Password</button>' : ''}
        </div>
      </form>`;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load email configuration</div>';
    }
  }
}

function emailConfigCheckbox(id, label, checked) {
  return `<label class="email-setting-check" for="${id}">
    <input type="checkbox" id="${id}" ${checked ? 'checked' : ''}>
    <span>${esc(label)}</span>
  </label>`;
}

function emailConfigValue(id) {
  return document.getElementById(id)?.value?.trim() || '';
}

function collectEmailConfig(clearSmtpPassword = false) {
  return {
    from: emailConfigValue('email-from'),
    smtpHost: emailConfigValue('email-smtp-host'),
    smtpPort: emailConfigValue('email-smtp-port'),
    smtpUser: emailConfigValue('email-smtp-user'),
    smtpPassword: clearSmtpPassword ? '' : emailConfigValue('email-smtp-password'),
    clearSmtpPassword,
    smtpSecure: document.getElementById('email-smtp-secure')?.checked === true,
    smtpRequireTls: document.getElementById('email-smtp-require-tls')?.checked === true,
    smtpRejectUnauthorized: document.getElementById('email-smtp-reject-unauthorized')?.checked === true,
    replyTo: emailConfigValue('email-reply-to'),
    requireSignupConfirmation: document.getElementById('email-signup-confirmation')?.checked === true,
    requireEmailChangeConfirmation: document.getElementById('email-change-confirmation')?.checked === true,
    notifyUnusualLogin: document.getElementById('email-notify-login')?.checked === true,
    notifyAccountChanges: document.getElementById('email-notify-account')?.checked === true,
    brandName: emailConfigValue('email-brand-name'),
    supportUrl: emailConfigValue('email-support-url'),
    publicUrl: emailConfigValue('email-public-url'),
    tokenTtlHours: emailConfigValue('email-token-ttl'),
  };
}

async function persistEmailConfig(payload, btn) {
  const original = btn?.textContent;
  if (btn) {
    btn.disabled = true;
    btn.textContent = 'Saving…';
  }
  try {
    const res = await api('/admin/api/config/email', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      showToast(body.error || 'Failed to save email settings', 'error');
      return;
    }
    await loadEmailConfig();
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  } finally {
    if (btn?.isConnected) {
      btn.disabled = false;
      btn.textContent = original;
    }
  }
}

async function saveEmailConfig(event) {
  event.preventDefault();
  await persistEmailConfig(collectEmailConfig(), event.submitter);
}

async function clearEmailPassword(btn) {
  await persistEmailConfig(collectEmailConfig(true), btn);
}

// ── Providers ──────────────────────────────────────────────────────────────

async function loadProviders() {
  const el = document.getElementById('providers-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/providers').then((r) => r.json());
    const providers = data.providers || [];
    if (!providers.length) { el.innerHTML = '<div class="empty">No providers configured</div>'; return; }
    el.innerHTML = providers.map((p) => `
      <div class="provider-row" data-key="${esc(p.key)}">
        <div class="provider-meta">
          <span class="provider-name">${esc(p.label)}</span>
          ${p.configured
            ? `<span class="badge badge-ok">configured</span><span class="provider-hint">${esc(p.hint)}</span>`
            : `<span class="badge badge-idle">not set</span>`}
        </div>
        <div class="provider-controls">
          <input
            type="${p.type === 'url' ? 'url' : 'password'}"
            placeholder="${p.type === 'url' ? '' : 'Paste new key…'}"
            autocomplete="off"
            spellcheck="false"
            aria-label="${esc(p.label)}"
          >
          <button class="btn btn-ghost provider-save-btn" onclick="saveProvider('${esc(p.key)}', this)">Save</button>
          ${p.configured ? `<button class="btn btn-danger provider-save-btn" onclick="clearProvider('${esc(p.key)}', this)" title="Remove key">✕</button>` : ''}
        </div>
      </div>`).join('');
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load providers</div>';
    }
  }
}

async function saveProvider(key, btn) {
  const row = btn.closest('.provider-row');
  const input = row?.querySelector('input');
  const value = input?.value?.trim() || '';
  if (!value) { input?.focus(); return; }
  if (input && !input.reportValidity()) return;
  btn.disabled = true;
  const original = btn.textContent;
  btn.textContent = 'Saving…';
  try {
    const res = await api('/admin/api/providers', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key, value }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      showToast(body.error || 'Failed to save', 'error');
    } else {
      btn.textContent = 'Saved!';
      setTimeout(loadProviders, 800);
      return;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  }
  btn.disabled = false;
  btn.textContent = original;
}

async function clearProvider(key, btn) {
  btn.disabled = true;
  try {
    await api('/admin/api/providers', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key, value: '' }),
    });
    setTimeout(loadProviders, 400);
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
    btn.disabled = false;
  }
}

// ── Models ─────────────────────────────────────────────────────────────────

function fmtModelPrice(inputCostPerM) {
  if (inputCostPerM === null || inputCostPerM === undefined) return '—';
  if (inputCostPerM === 0) return 'Free';
  if (inputCostPerM < 0.01) return `$${inputCostPerM.toFixed(4)}/M`;
  if (inputCostPerM < 1) return `$${inputCostPerM.toFixed(3)}/M`;
  return `$${inputCostPerM.toFixed(2)}/M`;
}

function priceTierClass(tier) {
  if (tier === 'free') return 'badge-ok';
  if (tier === 'cheap') return 'badge-ok';
  if (tier === 'medium') return 'badge-warn';
  if (tier === 'expensive') return 'badge-err';
  return 'badge-idle';
}

function purposeIcon(purpose) {
  const icons = { fast: '⚡', planning: '🧠', coding: '💻', general: '✦' };
  return icons[purpose] || '✦';
}

async function loadModels() {
  const el = document.getElementById('models-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/models').then((r) => r.json());
    const models = data.models || [];
    const disabledSet = new Set(data.disabledModels || []);

    if (!models.length) { el.innerHTML = '<div class="empty">No models found — configure providers first.</div>'; return; }

    // Sort: provider alpha, then price low→high within provider
    models.sort((a, b) => {
      if (a.provider !== b.provider) return a.provider.localeCompare(b.provider);
      const ac = a.inputCostPerM ?? Infinity;
      const bc = b.inputCostPerM ?? Infinity;
      return ac - bc;
    });

    const enabledCount = models.length - disabledSet.size;

    let html = `
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:14px;flex-wrap:wrap;">
        <button class="btn btn-ghost" style="padding:5px 12px;font-size:12px;" onclick="toggleAllModels(true)">Enable All</button>
        <button class="btn btn-ghost" style="padding:5px 12px;font-size:12px;" onclick="toggleAllModels(false)">Disable All</button>
        <span style="margin-left:4px;font-size:12px;color:var(--text-muted);" id="model-count-label">${enabledCount} of ${models.length} enabled</span>
      </div>
      <table class="users-table">
      <thead><tr>
        <th style="width:40px;">On</th>
        <th>Model</th>
        <th>Provider</th>
        <th style="width:90px;">Purpose</th>
        <th style="width:80px;">Tier</th>
        <th style="width:110px;text-align:right;">Input / 1M tokens</th>
      </tr></thead>
      <tbody>`;

    for (const m of models) {
      const isEnabled = !disabledSet.has(m.id);
      const priceStr = fmtModelPrice(m.inputCostPerM);
      const tierCls = priceTierClass(m.priceTier);
      const icon = purposeIcon(m.purpose);
      html += `
        <tr style="opacity:${isEnabled ? '1' : '0.45'}">
          <td style="text-align:center;">
            <input type="checkbox" class="model-cb" value="${esc(m.id)}" ${isEnabled ? 'checked' : ''}
              onchange="onModelToggle(this)">
          </td>
          <td>
            <div style="font-weight:600;color:var(--text);font-size:13px;">${esc(m.label)}</div>
            <div style="font-size:11px;color:var(--text-muted);font-family:var(--font-mono);margin-top:2px;">${esc(m.id)}</div>
          </td>
          <td style="font-size:13px;text-transform:capitalize;">${esc(m.provider)}</td>
          <td><span class="badge badge-idle">${icon} ${esc(m.purpose)}</span></td>
          <td><span class="badge ${tierCls}">${esc(m.priceTier ?? '?')}</span></td>
          <td style="text-align:right;font-family:var(--font-mono);font-size:13px;font-weight:600;color:var(--text);">${priceStr}</td>
        </tr>
      `;
    }

    html += `</tbody></table>`;
    el.innerHTML = html;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load models</div>';
    }
  }
}

function onModelToggle(cb) {
  const row = cb.closest('tr');
  if (row) row.style.opacity = cb.checked ? '1' : '0.45';
  const all = document.querySelectorAll('.model-cb');
  const checked = Array.from(all).filter(c => c.checked).length;
  const label = document.getElementById('model-count-label');
  if (label) label.textContent = `${checked} of ${all.length} enabled`;
}

function toggleAllModels(enable) {
  document.querySelectorAll('.model-cb').forEach(cb => {
    cb.checked = enable;
    const row = cb.closest('tr');
    if (row) row.style.opacity = enable ? '1' : '0.45';
  });
  const all = document.querySelectorAll('.model-cb');
  const label = document.getElementById('model-count-label');
  if (label) label.textContent = `${enable ? all.length : 0} of ${all.length} enabled`;
}

async function saveEnabledModels(btn) {
  const cbs = document.querySelectorAll('.model-cb');
  if (!cbs.length) return;

  // Persist only the disabled (unchecked) models
  const disabledModels = Array.from(cbs).filter(cb => !cb.checked).map(cb => cb.value);

  btn.disabled = true;
  const original = btn.textContent;
  btn.textContent = 'Saving…';

  try {
    const res = await api('/admin/api/models/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ disabledModels }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      showToast(body.error || 'Failed to save', 'error');
    } else {
      btn.textContent = 'Saved!';
      setTimeout(() => { btn.textContent = original; btn.disabled = false; }, 2000);
      return;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  }
  btn.disabled = false;
  btn.textContent = original;
}

// ── General Config ─────────────────────────────────────────────────────────

async function loadGeneralConfig() {
  const el = document.getElementById('general-config-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/config/general').then((r) => r.json());
    const s = data.settings || {};
    el.innerHTML = `
      <form id="general-config-form" onsubmit="saveGeneralConfig(event)">
        <div class="email-settings-grid">
          <div class="field field-wide">
            <label for="gc-public-url">Public URL</label>
            <input type="text" id="gc-public-url" value="${esc(s.publicUrl)}" autocomplete="off" spellcheck="false" placeholder="https://agent.example.com">
          </div>
          <div class="field">
            <label for="gc-profile">Deployment profile</label>
            <select id="gc-profile">
              <option value="prod" ${s.neoagentProfile === 'prod' ? 'selected' : ''}>prod (multi-user / isolated VM)</option>
              <option value="private" ${s.neoagentProfile === 'private' ? 'selected' : ''}>private (single-user)</option>
            </select>
          </div>
          <div class="field">
            <label for="gc-allowed-origins">Allowed CORS origins</label>
            <input type="text" id="gc-allowed-origins" value="${esc(s.allowedOrigins)}" autocomplete="off" spellcheck="false" placeholder="https://a.com,https://b.com">
          </div>
          <div class="field">
            <label for="gc-memory-interval">Memory ingestion interval (ms)</label>
            <input type="number" min="1000" step="1000" id="gc-memory-interval" value="${esc(s.memoryIngestionIntervalMs)}" autocomplete="off">
          </div>
        </div>
        <div class="email-settings-checks" style="margin-top:4px;">
          ${emailConfigCheckbox('gc-secure-cookies', 'Secure cookies (required behind HTTPS / TLS proxy)', s.secureCookies)}
          ${emailConfigCheckbox('gc-meshtastic', 'Meshtastic enabled', s.meshtasticEnabled)}
        </div>
        <button class="btn btn-primary" type="submit">Save General Settings</button>
      </form>`;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load general configuration</div>';
    }
  }
}

async function saveGeneralConfig(event) {
  event.preventDefault();
  const btn = event.submitter;
  const original = btn?.textContent;
  if (btn) { btn.disabled = true; btn.textContent = 'Saving…'; }
  try {
    const res = await api('/admin/api/config/general', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        publicUrl: document.getElementById('gc-public-url')?.value?.trim() || '',
        secureCookies: document.getElementById('gc-secure-cookies')?.checked === true,
        neoagentProfile: document.getElementById('gc-profile')?.value || '',
        allowedOrigins: document.getElementById('gc-allowed-origins')?.value?.trim() || '',
        meshtasticEnabled: document.getElementById('gc-meshtastic')?.checked === true,
        memoryIngestionIntervalMs: parseInt(document.getElementById('gc-memory-interval')?.value || '600000', 10),
      }),
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      showToast(body.error || 'Failed to save', 'error');
    } else {
      showToast('General settings saved', 'success');
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  } finally {
    if (btn?.isConnected) { btn.disabled = false; btn.textContent = original; }
  }
}

// ── VM Runtime Config ──────────────────────────────────────────────────────

async function loadVmConfig() {
  const el = document.getElementById('vm-config-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/config/vm').then((r) => r.json());
    const s = data.settings || {};
    el.innerHTML = `
      <form id="vm-config-form" onsubmit="saveVmConfig(event)">
        <div class="email-settings-grid">
          <div class="field field-wide">
            <label for="vm-base-image-url">Base image URL</label>
            <input type="text" id="vm-base-image-url" value="${esc(s.vmBaseImageUrl)}" autocomplete="off" spellcheck="false"
              placeholder="https://cloud-images.ubuntu.com/…">
          </div>
          <div class="field field-wide">
            <label for="vm-base-image">Local base image path override</label>
            <input type="text" id="vm-base-image" value="${esc(s.vmBaseImage)}" autocomplete="off" spellcheck="false"
              placeholder="/path/to/base.img (takes precedence over URL)">
          </div>
          <div class="field">
            <label for="vm-memory-mb">Memory (MB)</label>
            <input type="number" min="512" step="256" id="vm-memory-mb" value="${esc(s.vmMemoryMb)}" autocomplete="off">
          </div>
          <div class="field">
            <label for="vm-cpus">vCPUs</label>
            <input type="number" min="1" step="1" id="vm-cpus" value="${esc(s.vmCpus)}" autocomplete="off">
          </div>
        </div>
        <button class="btn btn-primary" type="submit" style="margin-top:8px;">Save VM Settings</button>
      </form>`;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load VM configuration</div>';
    }
  }
}

async function saveVmConfig(event) {
  event.preventDefault();
  const btn = event.submitter;
  const original = btn?.textContent;
  if (btn) { btn.disabled = true; btn.textContent = 'Saving…'; }
  try {
    const res = await api('/admin/api/config/vm', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        vmBaseImageUrl: document.getElementById('vm-base-image-url')?.value?.trim() || '',
        vmBaseImage: document.getElementById('vm-base-image')?.value?.trim() || '',
        vmMemoryMb: parseInt(document.getElementById('vm-memory-mb')?.value || '4096', 10),
        vmCpus: parseInt(document.getElementById('vm-cpus')?.value || '2', 10),
      }),
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      showToast(body.error || 'Failed to save', 'error');
    } else {
      showToast('VM settings saved', 'success');
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  } finally {
    if (btn?.isConnected) { btn.disabled = false; btn.textContent = original; }
  }
}

// ── Integrations Config ────────────────────────────────────────────────────

const INTEGRATION_FIELD_LABELS = {
  clientId: 'Client ID',
  clientSecret: 'Client secret',
  redirectUri: 'Redirect URI',
  tenantId: 'Tenant ID',
  apiKey: 'API key',
};

async function loadIntegrationsConfig() {
  const el = document.getElementById('integrations-config-content');
  const deepEl = document.getElementById('deepgram-config-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/config/integrations').then((r) => r.json());
    const integrations = data.integrations || [];

    el.innerHTML = integrations.map((integration) => {
      const fields = integration.fields.map((f) => {
        const fieldId = `int-${integration.key}-${f.name}`;
        const label = INTEGRATION_FIELD_LABELS[f.name] || f.name;
        if (f.secret) {
          return `<div class="field">
            <label for="${fieldId}">${esc(label)}</label>
            <input type="password" id="${fieldId}" value="" autocomplete="new-password"
              placeholder="${f.configured ? 'Stored — paste new value to update' : 'Not set'}">
            ${f.configured ? `<div style="font-size:11px;color:var(--text-muted);margin-top:4px;">A value is stored. Leave blank to keep it.</div>` : ''}
          </div>`;
        }
        return `<div class="field">
          <label for="${fieldId}">${esc(label)}</label>
          <input type="text" id="${fieldId}" value="${esc(f.value || '')}" autocomplete="off" spellcheck="false">
        </div>`;
      }).join('');

      const badge = integration.configured
        ? '<span class="badge badge-ok">configured</span>'
        : '<span class="badge badge-idle">not set</span>';

      return `<div class="integration-section" data-key="${esc(integration.key)}">
        <div class="integration-header">
          <span class="integration-name">${esc(integration.label)}</span>
          ${badge}
        </div>
        <div class="email-settings-grid">${fields}</div>
      </div>`;
    }).join('');

    if (deepEl) {
      const dg = data.deepgram || {};
      deepEl.innerHTML = `
        <form id="deepgram-config-form" onsubmit="saveDeepgramConfig(event)">
          <div class="email-settings-grid">
            <div class="field">
              <label for="dg-base-url">Base URL</label>
              <input type="text" id="dg-base-url" value="${esc(dg.baseUrl)}" autocomplete="off" spellcheck="false"
                placeholder="https://api.deepgram.com">
            </div>
            <div class="field">
              <label for="dg-model">Model</label>
              <input type="text" id="dg-model" value="${esc(dg.model)}" autocomplete="off" spellcheck="false"
                placeholder="nova-3">
            </div>
            <div class="field">
              <label for="dg-language">Language</label>
              <input type="text" id="dg-language" value="${esc(dg.language)}" autocomplete="off" spellcheck="false"
                placeholder="multi">
            </div>
          </div>
          <button class="btn btn-primary" type="submit" style="margin-top:8px;">Save Deepgram Settings</button>
        </form>`;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load integrations configuration</div>';
    }
  }
}

async function saveIntegrationsConfig(btn) {
  if (btn) { btn.disabled = true; const orig = btn.textContent; btn.textContent = 'Saving…';
    try {
      const integrationSections = document.querySelectorAll('.integration-section');
      const integrations = {};
      for (const section of integrationSections) {
        const key = section.dataset.key;
        integrations[key] = {};
        for (const input of section.querySelectorAll('input')) {
          const fieldName = input.id.replace(`int-${key}-`, '');
          integrations[key][fieldName] = input.value;
        }
      }
      const res = await api('/admin/api/config/integrations', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ integrations }),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        showToast(body.error || 'Failed to save', 'error');
      } else {
        showToast('Integration settings saved', 'success');
        setTimeout(loadIntegrationsConfig, 600);
      }
    } catch (err) {
      if (err.message !== 'unauthorized') showToast('Network error', 'error');
    } finally {
      if (btn.isConnected) { btn.disabled = false; btn.textContent = orig; }
    }
  }
}

async function saveDeepgramConfig(event) {
  event.preventDefault();
  const btn = event.submitter;
  const original = btn?.textContent;
  if (btn) { btn.disabled = true; btn.textContent = 'Saving…'; }
  try {
    const res = await api('/admin/api/config/integrations', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        deepgram: {
          baseUrl: document.getElementById('dg-base-url')?.value?.trim() || '',
          model: document.getElementById('dg-model')?.value?.trim() || '',
          language: document.getElementById('dg-language')?.value?.trim() || '',
        },
      }),
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      showToast(body.error || 'Failed to save', 'error');
    } else {
      showToast('Deepgram settings saved', 'success');
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  } finally {
    if (btn?.isConnected) { btn.disabled = false; btn.textContent = original; }
  }
}

// ── Billing Setup Config ───────────────────────────────────────────────────

async function loadBillingSetupConfig() {
  const el = document.getElementById('billing-setup-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/config/billing-setup').then((r) => r.json());
    const s = data.settings || {};
    el.innerHTML = `
      <form id="billing-setup-form" onsubmit="saveBillingSetupConfig(event)">
        <div style="font-size:12px;color:var(--text-muted);margin-bottom:16px;line-height:1.5;">
          Enable billing to expose Stripe-backed subscription flows. Requires a server restart when toggling.
        </div>
        <div class="email-settings-grid">
          <div class="field">
            <label for="bs-publishable-key">Stripe publishable key</label>
            <input type="text" id="bs-publishable-key" value="${esc(s.stripePublishableKey)}" autocomplete="off" spellcheck="false"
              placeholder="pk_test_…">
          </div>
          <div class="field">
            <label for="bs-secret-key">Stripe secret key</label>
            <input type="password" id="bs-secret-key" value="" autocomplete="new-password"
              placeholder="${s.stripeSecretKeyConfigured ? s.stripeSecretKeyHint + ' — paste new to update' : 'sk_test_…'}">
            ${s.stripeSecretKeyConfigured ? `<div style="font-size:11px;color:var(--text-muted);margin-top:4px;">Key stored. Leave blank to keep it.</div>` : ''}
          </div>
          <div class="field">
            <label for="bs-webhook-secret">Stripe webhook signing secret</label>
            <input type="password" id="bs-webhook-secret" value="" autocomplete="new-password"
              placeholder="${s.stripeWebhookSecretConfigured ? 'Stored — paste new to update' : 'whsec_…'}">
            ${s.stripeWebhookSecretConfigured ? `<div style="font-size:11px;color:var(--text-muted);margin-top:4px;">Secret stored. Leave blank to keep it.</div>` : ''}
          </div>
          <div class="field">
            <label for="bs-trial-days">Free trial period (days)</label>
            <input type="number" min="0" step="1" id="bs-trial-days" value="${esc(s.trialDays)}" autocomplete="off">
          </div>
        </div>
        <div class="email-settings-checks" style="margin-top:4px;">
          ${emailConfigCheckbox('bs-billing-enabled', 'Billing enabled', s.billingEnabled)}
        </div>
        <button class="btn btn-primary" type="submit">Save Billing Configuration</button>
      </form>`;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      el.innerHTML = '<div class="empty">Failed to load billing configuration</div>';
    }
  }
}

async function saveBillingSetupConfig(event) {
  event.preventDefault();
  const btn = event.submitter;
  const original = btn?.textContent;
  if (btn) { btn.disabled = true; btn.textContent = 'Saving…'; }
  try {
    const res = await api('/admin/api/config/billing-setup', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        billingEnabled: document.getElementById('bs-billing-enabled')?.checked === true,
        stripePublishableKey: document.getElementById('bs-publishable-key')?.value?.trim() || '',
        stripeSecretKey: document.getElementById('bs-secret-key')?.value || '',
        stripeWebhookSecret: document.getElementById('bs-webhook-secret')?.value || '',
        trialDays: parseInt(document.getElementById('bs-trial-days')?.value || '14', 10),
      }),
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      showToast(body.error || 'Failed to save', 'error');
    } else {
      showToast('Billing configuration saved — restart the server to apply changes', 'success');
      setTimeout(loadBillingSetupConfig, 600);
      if (typeof refreshBillingNav === 'function') refreshBillingNav();
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showToast('Network error', 'error');
  } finally {
    if (btn?.isConnected) { btn.disabled = false; btn.textContent = original; }
  }
}

// ── Auto-refresh ───────────────────────────────────────────────────────────

function startPolling() {
  setInterval(() => { if (currentPage === 'overview') loadHealth();  }, 30_000);
  setInterval(() => { if (currentPage === 'logs' && !logsCleared) loadLogs(); }, 5_000);
  setInterval(() => { if (currentPage === 'issues') loadIssues(); }, 10_000);
  setInterval(() => { if (currentPage === 'updates') loadVersion();  }, 10_000);
}

// ── Init ───────────────────────────────────────────────────────────────────

(async function init() {
  initTheme();
  try {
    const res = await fetch('/admin/api/version');
    if (res.status === 401) { window.location.replace('/admin/login'); return; }
  } catch {
    // server unreachable — still render; API calls will fail gracefully
  }
  loadHealth();
  loadIssues();
  startPolling();
}());
