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

  const loaders = { overview: loadHealth, logs: loadLogs, updates: loadVersion, config: loadConfig, providers: loadProviders, analytics: loadAnalytics, users: loadUsers, sql: loadSql, access: loadAccess };
  loaders[page]?.();
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
  return String(str ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
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

// ── Auto-refresh ───────────────────────────────────────────────────────────

function startPolling() {
  setInterval(() => { if (currentPage === 'overview') loadHealth();  }, 30_000);
  setInterval(() => { if (currentPage === 'logs' && !logsCleared) loadLogs(); }, 5_000);
  setInterval(() => { if (currentPage === 'updates') loadVersion();  }, 10_000);
}

// ── Init ───────────────────────────────────────────────────────────────────

(async function init() {
  try {
    const res = await fetch('/admin/api/version');
    if (res.status === 401) { window.location.replace('/admin/login'); return; }
  } catch {
    // server unreachable — still render; API calls will fail gracefully
  }
  loadHealth();
  startPolling();
}());
