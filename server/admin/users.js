'use strict';

// ── User Management ────────────────────────────────────────────────────────

let _userSearchTimer = null;

async function loadUsers() {
  await Promise.all([loadDefaultRateLimits(), fetchUsers(document.getElementById('user-search')?.value?.trim() || '')]);
}

async function loadDefaultRateLimits() {
  try {
    const data = await api('/admin/api/config/rate-limits').then(r => r.json());
    const f4h = document.getElementById('default-limit-4h');
    const fw = document.getElementById('default-limit-weekly');
    if (f4h) f4h.value = data.rate_limit_4h ?? '';
    if (fw) fw.value = data.rate_limit_weekly ?? '';
  } catch (_) {}
}

async function saveDefaultRateLimits(btn) {
  const v4h = document.getElementById('default-limit-4h')?.value;
  const vw = document.getElementById('default-limit-weekly')?.value;
  const parse = (v) => (v !== '' && v != null) ? parseInt(v, 10) : null;
  btn.disabled = true;
  const orig = btn.textContent;
  btn.textContent = 'Saving…';
  try {
    const res = await api('/admin/api/config/rate-limits', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rate_limit_4h: parse(v4h), rate_limit_weekly: parse(vw) }),
    });
    if (!res.ok) { const b = await res.json().catch(() => ({})); alert(b.error || 'Failed'); }
    else { btn.textContent = 'Saved!'; setTimeout(() => { btn.textContent = orig; btn.disabled = false; }, 2000); return; }
  } catch (_) { alert('Network error'); }
  btn.disabled = false;
  btn.textContent = orig;
}

async function fetchUsers(q = '') {
  const el = document.getElementById('users-table-wrap');
  if (!el) return;
  el.innerHTML = '<div class="empty"><span class="spinner"></span></div>';
  try {
    const url = q ? `/admin/api/users?q=${encodeURIComponent(q)}` : '/admin/api/users';
    const data = await api(url).then((r) => r.json());
    renderUsersTable(el, data.users || []);
    const cnt = document.getElementById('users-count');
    if (cnt) cnt.textContent = `${(data.users || []).length} user${(data.users || []).length === 1 ? '' : 's'}`;
  } catch (err) {
    if (err.message !== 'unauthorized') el.innerHTML = '<div class="empty">Failed to load users</div>';
  }
}

function onUserSearch() {
  clearTimeout(_userSearchTimer);
  _userSearchTimer = setTimeout(() => {
    const q = document.getElementById('user-search')?.value?.trim() || '';
    fetchUsers(q);
  }, 300);
}

