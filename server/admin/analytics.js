'use strict';

// ── Analytics ─────────────────────────────────────────────────────────────

let _analyticsRange = 30;

function setAnalyticsRange(days, btn) {
  _analyticsRange = days;
  document.querySelectorAll('.range-btn').forEach((b) => b.classList.remove('active'));
  if (btn) btn.classList.add('active');
  loadAnalytics();
}

async function loadAnalytics() {
  const el = document.getElementById('analytics-content');
  if (!el) return;
  el.innerHTML = '<div class="empty"><span class="spinner"></span></div>';
  try {
    const data = await api(`/admin/api/analytics?range=${_analyticsRange}`).then((r) => r.json());
    renderAnalytics(el, data);
    setTs('analytics-ts', 'Updated');
  } catch (err) {
    if (err.message !== 'unauthorized') el.innerHTML = '<div class="empty">Failed to load analytics</div>';
  }
}

function renderAnalytics(el, { stats, runsByDay, usersByDay, modelBreakdown, statusBreakdown, topUsers, recentRuns }) {
  const s = stats || {};
  el.innerHTML = `
    ${renderStatGrid(s)}
    ${renderCharts(runsByDay || [], usersByDay || [], _analyticsRange)}
    ${renderBreakdowns(modelBreakdown || [], statusBreakdown || [])}
    ${renderTopUsers(topUsers || [])}
    ${renderRecentRuns(recentRuns || [])}
  `;
}

// ── Stat cards ─────────────────────────────────────────────────────────────

function renderStatGrid(s) {
  const cards = [
    { label: 'Total Users',     value: fmtNum(s.totalUsers),     sub: null },
    { label: 'Active Today',    value: fmtNum(s.activeToday),    sub: null },
    { label: 'New This Week',   value: fmtNum(s.newThisWeek),    sub: null },
    { label: 'Active Sessions', value: fmtNum(s.activeSessions), sub: null },
    { label: 'Total Runs',      value: fmtNum(s.totalRuns),      sub: null },
    { label: 'Runs Today',      value: fmtNum(s.runsToday),      sub: null },
    { label: 'Runs This Week',  value: fmtNum(s.runsThisWeek),   sub: null },
    { label: 'Success Rate',    value: (s.successRate ?? '—') + (s.successRate != null ? '%' : ''), sub: null },
    { label: 'Total Tokens',    value: fmtTokens(s.totalTokens), sub: null },
    { label: 'Tokens Today',    value: fmtTokens(s.tokensToday), sub: null },
    { label: 'Avg Tokens/Run',  value: fmtTokens(s.avgTokensPerRun), sub: null },
    { label: 'Artifact Storage',value: fmtBytes(s.totalStorage), sub: null },
  ];
  return `<div class="stat-grid">${cards.map((c) => `
    <div class="stat-card">
      <div class="stat-value">${c.value}</div>
      <div class="stat-label">${c.label}</div>
    </div>`).join('')}
  </div>`;
}

// ── SVG Charts ─────────────────────────────────────────────────────────────

function renderCharts(runsByDay, usersByDay, range) {
  return `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:20px;">
      <div class="card">
        <div class="card-title" style="margin-bottom:12px;">Runs per Day</div>
        ${buildBarChart(fillDates(runsByDay, range, 'runs'), 'runs', 'tokens')}
      </div>
      <div class="card">
        <div class="card-title" style="margin-bottom:12px;">Tokens per Day</div>
        ${buildAreaChart(fillDates(runsByDay, range, 'tokens'), 'tokens')}
      </div>
    </div>`;
}

function fillDates(data, range, _key) {
  const map = new Map((data || []).map((d) => [d.date, d]));
  const out = [];
  for (let i = range - 1; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86_400_000);
    const key = d.toISOString().slice(0, 10);
    out.push(map.get(key) || { date: key, runs: 0, tokens: 0 });
  }
  return out;
}

function buildBarChart(data, key, altKey) {
  const W = 560, H = 110, pad = { top: 8, bottom: 22, left: 4, right: 4 };
  const vals = data.map((d) => d[key] || 0);
  const max = Math.max(...vals, 1);
  const n = data.length;
  const gap = 2;
  const barW = Math.max(1, Math.floor((W - pad.left - pad.right - (n - 1) * gap) / n));
  const innerH = H - pad.top - pad.bottom;

  const accentColor = 'var(--accent)';
  const mutedColor = 'rgba(126,210,126,0.18)';

  const bars = data.map((d, i) => {
    const v = d[key] || 0;
    const bh = v === 0 ? 1 : Math.max(2, Math.round((v / max) * innerH));
    const x = pad.left + i * (barW + gap);
    const y = pad.top + innerH - bh;
    const altV = altKey ? (d[altKey] || 0) : 0;
    const label = altKey ? `${d.date}\n${key}: ${fmtNum(v)}\n${altKey}: ${fmtTokens(altV)}` : `${d.date}: ${fmtNum(v)}`;
    return `<rect x="${x}" y="${y}" width="${barW}" height="${bh}"
      fill="${v > 0 ? accentColor : mutedColor}" rx="1">
      <title>${esc(label)}</title></rect>`;
  });

  // X-axis date labels — only first, middle, last
  const labelIdxs = [0, Math.floor(n / 2), n - 1];
  const labels = labelIdxs.map((i) => {
    const x = pad.left + i * (barW + gap) + barW / 2;
    const y = H - 4;
    return `<text x="${x}" y="${y}" text-anchor="middle" font-size="9" fill="var(--text-muted)">${esc(data[i]?.date?.slice(5) || '')}</text>`;
  });

  return `<svg viewBox="0 0 ${W} ${H}" style="width:100%;height:${H}px;display:block;">${bars.join('')}${labels.join('')}</svg>`;
}

