'use strict';

// ── Analytics ─────────────────────────────────────────────────────────────

async function loadAnalytics() {
  const el = document.getElementById('analytics-content');
  if (!el) return;
  el.innerHTML = '<div class="empty"><span class="spinner"></span></div>';
  try {
    const data = await api('/admin/api/analytics').then((r) => r.json());
    renderAnalytics(el, data);
    setTs('analytics-ts', 'Updated');
  } catch (err) {
    if (err.message !== 'unauthorized') el.innerHTML = '<div class="empty">Failed to load analytics</div>';
  }
}

function renderAnalytics(el, { stats, topUsers, recentRuns }) {
  const s = stats || {};
  el.innerHTML = `
    <div class="stat-grid">
      <div class="stat-card">
        <div class="stat-value">${fmtNum(s.totalUsers)}</div>
        <div class="stat-label">Total Users</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtNum(s.activeToday)}</div>
        <div class="stat-label">Active Today</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtNum(s.newThisWeek)}</div>
        <div class="stat-label">New This Week</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtNum(s.totalRuns)}</div>
        <div class="stat-label">Total Runs</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtNum(s.runsToday)}</div>
        <div class="stat-label">Runs Today</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtTokens(s.totalTokens)}</div>
        <div class="stat-label">Total Tokens</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtNum(s.activeSessions)}</div>
        <div class="stat-label">Active Sessions</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${fmtBytes(s.totalStorage)}</div>
        <div class="stat-label">Artifact Storage</div>
      </div>
    </div>

    ${renderTopUsers(topUsers || [])}
    ${renderRecentRuns(recentRuns || [])}
  `;
}

function renderTopUsers(users) {
  if (!users.length) return '';
  const maxRuns = Math.max(...users.map((u) => u.runs), 1);
  return `
    <div class="card" style="margin-top:20px;">
      <div class="card-title">Top Users by Runs</div>
      <table class="analytics-table">
        <thead><tr>
          <th>User</th><th>Runs</th><th>Tokens</th><th>Storage</th><th>Activity</th>
        </tr></thead>
        <tbody>${users.map((u) => `
          <tr>
            <td><span class="user-avatar">${esc((u.display_name || u.username || '?')[0]).toUpperCase()}</span> ${esc(u.display_name || u.username)}</td>
            <td>${fmtNum(u.runs)}</td>
            <td>${fmtTokens(u.tokens)}</td>
            <td>${fmtBytes(u.storage)}</td>
            <td>
              <div class="mini-bar"><div class="mini-bar-fill" style="width:${Math.round((u.runs / maxRuns) * 100)}%"></div></div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

function renderRecentRuns(runs) {
  if (!runs.length) return '';
  return `
    <div class="card" style="margin-top:16px;">
      <div class="card-title">Recent Runs</div>
      <table class="analytics-table">
        <thead><tr>
          <th>User</th><th>Title</th><th>Status</th><th>Tokens</th><th>Started</th>
        </tr></thead>
        <tbody>${runs.map((r) => `
          <tr>
            <td>${esc(r.username)}</td>
            <td class="cell-truncate">${esc(r.title || '(untitled)')}</td>
            <td><span class="run-badge run-${esc(r.status)}">${esc(r.status)}</span></td>
            <td>${fmtTokens(r.total_tokens)}</td>
            <td>${fmtTime(r.created_at)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

// ── Shared number helpers (also used by other modules) ────────────────────

function fmtNum(n) {
  if (n == null) return '—';
  return Number(n).toLocaleString();
}

function fmtTokens(n) {
  if (!n) return '0';
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000)     return (n / 1_000).toFixed(1) + 'K';
  return String(n);
}

function fmtBytes(n) {
  if (!n) return '0 B';
  if (n >= 1_073_741_824) return (n / 1_073_741_824).toFixed(1) + ' GB';
  if (n >= 1_048_576)     return (n / 1_048_576).toFixed(1) + ' MB';
  if (n >= 1_024)         return (n / 1_024).toFixed(1) + ' KB';
  return n + ' B';
}
