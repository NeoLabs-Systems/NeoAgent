'use strict';

// ── SQL Editor ─────────────────────────────────────────────────────────────

const SQL_TEMPLATES = [
  { label: '— Select a template —', query: '' },
  { label: 'User summary',            query: `SELECT u.id, u.username, u.email,\n       u.created_at, u.last_login,\n       COUNT(DISTINCT r.id) AS runs,\n       COALESCE(SUM(r.total_tokens),0) AS tokens\nFROM users u\nLEFT JOIN agent_runs r ON r.user_id = u.id\nGROUP BY u.id\nORDER BY runs DESC\nLIMIT 50` },
  { label: 'Recent failed runs',       query: `SELECT r.id, u.username, r.title, r.status,\n       r.error, r.created_at\nFROM agent_runs r\nJOIN users u ON u.id = r.user_id\nWHERE r.status = 'failed'\nORDER BY r.created_at DESC\nLIMIT 50` },
  { label: 'Artifact storage by user', query: `SELECT u.username,\n       COUNT(a.id) AS files,\n       SUM(a.byte_size) AS bytes,\n       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\nFROM users u\nLEFT JOIN artifacts a ON a.user_id = u.id\nGROUP BY u.id\nORDER BY bytes DESC` },
  { label: 'Active sessions',          query: `SELECT u.username, s.ip_address,\n       s.user_agent, s.created_at, s.last_seen_at\nFROM user_sessions s\nJOIN users u ON u.id = s.user_id\nWHERE s.revoked_at IS NULL\n  AND s.expires_at > datetime('now')\nORDER BY s.last_seen_at DESC\nLIMIT 50` },
  { label: 'Runs per day (30 days)',   query: `SELECT DATE(created_at) AS day,\n       COUNT(*) AS runs,\n       COALESCE(SUM(total_tokens),0) AS tokens\nFROM agent_runs\nWHERE created_at >= datetime('now', '-30 days')\nGROUP BY day\nORDER BY day DESC` },
  { label: 'Most used agents',         query: `SELECT a.slug, a.display_name, u.username AS owner,\n       COUNT(r.id) AS runs\nFROM agents a\nJOIN users u ON u.id = a.user_id\nLEFT JOIN agent_runs r ON r.agent_id = a.id\nGROUP BY a.id\nORDER BY runs DESC\nLIMIT 20` },
  { label: 'Integration connections',  query: `SELECT u.username, ic.provider_key,\n       ic.status, ic.account_email, ic.last_connected_at\nFROM integration_connections ic\nJOIN users u ON u.id = ic.user_id\nORDER BY ic.last_connected_at DESC\nLIMIT 50` },
  { label: 'All tables',               query: `SELECT name FROM sqlite_master WHERE type='table' ORDER BY name` },
  { label: 'Table info (users)',        query: `SELECT * FROM pragma_table_info('users')` },
];

function loadSql() {
  // Only initialize the editor once
  if (document.getElementById('sql-editor')?.dataset.ready === '1') return;
  initSqlEditor();
}

function initSqlEditor() {
  const el = document.getElementById('sql-content');
  if (!el) return;

  const templateOptions = SQL_TEMPLATES.map((t, i) =>
    `<option value="${i}">${esc(t.label)}</option>`).join('');

  el.innerHTML = `
    <div class="sql-toolbar">
      <select id="sql-template" onchange="onSqlTemplate(this)" style="width:auto;min-width:220px;" aria-label="Query template">
        ${templateOptions}
      </select>
      <span class="spacer"></span>
      <button class="btn btn-primary" id="sql-run-btn" onclick="runSql()" style="padding:7px 16px;">
        <svg viewBox="0 0 20 20" fill="currentColor" style="width:13px;height:13px;" aria-hidden="true">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>
        </svg>
        Run
      </button>
    </div>
    <textarea id="sql-editor" data-ready="1" class="sql-textarea" spellcheck="false" autocorrect="off" autocapitalize="off"
      placeholder="SELECT * FROM users LIMIT 10"
      onkeydown="onSqlKeydown(event)"
      aria-label="SQL query editor"
    ></textarea>
    <div id="sql-results"></div>`;
}

function onSqlTemplate(sel) {
  const idx = parseInt(sel.value, 10);
  const q = SQL_TEMPLATES[idx]?.query || '';
  const editor = document.getElementById('sql-editor');
  if (editor && q) { editor.value = q; editor.focus(); }
}

function onSqlKeydown(e) {
  // Ctrl+Enter / Cmd+Enter to run
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    runSql();
  }
  // Tab → insert 2 spaces
  if (e.key === 'Tab') {
    e.preventDefault();
    const ta = e.target;
    const s = ta.selectionStart, end = ta.selectionEnd;
    ta.value = ta.value.slice(0, s) + '  ' + ta.value.slice(end);
    ta.selectionStart = ta.selectionEnd = s + 2;
  }
}

async function runSql() {
  const query = document.getElementById('sql-editor')?.value?.trim();
  if (!query) return;
  const resultsEl = document.getElementById('sql-results');
  const runBtn    = document.getElementById('sql-run-btn');
  if (!resultsEl || !runBtn) return;

  runBtn.disabled = true;
  resultsEl.innerHTML = '<div class="empty"><span class="spinner"></span></div>';

  try {
    const res = await api('/admin/api/sql', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    });
    const data = await res.json();

    if (!res.ok) {
      resultsEl.innerHTML = `<div class="sql-error">${esc(data.error || 'Query failed')}</div>`;
      return;
    }

    if (!data.rows?.length) {
      resultsEl.innerHTML = '<div class="empty">Query returned 0 rows</div>';
      return;
    }

    resultsEl.innerHTML = `
      <div class="sql-meta">
        ${fmtNum(data.rows.length)}${data.truncated ? ` of ${fmtNum(data.total)}` : ''} row${data.rows.length === 1 ? '' : 's'}
        ${data.truncated ? '<span class="badge badge-warn" style="margin-left:6px;">truncated at 500</span>' : ''}
        <button class="btn btn-ghost" style="margin-left:auto;padding:4px 10px;font-size:11px;" onclick="copySqlResults()">Copy CSV</button>
      </div>
      <div class="sql-result-wrap">
        <table class="sql-result-table">
          <thead><tr>${data.columns.map((c) => `<th>${esc(c)}</th>`).join('')}</tr></thead>
          <tbody>${data.rows.map((row) =>
            `<tr>${data.columns.map((c) => `<td>${esc(row[c] == null ? 'NULL' : String(row[c]))}</td>`).join('')}</tr>`
          ).join('')}</tbody>
        </table>
      </div>`;
    // stash for copy
    window._lastSqlData = data;
  } catch (err) {
    if (err.message !== 'unauthorized') {
      resultsEl.innerHTML = `<div class="sql-error">Network error</div>`;
    }
  } finally {
    runBtn.disabled = false;
  }
}

function copySqlResults() {
  const d = window._lastSqlData;
  if (!d) return;
  const header = d.columns.join(',');
  const rows   = d.rows.map((r) => d.columns.map((c) => JSON.stringify(r[c] ?? '')).join(','));
  navigator.clipboard.writeText([header, ...rows].join('\n')).catch(() => {});
}