function buildAreaChart(data, key) {
  const W = 560, H = 110, pad = { top: 8, bottom: 22, left: 4, right: 4 };
  const vals = data.map((d) => d[key] || 0);
  const max = Math.max(...vals, 1);
  const n = data.length;
  const innerW = W - pad.left - pad.right;
  const innerH = H - pad.top - pad.bottom;

  const pts = data.map((d, i) => {
    const x = pad.left + (n <= 1 ? innerW / 2 : (i / (n - 1)) * innerW);
    const v = d[key] || 0;
    const y = pad.top + innerH - Math.max(0, (v / max) * innerH);
    return [x, y, d.date, v];
  });

  if (!pts.length) return `<svg viewBox="0 0 ${W} ${H}" style="width:100%;height:${H}px;display:block;"></svg>`;

  const linePts = pts.map(([x, y]) => `${x},${y}`).join(' ');
  const bottomY = pad.top + innerH;
  const areaPath = `M ${pts[0][0]},${bottomY} L ${pts.map(([x, y]) => `${x},${y}`).join(' L ')} L ${pts[pts.length - 1][0]},${bottomY} Z`;

  const dots = pts.map(([x, y, date, v]) =>
    `<circle cx="${x}" cy="${y}" r="2.5" fill="var(--accent)" opacity="0.85">
      <title>${esc(date)}: ${fmtTokens(v)}</title>
    </circle>`);

  const labelIdxs = [0, Math.floor(n / 2), n - 1];
  const labels = labelIdxs.map((i) => {
    const [x, , date] = pts[i] || [];
    if (x == null) return '';
    return `<text x="${x}" y="${H - 4}" text-anchor="middle" font-size="9" fill="var(--text-muted)">${esc((date || '').slice(5))}</text>`;
  });

  return `<svg viewBox="0 0 ${W} ${H}" style="width:100%;height:${H}px;display:block;">
    <defs>
      <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="var(--accent)" stop-opacity="0.28"/>
        <stop offset="100%" stop-color="var(--accent)" stop-opacity="0.03"/>
      </linearGradient>
    </defs>
    <path d="${areaPath}" fill="url(#areaGrad)"/>
    <polyline points="${linePts}" fill="none" stroke="var(--accent)" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
    ${dots.join('')}
    ${labels.join('')}
  </svg>`;
}

// ── Breakdowns ─────────────────────────────────────────────────────────────

function renderBreakdowns(modelBreakdown, statusBreakdown) {
  return `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:16px;">
      ${renderModelBreakdown(modelBreakdown)}
      ${renderStatusBreakdown(statusBreakdown)}
    </div>`;
}