function renderUsersTable(el, users) {
  if (!users.length) {
    el.innerHTML = '<div class="empty">No users found</div>';
    return;
  }
  el.innerHTML = `
    <table class="users-table">
      <thead><tr>
        <th>User</th>
        <th>Email</th>
        <th>Joined</th>
        <th>Last Login</th>
        <th>Runs</th>
        <th>Storage</th>
        <th>Rate Limits</th>
        <th style="text-align:right;">Actions</th>
      </tr></thead>
      <tbody>${users.map((u) => `
        <tr data-uid="${esc(u.id)}">
          <td>
            <div style="display:flex;align-items:center;gap:9px;">
              <span class="user-avatar">${esc((u.display_name || u.username || '?')[0]).toUpperCase()}</span>
              <div>
                <div style="font-weight:600;color:var(--text);">${esc(u.display_name || u.username)}</div>
                ${u.display_name && u.display_name !== u.username ? `<div style="font-size:11px;color:var(--text-muted);">@${esc(u.username)}</div>` : ''}
              </div>
            </div>
          </td>
          <td>
            <span style="font-size:12px;">${esc(u.email || '—')}</span>
            ${u.email_verified_at
              ? '<span class="badge badge-ok" style="font-size:10px;margin-left:5px;">verified</span>'
              : u.email ? '<span class="badge badge-warn" style="font-size:10px;margin-left:5px;">unverified</span>' : ''}
          </td>
          <td style="font-size:12px;color:var(--text-muted);">${fmtDate(u.created_at)}</td>
          <td style="font-size:12px;color:var(--text-muted);">${u.last_login ? fmtDate(u.last_login) : '—'}</td>
          <td style="font-family:var(--font-mono);font-size:12px;">${fmtNum(u.run_count)}</td>
          <td style="font-family:var(--font-mono);font-size:12px;">${fmtBytes(u.storage_bytes)}</td>
          <td style="font-size:11px;">
            ${u.rate_limit_4h || u.rate_limit_weekly
              ? `<div style="display:flex;flex-direction:column;gap:3px;">
                  ${u.rate_limit_4h ? `<span class="badge badge-idle" style="font-size:10px;">4h: ${fmtTokens(u.rate_limit_4h)}</span>` : ''}
                  ${u.rate_limit_weekly ? `<span class="badge badge-idle" style="font-size:10px;">7d: ${fmtTokens(u.rate_limit_weekly)}</span>` : ''}
                 </div>`
              : `<span style="color:var(--text-muted);">none</span>`}
          </td>
          <td>
            <div style="display:flex;gap:6px;justify-content:flex-end;">
              <button class="btn btn-ghost" style="padding:5px 10px;font-size:11px;"
                onclick="editRateLimits('${esc(u.id)}','${esc(u.username)}')" title="Edit Rate Limits">
                Limits
              </button>
              <button class="btn btn-ghost" style="padding:5px 10px;font-size:11px;"
                onclick="forceLogout('${esc(u.id)}','${esc(u.username)}',this)" title="Revoke all sessions">
                Logout
              </button>
              <button class="btn btn-danger" style="padding:5px 10px;font-size:11px;"
                onclick="deleteUser('${esc(u.id)}','${esc(u.display_name || u.username)}',this)" title="GDPR: delete all user data">
                Delete
              </button>
            </div>
          </td>
        </tr>`).join('')}
      </tbody>
    </table>
    <p class="gdpr-note">
      ⚠ <strong>Delete</strong> permanently erases all user data (runs, messages, memories, artifacts, sessions) — irreversible. Required by GDPR Art. 17 right to erasure.
    </p>`;
}

