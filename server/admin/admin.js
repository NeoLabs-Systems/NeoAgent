'use strict';

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

  const loaders = { overview: loadHealth, logs: loadLogs, issues: loadIssues, updates: loadVersion, config: loadConfig, providers: loadProviders, models: loadModels, analytics: loadAnalytics, users: loadUsers, sql: loadSql, access: loadAccess };
  loaders[page]?.();
}

// ── Theme ──────────────────────────────────────────────────────────────────

function applyTheme(theme) {
  const isLight = theme === 'light';
  document.documentElement.setAttribute('data-theme', isLight ? 'light' : 'dark');
  const label = document.getElementById('theme-toggle-label');
  if (label) label.textContent = isLight ? 'Dark mode' : 'Light mode';
}

function toggleTheme() {
  const next = document.documentElement.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
  try { localStorage.setItem('admin-theme', next); } catch {}
  applyTheme(next);
}

function initTheme() {
  let stored = 'dark';
  try { stored = localStorage.getItem('admin-theme') || 'dark'; } catch {}
  applyTheme(stored);
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
      alert(body.error || 'Failed to start update');
    }
    setTimeout(loadVersion, 1200);
  } catch (err) {
    if (err.message !== 'unauthorized') alert('Failed to trigger update');
  }
}

// ── Configuration ──────────────────────────────────────────────────────────

async function loadConfig() {
  const el = document.getElementById('config-content');
  if (!el) return;
  loadEmailConfig();
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
      alert(body.error || 'Failed to save email settings');
      return;
    }
    await loadEmailConfig();
  } catch (err) {
    if (err.message !== 'unauthorized') alert('Network error');
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
            type="${p.type === 'url' ? 'text' : 'password'}"
            placeholder="${p.type === 'url' ? 'http://localhost:11434' : 'Paste new key…'}"
            autocomplete="off"
            spellcheck="false"
            aria-label="${esc(p.label)} API key"
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
      alert(body.error || 'Failed to save');
    } else {
      btn.textContent = 'Saved!';
      setTimeout(loadProviders, 800);
      return;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') alert('Network error');
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
    if (err.message !== 'unauthorized') alert('Network error');
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
      alert(body.error || 'Failed to save');
    } else {
      btn.textContent = 'Saved!';
      setTimeout(() => { btn.textContent = original; btn.disabled = false; }, 2000);
      return;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') alert('Network error');
  }
  btn.disabled = false;
  btn.textContent = original;
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