function renderModelBreakdown(models) {
  if (!models.length) return '<div class="card"><div class="card-title">Model Usage</div><div class="empty" style="padding:20px 0;">No data</div></div>';
  const maxRuns = Math.max(...models.map((m) => m.runs), 1);
  return `
    <div class="card">
      <div class="card-title" style="margin-bottom:12px;">Model Usage (selected period)</div>
      <table class="analytics-table">
        <thead><tr><th>Model</th><th style="text-align:right;">Runs</th><th style="text-align:right;">Tokens</th><th style="width:80px;"></th></tr></thead>
        <tbody>${models.map((m) => `
          <tr>
            <td style="font-family:var(--font-mono);font-size:11px;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${esc(m.model)}</td>
            <td style="text-align:right;">${fmtNum(m.runs)}</td>
            <td style="text-align:right;">${fmtTokens(m.tokens)}</td>
            <td><div class="mini-bar"><div class="mini-bar-fill" style="width:${Math.round((m.runs / maxRuns) * 100)}%"></div></div></td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

const STATUS_COLORS = {
  completed: 'var(--success)',
  error:     'var(--danger)',
  running:   'var(--accent)',
  pending:   'var(--text-muted)',
};

function renderStatusBreakdown(statuses) {
  if (!statuses.length) return '<div class="card"><div class="card-title">Run Status</div><div class="empty" style="padding:20px 0;">No data</div></div>';
  const total = statuses.reduce((a, s) => a + s.count, 0);
  const pills = statuses.map((s) => {
    const pct = total > 0 ? Math.round((s.count / total) * 100) : 0;
    const color = STATUS_COLORS[s.status] || 'var(--text-muted)';
    return `<div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border);">
      <div style="display:flex;align-items:center;gap:10px;">
        <div style="width:10px;height:10px;border-radius:50%;background:${color};flex-shrink:0;"></div>
        <span style="font-size:13px;text-transform:capitalize;">${esc(s.status)}</span>
      </div>
      <div style="display:flex;align-items:center;gap:12px;">
        <span style="font-family:var(--font-mono);font-size:13px;font-weight:600;">${fmtNum(s.count)}</span>
        <span style="font-size:11px;color:var(--text-muted);width:34px;text-align:right;">${pct}%</span>
      </div>
    </div>`;
  });

  // Mini donut from status percentages using SVG
  const donut = buildDonut(statuses, total);

  return `
    <div class="card">
      <div class="card-title" style="margin-bottom:12px;">Run Status (all time)</div>
      <div style="display:flex;gap:20px;align-items:flex-start;">
        <div style="flex:1;">${pills.join('')}</div>
        <div style="flex-shrink:0;margin-top:4px;">${donut}</div>
      </div>
    </div>`;
}

function buildDonut(statuses, total) {
  const R = 36, cx = 44, cy = 44, strokeW = 12;
  const circum = 2 * Math.PI * R;
  let offset = 0;
  const slices = statuses.map((s) => {
    const pct = total > 0 ? s.count / total : 0;
    const dash = pct * circum;
    const gap  = circum - dash;
    const color = STATUS_COLORS[s.status] || 'var(--text-muted)';
    const slice = `<circle cx="${cx}" cy="${cy}" r="${R}" fill="none"
      stroke="${color}" stroke-width="${strokeW}"
      stroke-dasharray="${dash} ${gap}"
      stroke-dashoffset="${-offset}"
      transform="rotate(-90 ${cx} ${cy})"/>`;
    offset += dash;
    return slice;
  });
  return `<svg width="88" height="88" viewBox="0 0 88 88">
    <circle cx="${cx}" cy="${cy}" r="${R}" fill="none" stroke="var(--border)" stroke-width="${strokeW}"/>
    ${slices.join('')}
  </svg>`;
}

// ── Top Users ───────────────────────────────────────────────────────────────

function renderTopUsers(users) {
  if (!users.length) return '';
  const maxTokens = Math.max(...users.map((u) => u.tokens), 1);
  return `
    <div class="card" style="margin-top:16px;">
      <div class="card-title" style="margin-bottom:12px;">Top Users by Token Usage</div>
      <table class="analytics-table">
        <thead><tr>
          <th>User</th><th style="text-align:right;">Runs</th><th style="text-align:right;">Tokens</th><th style="text-align:right;">Storage</th><th style="width:100px;"></th>
        </tr></thead>
        <tbody>${users.map((u) => `
          <tr>
            <td><span class="user-avatar">${esc((u.display_name || u.username || '?')[0]).toUpperCase()}</span> ${esc(u.display_name || u.username)}</td>
            <td style="text-align:right;">${fmtNum(u.runs)}</td>
            <td style="text-align:right;">${fmtTokens(u.tokens)}</td>
            <td style="text-align:right;">${fmtBytes(u.storage)}</td>
            <td><div class="mini-bar"><div class="mini-bar-fill" style="width:${Math.round((u.tokens / maxTokens) * 100)}%"></div></div></td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

// ── Recent Runs ─────────────────────────────────────────────────────────────

function renderRecentRuns(runs) {
  if (!runs.length) return '';
  return `
    <div class="card" style="margin-top:16px;">
      <div class="card-title" style="margin-bottom:12px;">Recent Runs</div>
      <table class="analytics-table">
        <thead><tr>
          <th>User</th><th>Title</th><th>Model</th><th>Status</th><th style="text-align:right;">Tokens</th><th>Started</th>
        </tr></thead>
        <tbody>${runs.map((r) => `
          <tr>
            <td>${esc(r.username)}</td>
            <td class="cell-truncate">${esc(r.title || '(untitled)')}</td>
            <td style="font-family:var(--font-mono);font-size:11px;color:var(--text-muted);">${esc(r.model || '—')}</td>
            <td><span class="run-badge run-${esc(r.status)}">${esc(r.status)}</span></td>
            <td style="text-align:right;">${fmtTokens(r.total_tokens)}</td>
            <td>${fmtTime(r.created_at)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>`;
}

// ── Shared number helpers ──────────────────────────────────────────────────

function fmtNum(n) {
  if (n == null) return '—';
  return Number(n).toLocaleString();
}

function fmtTokens(n) {
  if (!n) return '0';
  if (n >= 1_000_000_000) return (n / 1_000_000_000).toFixed(1) + 'B';
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