async function forceLogout(id, username, btn) {
  if (!confirm(`Force logout ${username}?\n\nThis will revoke all active sessions. They can log back in.`)) return;
  btn.disabled = true;
  try {
    const res = await api(`/admin/api/users/${id}/sessions`, { method: 'DELETE' });
    if (res.ok) {
      btn.textContent = 'Done';
      setTimeout(loadUsers, 800);
    } else {
      const b = await res.json().catch(() => ({}));
      alert(b.error || 'Failed');
      btn.disabled = false;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') alert('Network error');
    btn.disabled = false;
  }
}

async function deleteUser(id, displayName, btn) {
  if (!confirm(
    `⚠ GDPR Erasure — permanently delete "${displayName}"?\n\n` +
    'This will delete the account and ALL associated data:\n' +
    '• Agent runs, steps, and messages\n• Memories and conversations\n• Integrations and platform connections\n• Artifacts and files on disk\n• All sessions\n\n' +
    'This action CANNOT be undone.'
  )) return;
  btn.disabled = true;
  btn.textContent = 'Deleting…';
  try {
    const res = await api(`/admin/api/users/${id}`, { method: 'DELETE' });
    if (res.ok) {
      btn.closest('tr')?.remove();
      const cnt = document.getElementById('users-count');
      if (cnt) {
        const n = parseInt(cnt.textContent) - 1;
        cnt.textContent = `${n} user${n === 1 ? '' : 's'}`;
      }
    } else {
      const b = await res.json().catch(() => ({}));
      alert(b.error || 'Failed to delete user');
      btn.disabled = false;
      btn.textContent = 'Delete';
    }
  } catch (err) {
    if (err.message !== 'unauthorized') alert('Network error');
    btn.disabled = false;
    btn.textContent = 'Delete';
  }
}

function fmtTokens(n) {
  if (!n) return '—';
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}k`;
  return String(n);
}

function fmtDate(iso) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
  } catch { return iso; }
}

async function editRateLimits(id, username) {
  try {
    const [userRes, globalRes] = await Promise.all([
      api(`/admin/api/users/${id}/rate-limits`).then(r => r.json()),
      api('/admin/api/config/rate-limits').then(r => r.json()).catch(() => ({})),
    ]);
    const limits = userRes.limits || {};
    const custom4h = limits.rate_limit_4h ?? null;
    const customWeekly = limits.rate_limit_weekly ?? null;
    const global4h = globalRes.rate_limit_4h ?? null;
    const globalWeekly = globalRes.rate_limit_weekly ?? null;

    const hint4h = global4h ? `Default: ${fmtTokens(global4h)} — empty inherits default` : 'Empty = no limit';
    const hintWeekly = globalWeekly ? `Default: ${fmtTokens(globalWeekly)} — empty inherits default` : 'Empty = no limit';

    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.6);display:flex;align-items:center;justify-content:center;z-index:9999;backdrop-filter:blur(2px);';
    const modal = document.createElement('div');
    modal.className = 'card';
    modal.style.cssText = 'width:440px;background:var(--bg-primary);box-shadow:0 10px 40px rgba(0,0,0,0.5);border:1px solid var(--border);border-radius:12px;padding:24px;';
    modal.innerHTML = `
      <div style="font-size:16px;font-weight:700;color:var(--text);margin-bottom:4px;">Rate Limits</div>
      <div style="font-size:13px;color:var(--text-muted);margin-bottom:20px;">
        Custom overrides for <span style="color:var(--text);font-weight:600;">@${esc(username)}</span>.
        Leave empty to inherit the global default.
      </div>

      <div style="margin-bottom:18px;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">
          <label style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.05em;color:var(--text-muted);">4-Hour Limit (tokens)</label>
          ${custom4h !== null ? '<span class="badge badge-warn" style="font-size:10px;">custom</span>' : (global4h ? '<span class="badge badge-idle" style="font-size:10px;">inheriting default</span>' : '<span class="badge badge-idle" style="font-size:10px;">no limit</span>')}
        </div>
        <input type="number" min="0" step="1" id="limit-4h" value="${custom4h ?? ''}" placeholder="${hint4h}"
          style="width:100%;padding:10px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:6px;color:var(--text);font-size:13px;">
      </div>

      <div style="margin-bottom:24px;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">
          <label style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.05em;color:var(--text-muted);">Weekly Limit (tokens)</label>
          ${customWeekly !== null ? '<span class="badge badge-warn" style="font-size:10px;">custom</span>' : (globalWeekly ? '<span class="badge badge-idle" style="font-size:10px;">inheriting default</span>' : '<span class="badge badge-idle" style="font-size:10px;">no limit</span>')}
        </div>
        <input type="number" min="0" step="1" id="limit-weekly" value="${customWeekly ?? ''}" placeholder="${hintWeekly}"
          style="width:100%;padding:10px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:6px;color:var(--text);font-size:13px;">
      </div>

      <div style="display:flex;gap:12px;justify-content:flex-end;">
        <button class="btn btn-ghost" id="btn-cancel" style="padding:8px 16px;">Cancel</button>
        <button class="btn btn-primary" id="btn-save" style="padding:8px 16px;">Save</button>
      </div>
    `;
    overlay.appendChild(modal);
    document.body.appendChild(overlay);

    document.getElementById('btn-cancel').onclick = () => overlay.remove();
    document.getElementById('btn-save').onclick = async () => {
      const v4 = document.getElementById('limit-4h').value;
      const vw = document.getElementById('limit-weekly').value;
      const parseLimit = (v) => { if (!v) return null; const n = Number(v); return Number.isInteger(n) && n >= 0 ? n : null; };
      const bSave = document.getElementById('btn-save');
      bSave.disabled = true;
      bSave.textContent = 'Saving…';
      try {
        const putRes = await api(`/admin/api/users/${id}/rate-limits`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ rate_limit_4h: parseLimit(v4), rate_limit_weekly: parseLimit(vw) }),
        });
        if (!putRes.ok) throw new Error('Save failed');
        overlay.remove();
        await fetchUsers(document.getElementById('user-search')?.value?.trim() || '');
      } catch (_) {
        alert('Failed to save rate limits');
        bSave.disabled = false;
        bSave.textContent = 'Save';
      }
    };
  } catch (_) {
    alert('Failed to fetch rate limits');
  }
}
