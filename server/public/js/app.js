// ── NeoAgent App ──

const socket = io();
let isStreaming = false;
const backgroundRunIds = new Set(); // tracks scheduler/heartbeat run IDs

// ── Utility ──

function $(sel) { return document.querySelector(sel); }
function $$(sel) { return document.querySelectorAll(sel); }

function toast(message, type = 'info') {
  const container = $('#toasts');
  const el = document.createElement('div');
  el.className = `toast toast-${type}`;
  el.textContent = message;
  container.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

async function api(path, opts = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { 'Content-Type': 'application/json', ...opts.headers },
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function formatTime(ts) {
  return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

// ── Navigation ──

function navigateTo(page) {
  $$('.page').forEach(p => p.classList.remove('active'));
  $$('.sidebar-btn').forEach(b => b.classList.remove('active'));

  const pageEl = $(`#page-${page}`);
  if (pageEl) {
    pageEl.classList.add('active');
    const btn = $(`.sidebar-btn[data-page="${page}"]`);
    if (btn) btn.classList.add('active');
  }

  if (page === 'memory') loadMemoryPage();
  if (page === 'skills') loadSkillsPage();
  if (page === 'mcp') loadMCPPage();
  if (page === 'scheduler') loadSchedulerPage();
  if (page === 'messaging') loadMessagingPage();
  if (page === 'protocols') loadProtocolsPage();
  if (page === 'activity') requestAnimationFrame(ensureTimeline);
}

$$('.sidebar-btn[data-page]').forEach(btn => {
  btn.addEventListener('click', () => navigateTo(btn.dataset.page));
});

// ── Chat ──

const chatInput = $('#chatInput');
const chatMessages = $('#chatMessages');
const chatEmpty = $('#chatEmpty');
const sendBtn = $('#chatSendBtn');

chatInput.addEventListener('input', () => {
  chatInput.style.height = 'auto';
  chatInput.style.height = Math.min(chatInput.scrollHeight, 200) + 'px';
});

chatInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});

sendBtn.addEventListener('click', sendMessage);

function sendMessage() {
  const text = chatInput.value.trim();
  if (!text || isStreaming) return;

  chatEmpty.classList.add('hidden');
  appendMessage('user', text);
  chatInput.value = '';
  chatInput.style.height = 'auto';

  isStreaming = true;
  sendBtn.disabled = true;

  const thinkingEl = document.createElement('div');
  thinkingEl.className = 'chat-thinking';
  thinkingEl.id = 'thinking';
  thinkingEl.innerHTML = '<div class="spinner"></div><span id="thinkingText">NeoAgent is thinking...</span>';
  chatMessages.appendChild(thinkingEl);
  chatMessages.scrollTop = chatMessages.scrollHeight;

  // Reset activity for new run
  clearActivity();

  socket.emit('agent:run', { task: text });
}

function appendMessage(role, content) {
  const div = document.createElement('div');
  div.className = `chat-message ${role}`;

  const avatar = document.createElement('div');
  avatar.className = 'chat-avatar';
  avatar.textContent = role === 'user' ? 'U' : 'N';

  const bubble = document.createElement('div');
  bubble.className = 'chat-bubble md-content';
  bubble.innerHTML = renderMarkdown(content);

  div.appendChild(avatar);
  div.appendChild(bubble);
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
  return bubble;
}

function appendToolCall(name, args, result) {
  const div = document.createElement('div');
  div.className = 'chat-message assistant';
  const avatar = document.createElement('div');
  avatar.className = 'chat-avatar';
  avatar.textContent = 'N';
  const bubble = document.createElement('div');
  bubble.className = 'chat-bubble';
  bubble.innerHTML = `<div class="chat-tool-call"><div class="tool-name">${escapeHtml(name)}</div>${args ? `<div class="tool-result">${escapeHtml(typeof args === 'string' ? args : JSON.stringify(args, null, 2)).slice(0, 500)}</div>` : ''}${result ? `<div class="tool-result" style="border-top:1px solid var(--border);padding-top:6px;margin-top:6px;">${escapeHtml(typeof result === 'string' ? result : JSON.stringify(result, null, 2)).slice(0, 1000)}</div>` : ''}</div>`;
  div.appendChild(avatar);
  div.appendChild(bubble);
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Status update (interim message from AI mid-task)
function appendInterimMessage(message) {
  const div = document.createElement('div');
  div.className = 'chat-interim';
  div.innerHTML = `<div class="chat-interim-dot"></div><div class="chat-interim-text">${escapeHtml(message)}</div>`;
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Show a social platform message (WhatsApp etc.) in chat
function appendSocialMessage(platform, role, content, senderName) {
  const div = document.createElement('div');
  div.className = role === 'user' ? 'chat-message social' : 'chat-message assistant';
  const avatar = document.createElement('div');
  avatar.className = 'chat-avatar';
  avatar.textContent = platform === 'whatsapp' ? '💬' : platform[0].toUpperCase();
  if (role === 'user') avatar.style.cssText = 'background:#25d36620;color:#25d366;font-size:12px;';
  const bubble = document.createElement('div');
  bubble.className = 'chat-bubble';
  const badge = `<div class="chat-platform-badge ${platform.toLowerCase()}">${platform}</div>`;
  const sender = (role === 'user' && senderName) ? `<div class="chat-sender">${escapeHtml(senderName)}</div>` : '';
  bubble.innerHTML = badge + sender + renderMarkdown(content);
  div.appendChild(avatar);
  div.appendChild(bubble);
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Load and render chat history from DB
async function loadChatHistory() {
  try {
    const data = await api('/agents/chat-history?limit=80');
    if (!data.messages || data.messages.length === 0) return;
    chatEmpty.classList.add('hidden');
    for (const msg of data.messages) {
      if (!msg.content) continue;
      if (msg.platform === 'web') {
        appendMessage(msg.role, msg.content);
      } else {
        appendSocialMessage(msg.platform, msg.role, msg.content, msg.sender_name);
      }
    }
  } catch { /* silently skip */ }
}

// Load history on startup
loadChatHistory();

// Simple markdown renderer
function renderMarkdown(text) {
  if (!text) return '';
  let html = escapeHtml(text);
  // Code blocks
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code>$2</code></pre>');
  // Inline code
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  // Bold
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  // Italic
  html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
  // Headers
  html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');
  // Lists
  html = html.replace(/^- (.+)$/gm, '<li>$1</li>');
  html = html.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');
  // Links
  html = html.replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2" target="_blank">$1</a>');
  // Line breaks
  html = html.replace(/\n/g, '<br>');
  return html;
}

// ── Activity Helpers ──

const TOOL_META = {
  execute_command:    { icon: '⚡', label: 'Terminal',      color: 'cli'       },
  browser_navigate:   { icon: '🌐', label: 'Browse',        color: 'browser'   },
  browser_click:      { icon: '🖱️', label: 'Click',         color: 'browser'   },
  browser_type:       { icon: '⌨️', label: 'Type',          color: 'browser'   },
  browser_extract:    { icon: '📋', label: 'Extract',       color: 'browser'   },
  browser_screenshot: { icon: '📷', label: 'Screenshot',    color: 'browser'   },
  browser_evaluate:   { icon: '⚙️', label: 'Script',        color: 'browser'   },
  memory_write:       { icon: '🧠', label: 'Memory Write',  color: 'memory'    },
  memory_read:        { icon: '🧠', label: 'Memory Read',   color: 'memory'    },
  memory_save:        { icon: '🧠', label: 'Save Memory',   color: 'memory'    },
  memory_recall:      { icon: '🔍', label: 'Recall Memory', color: 'memory'    },
  memory_update_core: { icon: '📌', label: 'Core Memory',   color: 'memory'    },
  think:              { icon: '💭', label: 'Thinking',      color: 'thinking'  },
  send_message:       { icon: '💬', label: 'Message',       color: 'messaging' },
  make_call:          { icon: '📞', label: 'Call',           color: 'messaging' },
  http_request:       { icon: '🔗', label: 'HTTP Request',  color: 'http'      },
  read_file:          { icon: '📄', label: 'Read File',     color: 'file'      },
  write_file:         { icon: '📝', label: 'Write File',    color: 'file'      },
  list_directory:     { icon: '📁', label: 'List Dir',      color: 'file'      },
  spawn_subagent:     { icon: '🤖', label: 'Sub-Agent',     color: 'agent'     },
};

function getToolMeta(name) {
  return TOOL_META[name] || { icon: '🔧', label: name, color: 'tool' };
}

function describeArgs(toolName, args) {
  if (!args) return null;
  switch (toolName) {
    case 'execute_command':   return { headline: args.command, detail: args.cwd ? `Dir: ${args.cwd}` : null };
    case 'browser_navigate':  return { headline: args.url };
    case 'browser_click':     return { headline: args.text ? `"${args.text}"` : (args.selector || 'element') };
    case 'browser_type':      return { headline: `"${args.text}"`, detail: `into ${args.selector}` };
    case 'browser_screenshot':return { headline: args.selector ? `Element: ${args.selector}` : 'Full page' };
    case 'browser_extract':   return { headline: args.selector || 'Page content' };
    case 'browser_evaluate':  return { headline: args.script?.slice(0, 120) };
    case 'memory_write':      return { headline: `→ ${args.target}`, detail: args.content?.slice(0, 160) };
    case 'memory_read':       return { headline: `← ${args.target}`, detail: args.search ? `Search: "${args.search}"` : null };
    case 'memory_save':       return { headline: args.content?.slice(0, 200), detail: `${args.category || 'episodic'} · importance ${args.importance || 5}` };
    case 'memory_recall':     return { headline: `"${args.query}"`, detail: args.limit ? `top ${args.limit}` : null };
    case 'memory_update_core':return { headline: `${args.key} → ${String(args.value || '').slice(0, 100)}` };
    case 'think':             return { headline: args.thought?.slice(0, 400) };
    case 'http_request':      return { headline: `${args.method || 'GET'} ${args.url}` };
    case 'send_message':      return { headline: args.content?.slice(0, 160), detail: `${args.platform} → ${args.to}` };
    case 'make_call':         return { headline: `Calling ${args.to}`, detail: args.greeting?.slice(0, 100) };
    case 'read_file':         return { headline: args.path };
    case 'write_file':        return { headline: args.path, detail: `${(args.content || '').length} chars` };
    case 'list_directory':    return { headline: args.path };
    case 'spawn_subagent':    return { headline: args.task?.slice(0, 200) };
    default: {
      const first = Object.values(args).find(v => typeof v === 'string');
      return first ? { headline: first.slice(0, 160) } : null;
    }
  }
}

function describeResult(toolName, result) {
  if (!result) return null;
  if (result.error) return { type: 'error', text: result.error };
  switch (toolName) {
    case 'execute_command': {
      const out = (result.stdout || result.output || result.stderr || '').trim();
      const code = result.exitCode ?? result.exit_code;
      return { type: (code === 0 || code == null) ? 'code' : 'error', text: out.slice(0, 600) || '(no output)', meta: code != null ? `Exit ${code}` : null };
    }
    case 'browser_navigate':
    case 'browser_click':
    case 'browser_type':
    case 'browser_screenshot':
    case 'browser_evaluate':
      return { type: 'screenshot', meta: result.title || null };
    case 'memory_write':  return { type: 'success', text: 'Saved ✓' };
    case 'memory_read': {
      const txt = typeof result === 'string' ? result : (result.content || JSON.stringify(result));
      return { type: 'output', text: txt.slice(0, 400) };
    }
    case 'memory_save':        return { type: 'success', text: 'Saved to memory ✓' };
    case 'memory_update_core': return { type: 'success', text: 'Core memory updated ✓' };
    case 'memory_recall': {
      const results = result?.results || [];
      if (!results.length) return { type: 'output', text: 'Nothing found' };
      const preview = results.slice(0, 3).map(r => `• ${r.content}`).join('\n');
      return { type: 'output', text: preview };
    }
    case 'think': return null;
    case 'http_request': {
      const s = result.status;
      const cls = s >= 200 && s < 300 ? 'ok' : s >= 400 ? 'err' : 'warn';
      return { type: 'output', text: (result.body || '').slice(0, 400), meta: `HTTP ${s}`, statusClass: cls };
    }
    case 'read_file':
      return { type: 'code', text: (result.content || '').slice(0, 400) };
    case 'write_file':
      return { type: 'success', text: 'File written ✓' };
    case 'list_directory': {
      const items = (result.entries || []).slice(0, 20).map(e => e.name || e).join('\n');
      return { type: 'code', text: items };
    }
    default: {
      const txt = typeof result === 'string' ? result : JSON.stringify(result, null, 2);
      return { type: 'output', text: txt.slice(0, 400) };
    }
  }
}

// ── Activity Timeline ──

class ActivityTimeline {
  constructor(feedEl) {
    this.feed = feedEl;
    this.steps = new Map(); // stepId → { el, cardEl }
    this.runHeaderEl = null;
    this.runStartTs = null;
    this.timerInterval = null;
    this.stepCount = 0;
  }

  // Start a new run header (called on run:start)
  startRun(title, model) {
    this._clearEmpty();
    this.runStartTs = Date.now();

    const el = document.createElement('div');
    el.className = 'atl-run-header';
    el.innerHTML = `
      <span class="atl-run-title">${escapeHtml(title || 'Running…')}</span>
      <div class="atl-run-badges">
        <span class="atl-run-timer" id="atlTimer">0s</span>
        ${model ? `<span class="atl-run-model">${escapeHtml(model)}</span>` : ''}
        <span class="atl-run-badge running" id="atlRunStatus">running</span>
      </div>`;
    this.feed.prepend(el);
    this.runHeaderEl = el;

    this.timerInterval = setInterval(() => {
      const el = document.getElementById('atlTimer');
      if (!el) return;
      const s = Math.round((Date.now() - this.runStartTs) / 1000);
      el.textContent = s < 60 ? `${s}s` : `${Math.floor(s/60)}m ${s%60}s`;
    }, 1000);
  }

  finishRun(status) {
    clearInterval(this.timerInterval);
    const badge = document.getElementById('atlRunStatus');
    if (badge) {
      badge.className = `atl-run-badge ${status}`;
      badge.textContent = status;
    }
    // Collapse all completed non-response steps
    for (const [, info] of this.steps) {
      if (!info.isResponse && info.cardEl && info.cardEl.classList.contains('open')) {
        const hadError = info.cardEl.querySelector('.atl-text.error');
        if (!hadError) info.cardEl.classList.remove('open');
      }
    }
  }

  addNode(stepId, toolName, toolArgs) {
    this._clearEmpty();
    const meta = getToolMeta(toolName);
    const desc = describeArgs(toolName, toolArgs);

    const stepEl = document.createElement('div');
    stepEl.className = `atl-step running`;
    stepEl.dataset.color = meta.color;
    stepEl.id = `atl-step-${stepId}`;

    const summaryText = desc?.headline ? escapeHtml(desc.headline.slice(0, 120)) : escapeHtml(meta.label);

    let urlChip = '';
    if ((toolName === 'browser_navigate') && toolArgs?.url) {
      const u = toolArgs.url;
      urlChip = `<a class="atl-url-chip" href="${escapeHtml(u)}" target="_blank" rel="noopener noreferrer">${escapeHtml(u.length > 80 ? u.slice(0,80)+'…' : u)}</a>`;
    }

    stepEl.innerHTML = `
      <div class="atl-spine">
        <div class="atl-dot">${meta.icon}</div>
        <div class="atl-connector"></div>
      </div>
      <div class="atl-card open" id="atl-card-${stepId}">
        <div class="atl-card-head" data-step="${stepId}">
          <span class="atl-card-label">${escapeHtml(meta.label)}</span>
          <span class="atl-card-summary">${summaryText}</span>
          <span class="atl-status-chip running" id="atl-chip-${stepId}">running</span>
          <span class="atl-toggle">▾</span>
        </div>
        <div class="atl-card-body">
          ${desc?.headline ? `<div class="atl-cmd">${escapeHtml(desc.headline)}</div>` : ''}
          ${desc?.detail   ? `<div class="atl-detail">${escapeHtml(desc.detail)}</div>` : ''}
          ${urlChip}
          <div id="atl-result-${stepId}"></div>
        </div>
      </div>`;

    this.feed.appendChild(stepEl);
    this.steps.set(stepId, { el: stepEl, cardEl: stepEl.querySelector(`#atl-card-${stepId}`), isResponse: false });
    this.stepCount++;

    // Toggle open/close on header click
    stepEl.querySelector('.atl-card-head').addEventListener('click', () => {
      stepEl.querySelector(`#atl-card-${stepId}`).classList.toggle('open');
    });

    stepEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    return stepEl;
  }

  updateNode(stepId, toolName, result, screenshotPath, status) {
    const info = this.steps.get(stepId);
    if (!info) return;

    const chip = document.getElementById(`atl-chip-${stepId}`);
    if (chip) {
      chip.className = `atl-status-chip ${status}`;
      chip.textContent = status === 'completed' ? 'done' : 'failed';
    }

    info.el.classList.remove('running');
    if (status === 'failed') info.el.dataset.color = 'tool';

    const resultEl = document.getElementById(`atl-result-${stepId}`);
    if (!resultEl) return;

    // Screenshot
    if (screenshotPath) {
      const wrap = document.createElement('div');
      wrap.className = 'atl-screenshot-wrap';
      const a = document.createElement('a');
      a.href = screenshotPath; a.target = '_blank'; a.rel = 'noopener noreferrer';
      const img = document.createElement('img');
      img.className = 'atl-screenshot';
      img.src = screenshotPath; img.alt = ''; img.loading = 'lazy';
      a.appendChild(img); wrap.appendChild(a);
      resultEl.appendChild(wrap);
    }

    const rd = describeResult(toolName, result);
    if (rd) {
      if (rd.meta) {
        const m = document.createElement('div');
        m.className = rd.statusClass ? `atl-http-badge ${rd.statusClass}` : `atl-result-label${rd.type === 'error' ? ' error' : ''}`;
        m.textContent = rd.meta;
        resultEl.appendChild(m);
      }
      if (rd.text) {
        const d = document.createElement('div');
        d.className = rd.type === 'code' ? 'atl-code' : rd.type === 'error' ? 'atl-text error' : rd.type === 'success' ? 'atl-success' : 'atl-text';
        d.textContent = rd.text;
        resultEl.appendChild(d);
      }
    }

    // Update summary with result snippet
    const summary = info.el.querySelector('.atl-card-summary');
    if (summary && rd?.text && rd.type !== 'error') {
      const snippet = rd.text.split('\n')[0].slice(0, 80);
      if (snippet) summary.textContent = snippet;
    }
  }

  addResponse(content) {
    if (!content) return;
    this._clearEmpty();

    const fakeId = `__resp_${Date.now()}`;
    const stepEl = document.createElement('div');
    stepEl.className = 'atl-step';
    stepEl.dataset.color = 'response';
    stepEl.id = `atl-step-${fakeId}`;
    stepEl.innerHTML = `
      <div class="atl-spine">
        <div class="atl-dot">✅</div>
      </div>
      <div class="atl-card open" id="atl-card-${fakeId}">
        <div class="atl-card-head" data-step="${fakeId}">
          <span class="atl-card-label">Response</span>
          <span class="atl-card-summary" style="font-style:italic;color:var(--text-muted);">final answer</span>
          <span class="atl-toggle">▾</span>
        </div>
        <div class="atl-card-body">
          <div class="atl-response-body md-content">${renderMarkdown(content)}</div>
        </div>
      </div>`;

    this.feed.appendChild(stepEl);
    this.steps.set(fakeId, { el: stepEl, cardEl: stepEl.querySelector(`#atl-card-${fakeId}`), isResponse: true });

    stepEl.querySelector('.atl-card-head').addEventListener('click', () => {
      stepEl.querySelector(`#atl-card-${fakeId}`).classList.toggle('open');
    });

    stepEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  _clearEmpty() {
    const e = document.getElementById('activityEmpty');
    if (e) e.style.display = 'none';
  }

  clear() {
    clearInterval(this.timerInterval);
    this.steps.clear();
    this.stepCount = 0;
    this.runHeaderEl = null;
    this.runStartTs = null;
    // Remove everything except the empty state placeholder
    const empty = document.getElementById('activityEmpty');
    this.feed.innerHTML = '';
    if (empty) { empty.style.display = ''; this.feed.appendChild(empty); }
  }
}

let activityTimeline = null;

function ensureTimeline() {
  if (activityTimeline) return;
  const feed = document.getElementById('activityFeed');
  if (!feed) return;
  activityTimeline = new ActivityTimeline(feed);
}

function addActivityNode(stepId, toolName, toolArgs) {
  ensureTimeline();
  activityTimeline.addNode(stepId, toolName, toolArgs);
  const badge = $('#activityBadge');
  if (badge) badge.classList.remove('hidden');
}

function updateActivityNode(stepId, toolName, result, screenshotPath, status) {
  if (activityTimeline) activityTimeline.updateNode(stepId, toolName, result, screenshotPath, status);
}

function addActivityResponse(content) {
  ensureTimeline();
  if (content) activityTimeline.addResponse(content);
}

function clearActivity() {
  if (activityTimeline) activityTimeline.clear();
  else {
    const empty = $('#activityEmpty');
    if (empty) empty.style.display = '';
  }
  const badge = $('#activityBadge');
  if (badge) badge.classList.add('hidden');
}

$('#clearActivityBtn').addEventListener('click', clearActivity);

// ── Activity History Panel ──

$('#historyToggleBtn').addEventListener('click', () => {
  const panel = $('#activityHistoryPanel');
  panel.classList.toggle('hidden');
  if (!panel.classList.contains('hidden')) loadActivityHistory();
});

$('#historyCloseBtn').addEventListener('click', () => {
  $('#activityHistoryPanel').classList.add('hidden');
});

async function loadActivityHistory() {
  const list = $('#activityHistoryList');
  list.innerHTML = '<div class="ahp-empty">Loading…</div>';
  try {
    const data = await api('/agents?limit=30');
    if (!data.runs || data.runs.length === 0) {
      list.innerHTML = '<div class="ahp-empty">No past runs</div>';
      return;
    }
    list.innerHTML = '';
    for (const run of data.runs) {
      const card = document.createElement('div');
      card.className = 'ahp-run-card';
      card.dataset.runId = run.id;
      const d = new Date(run.created_at);
      const dateStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      card.innerHTML = `<div class="ahp-run-title">${escapeHtml(run.title || 'Untitled')}</div><div class="ahp-run-meta"><span class="ahp-run-status ${run.status}">${run.status}</span><span>${dateStr}</span></div>`;
      card.addEventListener('click', () => {
        $$('.ahp-run-card.active').forEach(c => c.classList.remove('active'));
        card.classList.add('active');
        loadRunOnCanvas(run.id);
      });
      list.appendChild(card);
    }
  } catch { list.innerHTML = '<div class="ahp-empty">Failed to load</div>'; }
}

async function loadRunOnCanvas(runId) {
  try {
    const data = await api(`/agents/${runId}/steps`);
    clearActivity();
    ensureTimeline();
    activityTimeline?.startRun(`Run ${runId}`, data.model || '');
    for (const step of (data.steps || [])) {
      let toolInput = {};
      let result = null;
      try { toolInput = step.tool_input ? JSON.parse(step.tool_input) : {}; } catch {}
      try { result = step.result ? JSON.parse(step.result) : null; } catch {}
      activityTimeline.addNode(step.id, step.tool_name, toolInput);
      activityTimeline.updateNode(step.id, step.tool_name, result, step.screenshot_path || null, step.status);
    }
    if (data.response) activityTimeline.addResponse(data.response);
    activityTimeline?.finishRun(data.status || 'completed');
    const badge = $('#activityBadge');
    if (badge) badge.classList.remove('hidden');
  } catch (err) { toast('Failed to load run: ' + err.message, 'error'); }
}

// ── Socket Events ──

socket.on('run:start', (data) => {
  if (data.triggerSource === 'scheduler' || data.triggerSource === 'heartbeat') {
    backgroundRunIds.add(data.runId);
    return;
  }
  ensureTimeline();
  activityTimeline?.startRun(data.title || data.runId, data.model || '');
});

socket.on('run:thinking', (data) => {
  if (backgroundRunIds.has(data.runId)) return;
  const textEl = $('#thinkingText');
  if (textEl) textEl.textContent = `Thinking… (step ${data.iteration})`;
});

socket.on('run:tool_start', (data) => {
  if (backgroundRunIds.has(data.runId)) return;
  addActivityNode(data.stepId, data.toolName, data.toolArgs);
  const textEl = $('#thinkingText');
  if (textEl) textEl.textContent = `${data.toolName}…`;
});

socket.on('run:tool_end', (data) => {
  if (backgroundRunIds.has(data.runId)) return;
  updateActivityNode(data.stepId, data.toolName, data.result, data.screenshotPath, data.status);
});

socket.on('run:stream', (data) => {
  if (backgroundRunIds.has(data.runId) || data.triggerSource === 'scheduler' || data.triggerSource === 'heartbeat') return;
  let streamBubble = $('#streamBubble');
  if (!streamBubble) {
    const thinking = $('#thinking');
    if (thinking) thinking.remove();

    const div = document.createElement('div');
    div.className = 'chat-message assistant';
    div.innerHTML = '<div class="chat-avatar">N</div><div class="chat-bubble md-content" id="streamBubble"></div>';
    chatMessages.appendChild(div);
    streamBubble = $('#streamBubble');
  }
  streamBubble.innerHTML = renderMarkdown(data.content || data);
  chatMessages.scrollTop = chatMessages.scrollHeight;
});

socket.on('run:complete', (data) => {
  const isBackground = backgroundRunIds.has(data.runId) || data.triggerSource === 'scheduler' || data.triggerSource === 'heartbeat';
  if (isBackground) backgroundRunIds.delete(data.runId);

  if (!isBackground) {
    const thinking = $('#thinking');
    if (thinking) thinking.remove();

    const streamBubble = $('#streamBubble');
    if (streamBubble) {
      streamBubble.id = '';
      if (data.content) streamBubble.innerHTML = renderMarkdown(data.content);
    } else if (data.content) {
      appendMessage('assistant', data.content);
    }

    addActivityResponse(data.content);
    activityTimeline?.finishRun(data.status || 'completed');
    isStreaming = false;
    sendBtn.disabled = false;
  }
});

socket.on('chat:cleared', () => {
  chatMessages.innerHTML = '';
  if (chatEmpty) chatEmpty.classList.remove('hidden');
});

socket.on('run:error', (data) => {
  const thinking = $('#thinking');
  if (thinking) thinking.remove();
  const errMsg = data.error || 'Unknown error';
  appendMessage('assistant', `❌ ${errMsg}`);
  const badge = $('#activityBadge');
  if (badge) badge.classList.remove('hidden');
  isStreaming = false;
  sendBtn.disabled = false;
  toast(errMsg, 'error');
});

// AI sends a status update during a long task
socket.on('run:interim', (data) => {
  const textEl = $('#thinkingText');
  if (textEl) textEl.textContent = data.message;
  appendInterimMessage(data.message);
});

// Incoming social message → show in chat + activity canvas
socket.on('messaging:message', (data) => {
  appendSocialMessage(data.platform, 'user', data.content, data.senderName);
  ensureTimeline();
  const stepId = `msg-${Date.now()}`;
  activityTimeline.addNode(stepId, 'send_message', { platform: data.platform, to: data.chatId, content: data.content });
  activityTimeline.updateNode(stepId, 'send_message', { received: true, from: data.senderName }, null, 'completed');
  const badge = $('#activityBadge');
  if (badge) badge.classList.remove('hidden');
});

// ── Settings ──

$('#settingsBtn').addEventListener('click', async () => {
  try {
    const settings = await api('/settings');
    $('#settingHeartbeat').checked = settings.heartbeat_enabled === true || settings.heartbeat_enabled === 'true';
    $('#settingHeadlessBrowser').checked = settings.headless_browser !== false && settings.headless_browser !== 'false';
  } catch (err) {
    $('#settingHeadlessBrowser').checked = true; // default headless
  }
  $('#settingsModal').classList.remove('hidden');
});

$('#closeSettings').addEventListener('click', () => $('#settingsModal').classList.add('hidden'));
$('#cancelSettings').addEventListener('click', () => $('#settingsModal').classList.add('hidden'));

$('#saveSettings').addEventListener('click', async () => {
  try {
    await api('/settings', {
      method: 'PUT',
      body: {
        heartbeat_enabled: $('#settingHeartbeat').checked,
        headless_browser: $('#settingHeadlessBrowser').checked
      }
    });
    $('#settingsModal').classList.add('hidden');
    toast('Settings saved', 'success');
  } catch (err) {
    toast('Failed to save settings', 'error');
  }
});

// ── Logout ──

$('#logoutBtn').addEventListener('click', async () => {
  try {
    await fetch('/api/auth/logout', { method: 'POST' });
    window.location.href = '/login';
  } catch (err) {
    window.location.href = '/login';
  }
});

// ── Memory Page ──

// Category badge colours
const CAT_COLORS = {
  user_fact:   { bg: '#3b82f620', border: '#3b82f6', text: '#3b82f6', label: 'User Fact' },
  preference:  { bg: '#8b5cf620', border: '#8b5cf6', text: '#8b5cf6', label: 'Preference' },
  personality: { bg: '#ec489920', border: '#ec4899', text: '#ec4899', label: 'Personality' },
  episodic:    { bg: '#22c55e20', border: '#22c55e', text: '#22c55e', label: 'Episodic' },
};

let _memActiveCategory = '';
let _memCurrentPage = 0;

async function loadMemoryPage() {
  try {
    const data = await api('/memory');

    // Soul
    if ($('#soulEditor')) $('#soulEditor').value = data.soul || '';

    // Daily logs
    const dailyContainer = $('#dailyLogs');
    if (dailyContainer) {
      dailyContainer.innerHTML = '';
      for (const log of (data.dailyLogs || [])) {
        const card = document.createElement('div');
        card.className = 'item-card';
        card.innerHTML = `<div class="item-card-header"><div class="item-card-title">${escapeHtml(log.date)}</div></div><pre class="code-block">${escapeHtml(log.content || 'Empty')}</pre>`;
        dailyContainer.appendChild(card);
      }
    }

    // Core memory
    _renderCoreMemory(data.coreMemory || {});

    // API keys
    const keyContainer = $('#apiKeyList');
    if (keyContainer) {
      keyContainer.innerHTML = '';
      const keys = await api('/memory/api-keys');
      for (const [name, masked] of Object.entries(keys)) {
        const card = document.createElement('div');
        card.className = 'item-card flex justify-between items-center';
        card.innerHTML = `<div><div class="item-card-title">${escapeHtml(name)}</div><div class="item-card-meta font-mono">${escapeHtml(masked)}</div></div>
          <button class="btn btn-sm btn-danger" data-action="deleteApiKey" data-name="${escapeHtml(name)}">&times;</button>`;
        keyContainer.appendChild(card);
      }
    }

    // Memories list
    await _loadMemoriesTab(_memActiveCategory);

  } catch (err) {
    toast('Failed to load memory', 'error');
  }
}

async function _loadMemoriesTab(category = '') {
  const container = $('#memoryList');
  if (!container) return;
  container.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><p>Loading…</p></div>';
  try {
    const params = new URLSearchParams({ limit: 60, offset: 0 });
    if (category) params.set('category', category);
    const memories = await api(`/memory/memories?${params}`);
    _renderMemories(memories, container);
  } catch {
    container.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><p>Failed to load memories</p></div>';
  }
}

function _renderMemories(memories, container) {
  container.innerHTML = '';
  if (!memories.length) {
    container.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><p>No memories yet. The agent will save things automatically, or you can add one manually.</p></div>';
    return;
  }
  for (const mem of memories) {
    const cat = CAT_COLORS[mem.category] || CAT_COLORS.episodic;
    const dots = '●'.repeat(Math.round(mem.importance / 2)) + '○'.repeat(5 - Math.round(mem.importance / 2));
    const date = new Date(mem.updated_at || mem.created_at);
    const dateStr = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: '2-digit' });

    const card = document.createElement('div');
    card.className = 'card';
    card.style.cssText = `margin:0;cursor:default;border-left:3px solid ${cat.border};`;
    card.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px;margin-bottom:8px;">
        <span style="background:${cat.bg};color:${cat.text};border:1px solid ${cat.border};border-radius:999px;padding:2px 10px;font-size:0.72rem;font-weight:600;flex-shrink:0;">${cat.label}</span>
        <div style="display:flex;align-items:center;gap:6px;flex-shrink:0;">
          <span style="font-size:0.75rem;color:var(--text-muted);">${dateStr}</span>
          <button class="btn btn-sm btn-danger" data-action="deleteMemory" data-id="${escapeHtml(mem.id)}" style="padding:2px 7px;font-size:0.75rem;">&times;</button>
        </div>
      </div>
      <div style="font-size:0.9rem;line-height:1.5;color:var(--text);">${escapeHtml(mem.content)}</div>
      <div style="margin-top:8px;font-size:0.75rem;color:var(--text-muted);letter-spacing:0.03em;">${dots} <span style="margin-left:4px;">importance ${mem.importance}</span>${mem.access_count > 0 ? ` · recalled ${mem.access_count}×` : ''}</div>`;
    container.appendChild(card);
  }
}

function _renderCoreMemory(core) {
  const container = $('#coreMemoryList');
  if (!container) return;
  container.innerHTML = '';
  if (!Object.keys(core).length) {
    const empty = document.createElement('p');
    empty.className = 'text-muted';
    empty.style.cssText = 'font-size:0.85rem;margin-bottom:8px;';
    empty.textContent = 'No core memory entries yet.';
    container.appendChild(empty);
    return;
  }
  for (const [key, val] of Object.entries(core)) {
    const row = document.createElement('div');
    row.className = 'item-card';
    row.style.marginBottom = '8px';
    const display = typeof val === 'object' ? JSON.stringify(val) : String(val);
    row.innerHTML = `
      <div class="item-card-header">
        <div>
          <div class="item-card-title" style="font-size:0.85rem;font-family:monospace;">${escapeHtml(key)}</div>
          <div class="item-card-meta" style="margin-top:3px;">${escapeHtml(display.slice(0, 200))}</div>
        </div>
        <div class="item-card-actions">
          <button class="btn btn-sm btn-secondary" data-action="editCore" data-key="${escapeHtml(key)}" data-val="${escapeHtml(display)}">Edit</button>
          <button class="btn btn-sm btn-danger" data-action="deleteCore" data-key="${escapeHtml(key)}">&times;</button>
        </div>
      </div>`;
    container.appendChild(row);
  }
}

// Tab switching for memory page
$$('[data-mem-tab]').forEach(tab => {
  tab.addEventListener('click', () => {
    $$('[data-mem-tab]').forEach(t => t.classList.remove('active'));
    $$('.mem-panel').forEach(p => p.classList.remove('active'));
    tab.classList.add('active');
    $(`#mem-${tab.dataset.memTab}`)?.classList.add('active');
  });
});

// Category filter
$('#memoryCategoryFilter')?.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-cat]');
  if (!btn) return;
  _memActiveCategory = btn.dataset.cat;
  $$('#memoryCategoryFilter [data-cat]').forEach(b => {
    b.className = b.dataset.cat === _memActiveCategory ? 'btn btn-sm btn-primary' : 'btn btn-sm btn-secondary';
  });
  await _loadMemoriesTab(_memActiveCategory);
});

// Semantic search
$('#memorySearchBtn')?.addEventListener('click', async () => {
  const q = $('#memorySearchInput')?.value?.trim();
  if (!q) { await _loadMemoriesTab(_memActiveCategory); return; }
  const container = $('#memoryList');
  container.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><p>Searching…</p></div>';
  try {
    const results = await api('/memory/memories/recall', { method: 'POST', body: { query: q, limit: 20 } });
    _renderMemories(results, container);
  } catch {
    container.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><p>Search failed</p></div>';
  }
});

$('#memorySearchInput')?.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') $('#memorySearchBtn')?.click();
});

// Soul save
$('#saveSoulBtn')?.addEventListener('click', async () => {
  try {
    await api('/memory/soul', { method: 'PUT', body: { content: $('#soulEditor').value } });
    toast('Soul saved', 'success');
  } catch { toast('Failed to save', 'error'); }
});

// Add Memory Modal
$('#addMemoryBtn')?.addEventListener('click', () => {
  $('#addMemoryModal')?.classList.remove('hidden');
});
$('#closeAddMemory')?.addEventListener('click', () => $('#addMemoryModal')?.classList.add('hidden'));
$('#cancelAddMemory')?.addEventListener('click', () => $('#addMemoryModal')?.classList.add('hidden'));

$('#confirmAddMemory')?.addEventListener('click', async () => {
  const content = $('#newMemoryContent')?.value?.trim();
  if (!content) { toast('Content is required', 'error'); return; }
  const category  = $('#newMemoryCategory')?.value || 'episodic';
  const importance = parseInt($('#newMemoryImportance')?.value) || 5;
  try {
    await api('/memory/memories', { method: 'POST', body: { content, category, importance } });
    $('#addMemoryModal')?.classList.add('hidden');
    $('#newMemoryContent').value = '';
    await _loadMemoriesTab(_memActiveCategory);
    toast('Memory saved', 'success');
  } catch { toast('Failed to save memory', 'error'); }
});

// Set core memory key
$('#setCoreBtn')?.addEventListener('click', async () => {
  const key = $('#coreKeySelect')?.value;
  const value = $('#coreValueInput')?.value?.trim();
  if (!key || !value) { toast('Key and value are required', 'error'); return; }
  try {
    await api(`/memory/core/${key}`, { method: 'PUT', body: { value } });
    $('#coreValueInput').value = '';
    const core = await api('/memory/core');
    _renderCoreMemory(core);
    toast('Core memory updated', 'success');
  } catch { toast('Failed to update core memory', 'error'); }
});

// API Keys
window.deleteApiKey = async (name) => {
  try {
    await api(`/memory/api-keys/${name}`, { method: 'DELETE' });
    loadMemoryPage();
    toast('Key deleted', 'success');
  } catch { toast('Failed to delete', 'error'); }
};

$('#addApiKeyBtn')?.addEventListener('click', () => {
  const name = prompt('Service name:');
  if (!name) return;
  const key = prompt('API key value:');
  if (!key) return;
  api(`/memory/api-keys/${name}`, { method: 'PUT', body: { key } })
    .then(() => { loadMemoryPage(); toast('Key added', 'success'); })
    .catch(() => toast('Failed to add key', 'error'));
});

// Global click delegation for memory actions
document.addEventListener('click', async e => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const action = btn.dataset.action;

  if (action === 'deleteApiKey') {
    window.deleteApiKey(btn.dataset.name);
  } else if (action === 'deleteMemory') {
    if (!confirm('Delete this memory?')) return;
    try {
      await api(`/memory/memories/${btn.dataset.id}`, { method: 'DELETE' });
      await _loadMemoriesTab(_memActiveCategory);
      toast('Memory deleted', 'success');
    } catch { toast('Failed to delete', 'error'); }
  } else if (action === 'editCore') {
    const newVal = prompt(`Edit ${btn.dataset.key}:`, btn.dataset.val);
    if (newVal === null) return;
    try {
      await api(`/memory/core/${btn.dataset.key}`, { method: 'PUT', body: { value: newVal } });
      const core = await api('/memory/core');
      _renderCoreMemory(core);
      toast('Updated', 'success');
    } catch { toast('Failed to update', 'error'); }
  } else if (action === 'deleteCore') {
    if (!confirm(`Delete core key "${btn.dataset.key}"?`)) return;
    try {
      await api(`/memory/core/${btn.dataset.key}`, { method: 'DELETE' });
      const core = await api('/memory/core');
      _renderCoreMemory(core);
      toast('Deleted', 'success');
    } catch { toast('Failed to delete', 'error'); }
  }
});

// ── Skills Page ──

// Tab switching for skills page
document.querySelectorAll('[data-skills-tab]').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('[data-skills-tab]').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    const which = tab.dataset.skillsTab;
    $('#skillList').classList.toggle('hidden', which !== 'installed');
    $('#skillStore').classList.toggle('hidden', which !== 'store');
    if (which === 'store') loadSkillStore();
    else loadSkillsPage();
  });
});

async function loadSkillStore() {
  const wrap = $('#skillStore');
  wrap.innerHTML = '<div class="empty-state"><p>Loading store…</p></div>';
  try {
    const items = await api('/store');

    // Build category groups
    const cats = {};
    for (const item of items) {
      if (!cats[item.category]) cats[item.category] = [];
      cats[item.category].push(item);
    }

    const CAT_LABELS = { system: '⚙️ System', network: '📡 Network', info: 'ℹ️ Info', dev: '🛠 Dev', productivity: '🗂 Productivity', fun: '🎲 Fun' };

    wrap.innerHTML = '';

    // Search input
    const searchRow = document.createElement('div');
    searchRow.style.cssText = 'margin-bottom:16px;';
    const searchInp = document.createElement('input');
    searchInp.type = 'text';
    searchInp.className = 'input';
    searchInp.placeholder = 'Search skills…';
    searchRow.appendChild(searchInp);
    wrap.appendChild(searchRow);

    const cardsWrap = document.createElement('div');
    wrap.appendChild(cardsWrap);

    function renderStore(filter) {
      cardsWrap.innerHTML = '';
      let totalShown = 0;
      for (const [cat, catItems] of Object.entries(cats)) {
        const visible = catItems.filter(i => !filter || i.name.toLowerCase().includes(filter) || i.description.toLowerCase().includes(filter));
        if (!visible.length) continue;
        totalShown += visible.length;

        const section = document.createElement('div');
        section.style.cssText = 'margin-bottom:28px;';
        section.innerHTML = `<div style="font-size:0.8rem;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-muted);margin-bottom:10px;">${CAT_LABELS[cat] || cat}</div>`;

        const grid = document.createElement('div');
        grid.style.cssText = 'display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:10px;';

        for (const item of visible) {
          const card = document.createElement('div');
          card.className = 'card';
          card.style.cssText = 'display:flex;flex-direction:column;gap:8px;padding:14px;';
          card.innerHTML = `
            <div style="display:flex;align-items:center;gap:10px;">
              <span style="font-size:1.6rem;line-height:1;">${item.icon}</span>
              <div style="flex:1;min-width:0;">
                <div style="font-weight:600;font-size:0.95rem;">${escapeHtml(item.name)}</div>
                <div style="font-size:0.78rem;color:var(--text-muted);margin-top:2px;">${escapeHtml(item.description)}</div>
              </div>
            </div>
            <div style="display:flex;justify-content:flex-end;">
              ${item.installed
                ? `<span class="badge badge-success" style="margin-right:auto;">Installed</span>
                   <button class="btn btn-sm btn-danger" data-store-action="uninstall" data-store-id="${escapeHtml(item.id)}">Remove</button>`
                : `<button class="btn btn-sm btn-primary" data-store-action="install" data-store-id="${escapeHtml(item.id)}">Install</button>`
              }
            </div>`;
          grid.appendChild(card);
        }
        section.appendChild(grid);
        cardsWrap.appendChild(section);
      }
      if (!totalShown) cardsWrap.innerHTML = '<div class="empty-state"><p>No matching skills</p></div>';
    }

    renderStore('');

    searchInp.addEventListener('input', () => renderStore(searchInp.value.trim().toLowerCase()));

    cardsWrap.addEventListener('click', async (e) => {
      const btn = e.target.closest('[data-store-action]');
      if (!btn) return;
      const { storeAction, storeId } = btn.dataset;
      btn.disabled = true;
      btn.textContent = storeAction === 'install' ? 'Installing…' : 'Removing…';
      try {
        if (storeAction === 'install') {
          await api(`/store/${storeId}/install`, { method: 'POST' });
          toast('Skill installed!', 'success');
        } else {
          await api(`/store/${storeId}/uninstall`, { method: 'DELETE' });
          toast('Skill removed', 'info');
        }
        await loadSkillStore(); // refresh
      } catch (err) {
        toast('Error: ' + err.message, 'error');
        btn.disabled = false;
      }
    });

  } catch (err) {
    wrap.innerHTML = '<div class="empty-state"><p>Failed to load store</p></div>';
    console.error(err);
  }
}

async function loadSkillsPage() {
  try {
    const skills = await api('/skills');
    const container = $('#skillList');
    container.innerHTML = '';

    if (skills.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>No skills installed yet. <a href="#" id="goToStore">Browse the store →</a></p></div>';
      document.getElementById('goToStore')?.addEventListener('click', (e) => {
        e.preventDefault();
        document.querySelector('[data-skills-tab="store"]')?.click();
      });
      return;
    }

    for (const skill of skills) {
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `
        <div class="item-card-header">
          <div>
            <div class="item-card-title">${escapeHtml(skill.name)}</div>
            <div class="item-card-meta">${escapeHtml(skill.description)}</div>
          </div>
          <div class="item-card-actions">
            <span class="badge ${skill.enabled ? 'badge-success' : 'badge-neutral'}">${skill.enabled ? 'Active' : 'Disabled'}</span>
            <button class="btn btn-sm btn-secondary" data-action="editSkill" data-filename="${escapeHtml(skill.filename)}">Edit</button>
            <button class="btn btn-sm btn-danger" data-action="deleteSkill" data-filename="${escapeHtml(skill.filename)}">&times;</button>
          </div>
        </div>
        <div class="item-card-meta">Trigger: ${escapeHtml(skill.trigger || 'N/A')} | Category: ${escapeHtml(skill.category)}</div>
      `;
      container.appendChild(card);
    }
  } catch (err) {
    toast('Failed to load skills', 'error');
  }
}

window.editSkill = async (filename) => {
  try {
    const data = await api(`/skills/${filename}`);
    const content = prompt('Edit skill content:', data.content);
    if (content !== null) {
      await api(`/skills/${filename}`, { method: 'PUT', body: { content } });
      loadSkillsPage();
      toast('Skill updated', 'success');
    }
  } catch (err) { toast('Failed to edit skill', 'error'); }
};

window.deleteSkill = async (filename) => {
  if (!confirm(`Delete skill ${filename}?`)) return;
  try {
    await api(`/skills/${filename}`, { method: 'DELETE' });
    loadSkillsPage();
    toast('Skill deleted', 'success');
  } catch (err) { toast('Failed to delete', 'error'); }
};

// Skills event delegation
$('#skillList').addEventListener('click', e => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const action = btn.dataset.action;
  if (action === 'editSkill') window.editSkill(btn.dataset.filename);
  else if (action === 'deleteSkill') window.deleteSkill(btn.dataset.filename);
});

$('#addSkillBtn').addEventListener('click', () => {
  const name = prompt('Skill filename (without .md):');
  if (!name) return;
  const content = `---\nname: ${name}\ndescription: \ntrigger: \ncategory: general\nenabled: true\n---\n\n# ${name}\n\nDescribe the skill here.`;
  api('/skills', { method: 'POST', body: { filename: name, content } })
    .then(() => { loadSkillsPage(); toast('Skill created', 'success'); })
    .catch(() => toast('Failed to create skill', 'error'));
});

// ── MCP Servers Page ──

async function loadMCPPage() {
  try {
    const servers = await api('/mcp');
    const container = $('#mcpServerList');
    container.innerHTML = '';

    if (servers.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>No MCP servers configured</p></div>';
      return;
    }

    for (const srv of servers) {
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `
        <div class="item-card-header">
          <div>
            <div class="item-card-title">${escapeHtml(srv.name)}</div>
            <div class="item-card-meta font-mono">${escapeHtml(srv.command)}</div>
          </div>
          <div class="item-card-actions">
            <span class="badge ${srv.status === 'running' ? 'badge-success' : 'badge-neutral'}">${srv.status}</span>
            ${srv.status === 'running'
              ? `<button class="btn btn-sm btn-secondary" data-action="stopMCP" data-id="${srv.id}">Stop</button>`
              : `<button class="btn btn-sm btn-primary" data-action="startMCP" data-id="${srv.id}">Start</button>`
            }
            <button class="btn btn-sm btn-danger" data-action="deleteMCP" data-id="${srv.id}">&times;</button>
          </div>
        </div>
        ${srv.toolCount > 0 ? `<div class="item-card-meta">${srv.toolCount} tools available</div>` : ''}
      `;
      container.appendChild(card);
    }
  } catch (err) {
    toast('Failed to load MCP servers', 'error');
  }
}

window.startMCP = async (id) => {
  try {
    await api(`/mcp/${id}/start`, { method: 'POST' });
    loadMCPPage();
    toast('Server started', 'success');
  } catch (err) { toast(err.message, 'error'); }
};

window.stopMCP = async (id) => {
  try {
    await api(`/mcp/${id}/stop`, { method: 'POST' });
    loadMCPPage();
    toast('Server stopped', 'success');
  } catch (err) { toast(err.message, 'error'); }
};

window.deleteMCP = async (id) => {
  if (!confirm('Delete this MCP server?')) return;
  try {
    await api(`/mcp/${id}`, { method: 'DELETE' });
    loadMCPPage();
    toast('Server deleted', 'success');
  } catch (err) { toast('Failed to delete', 'error'); }
};

// MCP event delegation
$('#mcpServerList').addEventListener('click', e => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const id = btn.dataset.id;
  const action = btn.dataset.action;
  if (action === 'startMCP') window.startMCP(id);
  else if (action === 'stopMCP') window.stopMCP(id);
  else if (action === 'deleteMCP') window.deleteMCP(id);
});

$('#addMcpBtn').addEventListener('click', () => {
  const name = prompt('Server name:');
  if (!name) return;
  const command = prompt('Command to start the server:');
  if (!command) return;
  const argsStr = prompt('Arguments (comma-separated, or leave empty):') || '';
  const args = argsStr ? argsStr.split(',').map(s => s.trim()) : [];

  api('/mcp', { method: 'POST', body: { name, command, config: { args }, enabled: true } })
    .then(() => { loadMCPPage(); toast('Server added', 'success'); })
    .catch(() => toast('Failed to add server', 'error'));
});

// ── Scheduler Page ──

async function loadSchedulerPage() {
  try {
    const tasks = await api('/scheduler');
    const container = $('#taskList');
    container.innerHTML = '';

    if (tasks.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>No scheduled tasks</p></div>';
      return;
    }

    for (const task of tasks) {
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `
        <div class="item-card-header">
          <div>
            <div class="item-card-title">${escapeHtml(task.name)}</div>
            <div class="item-card-meta font-mono">${escapeHtml(task.cronExpression)}</div>
          </div>
          <div class="item-card-actions">
            <span class="badge ${task.enabled ? 'badge-success' : 'badge-neutral'}">${task.enabled ? 'Active' : 'Paused'}</span>
            <button class="btn btn-sm btn-primary" data-action="runTask" data-id="${task.id}">Run Now</button>
            <button class="btn btn-sm btn-danger" data-action="deleteTask" data-id="${task.id}">&times;</button>
          </div>
        </div>
        <div class="item-card-meta">${escapeHtml(task.config?.prompt?.slice(0, 100) || 'No prompt')}${task.lastRun ? ` | Last run: ${formatTime(task.lastRun)}` : ''}</div>
      `;
      container.appendChild(card);
    }
  } catch (err) {
    toast('Failed to load tasks', 'error');
  }
}

window.runTask = async (id) => {
  try {
    await api(`/scheduler/${id}/run`, { method: 'POST' });
    toast('Task started', 'success');
  } catch (err) { toast(err.message, 'error'); }
};

window.deleteTask = async (id) => {
  if (!confirm('Delete this task?')) return;
  try {
    await api(`/scheduler/${id}`, { method: 'DELETE' });
    loadSchedulerPage();
    toast('Task deleted', 'success');
  } catch (err) { toast('Failed to delete', 'error'); }
};

// Scheduler event delegation
$('#taskList').addEventListener('click', e => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const id = btn.dataset.id;
  const action = btn.dataset.action;
  if (action === 'runTask') window.runTask(id);
  else if (action === 'deleteTask') window.deleteTask(id);
});

$('#addTaskBtn').addEventListener('click', () => {
  const name = prompt('Task name:');
  if (!name) return;
  const cronExpression = prompt('Cron expression (e.g., */30 * * * * for every 30 min):');
  if (!cronExpression) return;
  const promptText = prompt('What should the agent do?');
  if (!promptText) return;

  api('/scheduler', { method: 'POST', body: { name, cronExpression, prompt: promptText } })
    .then(() => { loadSchedulerPage(); toast('Task created', 'success'); })
    .catch((err) => toast(err.message, 'error'));
});

// ── Messaging Page ──

// Registry of supported platforms — add new entries here to support more providers
const _svgLogo = {
  whatsapp: `<svg viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="18" cy="18" r="18" fill="#25D366"/><path d="M18 7C11.9 7 7 11.9 7 18c0 2.1.58 4.08 1.6 5.77L7 29l5.4-1.56A11 11 0 0018 29c6.07 0 11-4.93 11-11S24.07 7 18 7z" fill="#25D366"/><path d="M24.4 21.52c-.33-.17-1.94-.96-2.24-1.07-.3-.1-.52-.17-.74.17-.22.33-.85 1.07-1.04 1.29-.2.22-.38.25-.71.08-.33-.17-1.39-.51-2.65-1.63-.98-.87-1.64-1.95-1.83-2.28-.19-.33-.02-.51.14-.67.15-.15.33-.38.5-.58.17-.19.22-.33.33-.55.1-.22.05-.41-.03-.58-.08-.17-.74-1.78-1.01-2.44-.27-.64-.54-.55-.74-.56-.19-.01-.41-.01-.63-.01-.22 0-.58.08-.88.41-.3.33-1.15 1.12-1.15 2.74s1.18 3.18 1.34 3.4c.17.22 2.32 3.54 5.61 4.96.79.34 1.4.54 1.87.69.79.25 1.5.22 2.07.13.63-.09 1.94-.79 2.22-1.56.28-.77.28-1.43.19-1.56-.09-.14-.3-.22-.63-.38z" fill="white"/></svg>`,

  telegram: `<svg viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="18" cy="18" r="18" fill="#2AABEE"/><path d="M8.16 17.36l14.75-5.69c.68-.25 1.28.17 1.14.95L21.55 24.4c-.18.81-.67 1.01-1.36.63l-3.83-2.83-1.85 1.78c-.2.2-.38.37-.77.37l.27-3.86 6.99-6.32c.3-.27-.07-.42-.46-.15l-8.65 5.45-3.72-1.17c-.81-.25-.82-.81.17-1.2z" fill="white"/></svg>`,

  discord: `<svg viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="18" cy="18" r="18" fill="#5865F2"/><path d="M25.57 11.69A18.2 18.2 0 0021.8 10.6a.07.07 0 00-.07.04 12.4 12.4 0 00-.52 1.06 16.8 16.8 0 00-5.07 0 10.7 10.7 0 00-.53-1.06.07.07 0 00-.07-.04 18.1 18.1 0 00-3.59 1.1.06.06 0 00-.03.03C9.51 15.52 8.61 19 9.07 22.4c0 .02.01.03.03.04a17.3 17.3 0 005.22 2.64.07.07 0 00.07-.02c.4-.55.76-1.13 1.06-1.74a.07.07 0 00-.04-.09 11.4 11.4 0 01-1.63-.78.07.07 0 010-.11c.11-.08.22-.17.32-.25a.07.07 0 01.07-.01c3.42 1.56 7.12 1.56 10.5 0a.07.07 0 01.07.01c.1.08.21.17.33.25a.07.07 0 010 .11c-.52.3-1.06.56-1.64.78a.07.07 0 00-.03.1c.31.6.67 1.18 1.06 1.74a.07.07 0 00.07.02 17.24 17.24 0 005.23-2.64.07.07 0 00.03-.04c.52-3.74-.53-6.93-2.85-10.38a.05.05 0 00-.03-.02zm-9.73 6.72c-1.1 0-2-1-2-2.24s.88-2.24 2-2.24c1.12 0 2.01 1.01 2 2.24 0 1.23-.88 2.24-2 2.24zm7.37 0c-1.1 0-2-1-2-2.24s.88-2.24 2-2.24c1.12 0 2.01 1.01 2 2.24 0 1.23-.88 2.24-2 2.24z" fill="white"/></svg>`,

  telnyx: `<svg viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="18" cy="18" r="18" fill="#00C8A0"/><path d="M23 21.83c-.56.56-1.12 1.12-2.02 1.01-.9-.11-2.47-.79-4.38-2.7-1.91-1.91-2.59-3.48-2.7-4.38-.11-.9.45-1.46 1.01-2.02.56-.56.9-.56 1.24 0l1.35 2.02c.34.56.22 1.01-.11 1.35l-.56.56c.34.67.9 1.46 1.58 2.13.67.67 1.46 1.23 2.13 1.57l.56-.56c.34-.34.79-.45 1.35-.11l2.02 1.35c.56.34.56.68 0 1.24z" fill="white"/><path d="M18 9v2.25A6.75 6.75 0 0124.75 18H27A9 9 0 0018 9z" fill="white" opacity=".65"/><path d="M18 12.75v2.25A3 3 0 0121 18h2.25A5.25 5.25 0 0018 12.75z" fill="white" opacity=".9"/></svg>`,
};

const MESSAGING_PLATFORM_GROUPS = [
  { id: 'text',  label: 'Text & Chat',  description: 'Send and receive messages' },
  { id: 'voice', label: 'Voice Calls',  description: 'Inbound & outbound phone calls' },
];

const MESSAGING_PLATFORMS = [
  { id: 'whatsapp', name: 'WhatsApp',    group: 'text',  color: '#25D366', connectMethod: 'qr'     },
  { id: 'telegram', name: 'Telegram',    group: 'text',  color: '#2AABEE', connectMethod: 'config' },
  { id: 'discord',  name: 'Discord',     group: 'text',  color: '#5865F2', connectMethod: 'config' },
  { id: 'telnyx',   name: 'Telnyx Voice',group: 'voice', color: '#00C8A0', connectMethod: 'config' },
];

// Per-platform whitelist config
const PLATFORM_WHITELIST = {
  whatsapp: {
    settingKey: 'platform_whitelist_whatsapp',
    label: 'Approved contacts',
    emptyHint: 'No approved contacts yet — senders are added via the allow popup.',
    allowAdd: false,
    saveFn: async (list) => api('/settings', { method: 'PUT', body: { platform_whitelist_whatsapp: JSON.stringify(list) } }),
  },
  telnyx: {
    settingKey: 'platform_whitelist_telnyx',
    label: 'Allowed callers',
    emptyHint: 'Empty — all inbound callers accepted.',
    allowAdd: true,
    addPlaceholder: 'e.g. +12125550100',
    saveFn: async (list) => api('/messaging/telnyx/whitelist', { method: 'PUT', body: { numbers: list } }),
  },
  discord: {
    settingKey: 'platform_whitelist_discord',
    label: 'Approved users, servers & channels',
    emptyHint: 'No entries — all messages blocked. Add entries via the allow popup or manually below.',
    allowAdd: true,
    addTypes: ['user', 'guild', 'channel'],
    saveFn: async (list) => api('/messaging/discord/whitelist', { method: 'PUT', body: { ids: list } }),
  },
  telegram: {
    settingKey: 'platform_whitelist_telegram',
    label: 'Approved users & groups',
    emptyHint: 'No entries — all messages blocked. Add entries via the allow popup or manually below.',
    allowAdd: true,
    addTypes: ['user', 'group'],
    saveFn: async (list) => api('/messaging/telegram/whitelist', { method: 'PUT', body: { ids: list } }),
  },
};

async function loadMessagingPage() {
  try {
    const [statuses, settings] = await Promise.all([api('/messaging/status'), api('/settings')]);
    const container = $('#platformList');
    container.innerHTML = '';

    for (const group of MESSAGING_PLATFORM_GROUPS) {
      const groupPlatforms = MESSAGING_PLATFORMS.filter(p => p.group === group.id);

      // Section header
      const section = document.createElement('div');
      section.style.cssText = 'margin-bottom:28px;';

      const heading = document.createElement('div');
      heading.style.cssText = 'display:flex;align-items:baseline;gap:10px;margin-bottom:14px;padding-bottom:8px;border-bottom:1px solid var(--border);';
      heading.innerHTML = `
        <span style="font-size:0.95rem;font-weight:700;">${escapeHtml(group.label)}</span>
        <span style="font-size:0.78rem;color:var(--text-muted);">${escapeHtml(group.description)}</span>`;
      section.appendChild(heading);

      // Grid — 2 cols for text/chat, single col for voice
      const grid = document.createElement('div');
      grid.style.cssText = group.id === 'text'
        ? 'display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px;'
        : 'display:flex;flex-direction:column;gap:14px;';

      for (const platform of groupPlatforms) {
        const info    = statuses[platform.id] || { status: 'not_configured' };
        const wlCfg   = PLATFORM_WHITELIST[platform.id];
        const isConnected  = info.status === 'connected';
        const isConnecting = info.status === 'connecting' || info.status === 'awaiting_qr';

        let wlList = [];
        try {
          const raw = settings[wlCfg.settingKey];
          if (raw) { wlList = typeof raw === 'string' ? JSON.parse(raw) : raw; }
          if (!Array.isArray(wlList)) wlList = [];
        } catch { wlList = []; }

        // Auth subtitle
        let authSub = '';
        if (isConnected) {
          if (info.authInfo?.phoneNumber) authSub = escapeHtml(info.authInfo.phoneNumber);
          else if (info.authInfo?.tag)    authSub = escapeHtml(info.authInfo.tag);
          else if (info.authInfo?.username) authSub = '@' + escapeHtml(info.authInfo.username);
        }

        const card = document.createElement('div');
        card.className = 'card';
        card.style.cssText = 'margin:0;';

        // ── Top row: logo + name + status + buttons
        const topRow = document.createElement('div');
        topRow.className = 'flex items-center justify-between';
        topRow.innerHTML = `
          <div class="flex items-center gap-3">
            <div style="width:40px;height:40px;flex-shrink:0;border-radius:10px;overflow:hidden;">${_svgLogo[platform.id] || ''}</div>
            <div>
              <div class="item-card-title" style="font-size:0.97rem;">${escapeHtml(platform.name)}</div>
              <div class="flex items-center gap-2 mt-1" style="flex-wrap:wrap;">
                <span class="badge ${isConnected ? 'badge-success' : 'badge-neutral'}" style="font-size:0.7rem;">
                  ${escapeHtml(info.status.replace(/_/g, ' '))}
                </span>
                ${authSub ? `<span class="text-xs text-muted">${authSub}</span>` : ''}
                ${!isConnected && info.lastConnected ? `<span class="text-xs text-muted">last seen ${formatTime(info.lastConnected)}</span>` : ''}
              </div>
            </div>
          </div>
          <div class="flex gap-2" style="flex-shrink:0;">
            ${isConnected
              ? `<button class="btn btn-sm btn-secondary" data-action="disconnectPlatform" data-platform="${platform.id}">Disconnect</button>
                 <button class="btn btn-sm btn-danger"     data-action="logoutPlatform"     data-platform="${platform.id}">Logout</button>`
              : isConnecting
                ? `<span class="text-muted text-sm" style="padding:0 4px;">Connecting…</span>`
                : `<button class="btn btn-sm btn-primary" data-action="connectPlatform" data-platform="${platform.id}" data-method="${platform.connectMethod}">Connect</button>`}
          </div>`;
        card.appendChild(topRow);

        // ── Whitelist collapsible strip
        const strip = document.createElement('div');
        strip.style.cssText = 'border-top:1px solid var(--border);margin:14px -20px 0;';

        const arrowId = `wl-arrow-${platform.id}`;
        const labelId = `wl-label-${platform.id}`;
        const toggleBtn = document.createElement('button');
        toggleBtn.style.cssText = 'display:flex;align-items:center;gap:7px;width:100%;background:none;border:none;cursor:pointer;padding:9px 20px;color:var(--text-muted);font-size:0.8rem;user-select:none;';
        toggleBtn.innerHTML = `<span id="${arrowId}" style="font-size:0.65rem;transition:transform 0.15s;display:inline-block;">&#9654;</span>
          <span id="${labelId}">${_wlLabel(wlCfg.label, wlList.length)}</span>`;

        const panel = document.createElement('div');
        panel.id = `wl-panel-${platform.id}`;
        panel.style.cssText = 'display:none;padding:4px 20px 14px;';
        _buildWhitelistPanel(panel, wlList, wlCfg, platform.id);

        toggleBtn.addEventListener('click', () => {
          const open = panel.style.display !== 'none';
          panel.style.display = open ? 'none' : 'block';
          document.getElementById(arrowId).style.transform = open ? '' : 'rotate(90deg)';
        });

        strip.appendChild(toggleBtn);
        strip.appendChild(panel);
        card.appendChild(strip);
        grid.appendChild(card);
      }

      section.appendChild(grid);
      container.appendChild(section);
    }
  } catch (err) {
    console.error(err);
    toast('Failed to load messaging', 'error');
  }
}

function _wlLabel(label, count) {
  return count
    ? `${label} <strong style="color:var(--text);font-weight:600;">(${count})</strong>`
    : `${label} <span style="opacity:0.55;">— none</span>`;
}

function _buildWhitelistPanel(panel, list, wlCfg, platformId) {
  panel.innerHTML = '';

  // Type-badge colours for Discord prefixed entries
  const TYPE_COLORS = { user: '#5865F2', guild: '#57F287', channel: '#FEE75C', group: '#2AABEE' };
  const TYPE_LABELS = { user: 'User', guild: 'Server', channel: 'Channel', group: 'Group' };

  if (!list.length) {
    const empty = document.createElement('p');
    empty.className = 'text-xs text-muted';
    empty.style.margin = '0 0 6px';
    empty.textContent = wlCfg.emptyHint;
    panel.appendChild(empty);
  } else {
    const tags = document.createElement('div');
    tags.style.cssText = 'display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px;';
    for (const entry of list) {
      // Parse optional prefix
      const colon = entry.indexOf(':');
      const entryType = (colon > 0 && ['user','guild','channel'].includes(entry.slice(0,colon)))
        ? entry.slice(0, colon) : null;
      const entryId = colon > 0 ? entry.slice(colon + 1) : entry;

      const tag = document.createElement('span');
      tag.style.cssText = 'display:inline-flex;align-items:center;gap:5px;background:var(--bg-secondary);border:1px solid var(--border);border-radius:999px;padding:2px 10px 2px 8px;font-size:0.81rem;';

      if (entryType) {
        const badge = document.createElement('span');
        badge.style.cssText = `background:${TYPE_COLORS[entryType] || '#888'};color:#000;border-radius:999px;padding:1px 7px;font-size:0.71rem;font-weight:600;`;
        badge.textContent = TYPE_LABELS[entryType] || entryType;
        tag.appendChild(badge);
        tag.appendChild(document.createTextNode(' ' + entryId));
      } else {
        tag.appendChild(document.createTextNode(entry));
      }

      const removeBtn = document.createElement('button');
      removeBtn.style.cssText = 'background:none;border:none;cursor:pointer;color:var(--text-muted);padding:0;font-size:1rem;line-height:1;margin-left:2px;';
      removeBtn.textContent = '×';
      removeBtn.title = 'Remove';
      removeBtn.addEventListener('click', async () => {
        const newList = list.filter(n => n !== entry);
        try {
          await wlCfg.saveFn(newList);
          list = newList;
          _buildWhitelistPanel(panel, list, wlCfg, platformId);
          const lbl = document.getElementById(`wl-label-${platformId}`);
          if (lbl) lbl.innerHTML = _wlLabel(wlCfg.label, newList.length);
        } catch { toast('Failed to remove', 'error'); }
      });
      tag.appendChild(removeBtn);
      tags.appendChild(tag);
    }
    panel.appendChild(tags);
  }

  if (wlCfg.allowAdd) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px;align-items:center;';

    if (wlCfg.addTypes) {
      // Type selector + ID input for Discord
      const sel = document.createElement('select');
      sel.className = 'input';
      sel.style.cssText = 'flex:0 0 auto;width:110px;';
      for (const t of wlCfg.addTypes) {
        const opt = document.createElement('option');
        opt.value = t;
        opt.textContent = TYPE_LABELS[t] || t;
        sel.appendChild(opt);
      }
      const inp = document.createElement('input');
      inp.type = 'text'; inp.className = 'input'; inp.style.flex = '1';
      inp.placeholder = 'Snowflake ID';
      const addBtn = document.createElement('button');
      addBtn.className = 'btn btn-primary btn-sm';
      addBtn.textContent = 'Add';
      addBtn.addEventListener('click', async () => {
        const id = inp.value.replace(/[^0-9]/g, '').trim();
        if (!id) return;
        const val = `${sel.value}:${id}`;
        if (list.includes(val)) { toast('Already in list', 'info'); return; }
        const newList = [...list, val];
        try {
          await wlCfg.saveFn(newList);
          list = newList; inp.value = '';
          _buildWhitelistPanel(panel, list, wlCfg, platformId);
          const lbl = document.getElementById(`wl-label-${platformId}`);
          if (lbl) lbl.innerHTML = _wlLabel(wlCfg.label, newList.length);
        } catch { toast('Failed to add', 'error'); }
      });
      inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') addBtn.click(); });
      row.appendChild(sel); row.appendChild(inp); row.appendChild(addBtn);
    } else {
      // Plain input for telnyx numbers
      const inp = document.createElement('input');
      inp.type = 'text'; inp.className = 'input'; inp.style.flex = '1';
      inp.placeholder = wlCfg.addPlaceholder || '+12125550100';
      const addBtn = document.createElement('button');
      addBtn.className = 'btn btn-primary btn-sm';
      addBtn.textContent = 'Add';
      addBtn.addEventListener('click', async () => {
        const val = inp.value.replace(/[^0-9+]/g, '').trim();
        if (!val) return;
        if (list.includes(val)) { toast('Already in list', 'info'); return; }
        const newList = [...list, val];
        try {
          await wlCfg.saveFn(newList);
          list = newList; inp.value = '';
          _buildWhitelistPanel(panel, list, wlCfg, platformId);
          const lbl = document.getElementById(`wl-label-${platformId}`);
          if (lbl) lbl.innerHTML = _wlLabel(wlCfg.label, newList.length);
        } catch { toast('Failed to add', 'error'); }
      });
      inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') addBtn.click(); });
      row.appendChild(inp); row.appendChild(addBtn);
    }
    panel.appendChild(row);
  }
}

async function loadWhitelistUI() { /* replaced — whitelist is now inline in each platform card */ }

// Platform action delegation
$('#platformList').addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const { action, platform, method } = btn.dataset;

  if (action === 'connectPlatform') {
    if (method === 'config') {
      if (platform === 'telnyx')  openTelnyxConfigModal();
      if (platform === 'discord')  openDiscordConfigModal();
      if (platform === 'telegram') openTelegramConfigModal();
    } else {
      socket.emit('messaging:connect', { platform });
      toast(`Connecting to ${platform}…`, 'info');
    }
  } else if (action === 'disconnectPlatform') {
    try {
      await api('/messaging/disconnect', { method: 'POST', body: { platform } });
      loadMessagingPage();
      toast(`${platform} disconnected`, 'success');
    } catch (err) { toast(err.message, 'error'); }
  } else if (action === 'logoutPlatform') {
    try {
      await api('/messaging/logout', { method: 'POST', body: { platform } });
      loadMessagingPage();
      toast(`${platform} logged out`, 'success');
    } catch (err) { toast(err.message, 'error'); }
  }
});

$('#cancelQR').addEventListener('click', () => {
  $('#messagingQR').classList.add('hidden');
});

// ── Telnyx Config Modal ──────────────────────────────────────────────────────

async function openTelnyxConfigModal() {
  // Pre-fill from saved DB config if available
  let saved = {};
  try {
    const st = await api('/messaging/status/telnyx');
    // Config is not exposed in status; try settings instead
  } catch {}
  try {
    const s = await api('/settings');
    if (s.telnyx_config) saved = typeof s.telnyx_config === 'string' ? JSON.parse(s.telnyx_config) : s.telnyx_config;
  } catch {}

  const TTS_VOICES = ['alloy','echo','fable','onyx','nova','shimmer'];
  const TTS_MODELS = ['tts-1','tts-1-hd','gpt-4o-mini-tts'];
  const STT_MODELS = ['whisper-1','gpt-4o-transcribe'];

  const overlay = document.createElement('div');
  overlay.style.cssText = 'position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;padding:16px;';

  overlay.innerHTML = `
    <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:28px 28px 22px;max-width:480px;width:100%;max-height:90vh;overflow-y:auto;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
        <div style="font-size:1.15rem;font-weight:700;">📞 Telnyx Voice — Configuration</div>
        <button id="telnyxModalClose" style="background:none;border:none;cursor:pointer;font-size:1.4rem;color:var(--text-muted);">×</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Telnyx API Key *</label>
          <input id="telnyx_apiKey" class="input" type="password" placeholder="KEY0..." value="${escapeHtml(saved.apiKey || '')}" autocomplete="off"/>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Telnyx Phone Number * <span style="color:var(--text-muted);font-size:0.78rem;">(E.164, e.g. +12125550100)</span></label>
          <input id="telnyx_phoneNumber" class="input" type="text" placeholder="+12125550100" value="${escapeHtml(saved.phoneNumber || '')}"/>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Call Control Application ID (Connection ID) *</label>
          <input id="telnyx_connectionId" class="input" type="text" placeholder="..." value="${escapeHtml(saved.connectionId || '')}"/>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Webhook Base URL * <span style="color:var(--text-muted);font-size:0.78rem;">(public URL this server is reachable at)</span></label>
          <input id="telnyx_webhookUrl" class="input" type="text" placeholder="https://xyz.ngrok.io" value="${escapeHtml(saved.webhookUrl || '')}"/>
          <div style="font-size:0.76rem;color:var(--text-muted);margin-top:4px;">Set your Telnyx webhook to: <code style="background:var(--bg-secondary);padding:1px 5px;border-radius:4px;">&lt;URL&gt;/api/telnyx/webhook</code></div>
        </div>
        <div style="display:flex;gap:12px;">
          <div style="flex:1;">
            <label class="label" style="display:block;margin-bottom:4px;">TTS Voice</label>
            <select id="telnyx_ttsVoice" class="input" style="width:100%;">
              ${TTS_VOICES.map(v => `<option value="${v}"${(saved.ttsVoice||'alloy')===v?' selected':''}>${v}</option>`).join('')}
            </select>
          </div>
          <div style="flex:1;">
            <label class="label" style="display:block;margin-bottom:4px;">TTS Model</label>
            <select id="telnyx_ttsModel" class="input" style="width:100%;">
              ${TTS_MODELS.map(m => `<option value="${m}"${(saved.ttsModel||'tts-1')===m?' selected':''}>${m}</option>`).join('')}
            </select>
          </div>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">STT Model</label>
          <select id="telnyx_sttModel" class="input" style="width:100%;">
            ${STT_MODELS.map(m => `<option value="${m}"${(saved.sttModel||'whisper-1')===m?' selected':''}>${m}</option>`).join('')}
          </select>
          <div style="font-size:0.76rem;color:var(--text-muted);margin-top:4px;">Uses <code style="background:var(--bg-secondary);padding:1px 5px;border-radius:4px;">OPENAI_API_KEY</code> from environment for TTS + STT.</div>
        </div>
      </div>
      <div style="display:flex;gap:10px;margin-top:22px;justify-content:flex-end;">
        <button id="telnyxModalCancel" class="btn btn-secondary">Cancel</button>
        <button id="telnyxModalSave" class="btn btn-primary">Connect</button>
      </div>
    </div>`;

  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  overlay.querySelector('#telnyxModalClose').addEventListener('click', close);
  overlay.querySelector('#telnyxModalCancel').addEventListener('click', close);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

  overlay.querySelector('#telnyxModalSave').addEventListener('click', async () => {
    const config = {
      apiKey:       overlay.querySelector('#telnyx_apiKey').value.trim(),
      phoneNumber:  overlay.querySelector('#telnyx_phoneNumber').value.trim(),
      connectionId: overlay.querySelector('#telnyx_connectionId').value.trim(),
      webhookUrl:   overlay.querySelector('#telnyx_webhookUrl').value.trim(),
      ttsVoice:     overlay.querySelector('#telnyx_ttsVoice').value,
      ttsModel:     overlay.querySelector('#telnyx_ttsModel').value,
      sttModel:     overlay.querySelector('#telnyx_sttModel').value
    };
    if (!config.apiKey || !config.phoneNumber || !config.connectionId || !config.webhookUrl) {
      toast('Please fill in all required fields', 'error');
      return;
    }
    try {
      // Save config snapshot for pre-fill
      await api('/settings', { method: 'PUT', body: { telnyx_config: JSON.stringify(config) } });
      await api('/messaging/connect', { method: 'POST', body: { platform: 'telnyx', config } });
      toast('Telnyx Voice connecting…', 'success');
      close();
      setTimeout(loadMessagingPage, 1000);
    } catch (err) {
      toast('Failed to connect: ' + (err.message || err), 'error');
    }
  });
}

// ── Discord Config Modal ─────────────────────────────────────────────────────

async function openDiscordConfigModal() {
  let saved = {};
  try {
    const s = await api('/settings');
    if (s.discord_config) saved = typeof s.discord_config === 'string' ? JSON.parse(s.discord_config) : s.discord_config;
  } catch {}

  const overlay = document.createElement('div');
  overlay.style.cssText = 'position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;padding:16px;';

  overlay.innerHTML = `
    <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:28px 28px 22px;max-width:460px;width:100%;max-height:90vh;overflow-y:auto;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
        <div style="font-size:1.15rem;font-weight:700;">🎮 Discord — Configuration</div>
        <button id="discordModalClose" style="background:none;border:none;cursor:pointer;font-size:1.4rem;color:var(--text-muted);">×</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Bot Token *</label>
          <input id="discord_token" class="input" type="password" placeholder="MTxxxxxxxx..." value="${escapeHtml(saved.token || '')}" autocomplete="off"/>
          <div style="font-size:0.76rem;color:var(--text-muted);margin-top:4px;">Create a bot at <a href="https://discord.com/developers/applications" target="_blank" style="color:var(--accent);">discord.com/developers</a>. Enable <strong>Message Content</strong> privileged intent.</div>
        </div>
      </div>
      <div style="display:flex;gap:10px;margin-top:22px;justify-content:flex-end;">
        <button id="discordModalCancel" class="btn btn-secondary">Cancel</button>
        <button id="discordModalSave" class="btn btn-primary">Connect</button>
      </div>
    </div>`;

  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  overlay.querySelector('#discordModalClose').addEventListener('click', close);
  overlay.querySelector('#discordModalCancel').addEventListener('click', close);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

  overlay.querySelector('#discordModalSave').addEventListener('click', async () => {
    const config = { token: overlay.querySelector('#discord_token').value.trim() };
    if (!config.token) { toast('Bot token is required', 'error'); return; }
    try {
      await api('/settings', { method: 'PUT', body: { discord_config: JSON.stringify(config) } });
      await api('/messaging/connect', { method: 'POST', body: { platform: 'discord', config } });
      toast('Discord connecting…', 'success');
      close();
      setTimeout(loadMessagingPage, 1500);
    } catch (err) {
      toast('Failed to connect: ' + (err.message || err), 'error');
    }
  });
}

// ── Telegram Config Modal ─────────────────────────────────────────────

async function openTelegramConfigModal() {
  let saved = {};
  try {
    const s = await api('/settings');
    if (s.telegram_config) saved = typeof s.telegram_config === 'string' ? JSON.parse(s.telegram_config) : s.telegram_config;
  } catch {}

  const overlay = document.createElement('div');
  overlay.style.cssText = 'position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;padding:16px;';

  overlay.innerHTML = `
    <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:28px 28px 22px;max-width:460px;width:100%;max-height:90vh;overflow-y:auto;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
        <div style="font-size:1.15rem;font-weight:700;">✈️ Telegram — Configuration</div>
        <button id="telegramModalClose" style="background:none;border:none;cursor:pointer;font-size:1.4rem;color:var(--text-muted);">&#xD7;</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Bot Token *</label>
          <input id="telegram_token" class="input" type="password" placeholder="123456:ABCdef..." value="${escapeHtml(saved.botToken || '')}" autocomplete="off"/>
          <div style="font-size:0.76rem;color:var(--text-muted);margin-top:4px;">Get a token from <a href="https://t.me/BotFather" target="_blank" style="color:var(--accent);">@BotFather</a> on Telegram. Send the bot a message or add it to a group to start receiving messages.</div>
        </div>
      </div>
      <div style="display:flex;gap:10px;margin-top:22px;justify-content:flex-end;">
        <button id="telegramModalCancel" class="btn btn-secondary">Cancel</button>
        <button id="telegramModalSave" class="btn btn-primary">Connect</button>
      </div>
    </div>`;

  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  overlay.querySelector('#telegramModalClose').addEventListener('click', close);
  overlay.querySelector('#telegramModalCancel').addEventListener('click', close);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

  overlay.querySelector('#telegramModalSave').addEventListener('click', async () => {
    const config = { botToken: overlay.querySelector('#telegram_token').value.trim() };
    if (!config.botToken) { toast('Bot token is required', 'error'); return; }
    try {
      await api('/settings', { method: 'PUT', body: { telegram_config: JSON.stringify(config) } });
      await api('/messaging/connect', { method: 'POST', body: { platform: 'telegram', config } });
      toast('Telegram connecting…', 'success');
      close();
      setTimeout(loadMessagingPage, 1500);
    } catch (err) {
      toast('Failed to connect: ' + (err.message || err), 'error');
    }
  });
}

socket.on('messaging:qr', (data) => {
  $('#messagingQR').classList.remove('hidden');
  const container = $('#qrContainer');
  container.innerHTML = `<img src="https://api.qrserver.com/v1/create-qr-code/?data=${encodeURIComponent(data.qr)}&size=280x280" alt="QR Code">`;
});

socket.on('messaging:connected', (data) => {
  $('#messagingQR').classList.add('hidden');
  toast(`${data.platform} connected!`, 'success');
  loadMessagingPage();
});

socket.on('messaging:sent', (data) => {
  appendSocialMessage(data.platform, 'assistant', data.content, 'me');
});

socket.on('messaging:disconnected', () => loadMessagingPage());
socket.on('messaging:logged_out', () => loadMessagingPage());

socket.on('messaging:error', (data) => {
  toast((data && data.error) ? data.error : 'Messaging error', 'error');
});

socket.on('messaging:blocked_sender', (data) => {
  // Show a persistent banner so the user can see the raw ID and add it to the whitelist
  const platform = data.platform || 'whatsapp';
  const rawId = data.sender || data.chatId || 'unknown';
  const bannerId = `blocked-banner-${rawId.replace(/[^a-zA-Z0-9]/g, '')}`;
  if (document.getElementById(bannerId)) return; // don't stack duplicates

  const platformLabel = platform === 'telnyx'   ? '📞 Blocked call'
    : platform === 'discord'  ? '🎮 Blocked Discord message'
    : platform === 'telegram' ? '✈️ Blocked Telegram message'
    : '⚠ Blocked message';

  const banner = document.createElement('div');
  banner.id = bannerId;
  banner.style.cssText = 'position:fixed;bottom:80px;right:20px;z-index:9999;max-width:380px;background:var(--bg-card);border:1px solid var(--border);border-left:4px solid #f59e0b;border-radius:10px;padding:14px 16px;box-shadow:0 4px 24px rgba(0,0,0,0.25);font-size:0.86rem;';
  banner.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;">
      <div>
        <div style="font-weight:600;margin-bottom:4px;">${platformLabel}</div>
        <div style="color:var(--text-muted);margin-bottom:10px;">${platform === 'telnyx' ? 'From' : 'Sender'}: <code style="font-size:0.82rem;background:var(--bg-secondary);padding:1px 6px;border-radius:4px;">${escapeHtml(rawId)}</code>${data.senderName ? ` &mdash; ${escapeHtml(data.senderName)}` : ''}${data.meta ? ` <span style="font-size:0.78rem;">(${escapeHtml(data.meta)})</span>` : ''}</div>
        <div style="display:flex;flex-wrap:wrap;gap:8px;" id="wb-btns-${bannerId}">
          ${(data.suggestions && data.suggestions.length
            ? data.suggestions.map((s, i) =>
                `<button class="btn btn-sm btn-primary" id="wb-sug-${bannerId}-${i}" data-pid="${escapeHtml(s.prefixedId)}">${escapeHtml(s.label)}</button>`
              ).join('')
            : `<button class="btn btn-sm btn-primary" id="wb-add-${bannerId}">Add to whitelist</button>`
          )}
          <button class="btn btn-sm btn-secondary" id="wb-dismiss-${bannerId}">Dismiss</button>
        </div>
      </div>
    </div>`;

  document.body.appendChild(banner);

  document.getElementById(`wb-dismiss-${bannerId}`).addEventListener('click', () => banner.remove());

  // Helper: add a prefixed/plain ID to a platform whitelist, refresh cards
  async function _wbSave(platform, entryKey) {
    if (platform === 'telnyx') {
      const s = await api('/settings');
      let list = [];
      try { list = JSON.parse(s.platform_whitelist_telnyx || '[]'); if (!Array.isArray(list)) list = []; } catch { list = []; }
      if (!list.includes(entryKey)) list.push(entryKey);
      await api('/messaging/telnyx/whitelist', { method: 'PUT', body: { numbers: list } });
    } else if (platform === 'discord') {
      const s = await api('/settings');
      let list = [];
      try { list = JSON.parse(s.platform_whitelist_discord || '[]'); if (!Array.isArray(list)) list = []; } catch { list = []; }
      const prefixed = entryKey.includes(':') ? entryKey : `user:${entryKey}`;
      if (!list.includes(prefixed)) list.push(prefixed);
      await api('/messaging/discord/whitelist', { method: 'PUT', body: { ids: list } });
    } else if (platform === 'telegram') {
      const s = await api('/settings');
      let list = [];
      try { list = JSON.parse(s.platform_whitelist_telegram || '[]'); if (!Array.isArray(list)) list = []; } catch { list = []; }
      const prefixed = entryKey.includes(':') ? entryKey : `user:${entryKey}`;
      if (!list.includes(prefixed)) list.push(prefixed);
      await api('/messaging/telegram/whitelist', { method: 'PUT', body: { ids: list } });
    } else {
      // whatsapp
      const s = await api('/settings');
      let list = [];
      try { list = JSON.parse(s.platform_whitelist_whatsapp || '[]'); if (!Array.isArray(list)) list = []; } catch { list = []; }
      if (!list.includes(entryKey)) list.push(entryKey);
      await api('/settings', { method: 'PUT', body: { platform_whitelist_whatsapp: JSON.stringify(list) } });
    }
  }

  // Wire suggestion buttons (Discord) or the single Add button (other platforms)
  if (data.suggestions && data.suggestions.length) {
    data.suggestions.forEach((s, i) => {
      const btn = document.getElementById(`wb-sug-${bannerId}-${i}`);
      if (!btn) return;
      btn.addEventListener('click', async () => {
        try {
          await _wbSave(platform, s.prefixedId);
          toast(`Added ${s.prefixedId} to whitelist`, 'success');
          banner.remove();
          if (document.querySelector('#page-messaging.active')) loadMessagingPage();
        } catch (err) { toast('Failed to save: ' + err.message, 'error'); }
      });
    });
  } else {
    const addBtn = document.getElementById(`wb-add-${bannerId}`);
    if (addBtn) addBtn.addEventListener('click', async () => {
      const digits = rawId.replace(/[^0-9]/g, '');
      const key = digits || rawId;
      try {
        await _wbSave(platform, key);
        toast(`Added ${key} to whitelist`, 'success');
        banner.remove();
        if (document.querySelector('#page-messaging.active')) loadMessagingPage();
      } catch (err) {
        toast('Failed to save: ' + err.message, 'error');
      }
    });
  }
});

// ── Browser Page (removed - integrated into flow) ──

// ── Init ──

// model is fixed: grok-4-1-fast-reasoning; nothing to load here

// ── Protocols ──
let currentProtocolId = null;

async function loadProtocolsPage() {
  try {
    const res = await fetch('/api/protocols');
    if (!res.ok) throw new Error('Failed to load protocols');
    const protocols = await res.json();
    renderProtocolsList(protocols);
  } catch (err) {
    console.error(err);
  }
}

function renderProtocolsList(protocols) {
  const container = $('#protocolsList');
  if (protocols.length === 0) {
    container.innerHTML = '<div class="empty-state">No protocols found. Create one.</div>';
    return;
  }
  container.className = 'protocols-list';
  container.innerHTML = protocols.map(p => `
    <div class="item-card">
      <div class="item-card-header">
        <div class="item-card-title" style="font-size: 16px;">${p.name}</div>
        <div class="item-card-actions">
          <button class="btn-icon" onclick="editProtocol(${p.id})" title="Edit">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="btn-icon text-red" onclick="deleteProtocol(${p.id})" title="Delete">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
          </button>
        </div>
      </div>
      <div class="item-card-meta mb-2" style="font-size: 14px; margin-bottom: 8px;">
        ${p.description || 'No description'}
      </div>
    </div>
  `).join('');
}

$('#closeProtocolModal')?.addEventListener('click', () => $('#protocolModal')?.classList.add('hidden'));
$('#cancelProtocolModal')?.addEventListener('click', () => $('#protocolModal')?.classList.add('hidden'));

$('#addProtocolBtn')?.addEventListener('click', () => {
  currentProtocolId = null;
  $('#protocolModalTitle').textContent = 'Add Protocol';
  $('#protocolName').value = '';
  $('#protocolDesc').value = '';
  $('#protocolContent').value = '';
  $('#protocolModal')?.classList.remove('hidden');
});

$('#saveProtocolBtn').addEventListener('click', async () => {
  const name = $('#protocolName').value.trim();
  const description = $('#protocolDesc').value.trim();
  const content = $('#protocolContent').value.trim();
  
  if (!name || !content) {
    alert('Name and Content are required');
    return;
  }
  
  const payload = { name, description, content };
  const method = currentProtocolId ? 'PUT' : 'POST';
  const url = currentProtocolId ? `/api/protocols/${currentProtocolId}` : '/api/protocols';
  
  try {
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Failed to save: ' + res.status);
    }
    $('#protocolModal')?.classList.add('hidden');
    loadProtocolsPage();
  } catch (err) {
    alert(err.message);
  }
});

async function editProtocol(id) {
  try {
    const res = await fetch(`/api/protocols/${id}`);
    if (!res.ok) throw new Error('Failed to load protocol');
    const p = await res.json();
    
    currentProtocolId = p.id;
    $('#protocolModalTitle').textContent = 'Edit Protocol';
    $('#protocolName').value = p.name;
    $('#protocolDesc').value = p.description || '';
    $('#protocolContent').value = p.content;
    $('#protocolModal')?.classList.remove('hidden');
  } catch (err) {
    alert(err.message);
  }
}

async function deleteProtocol(id) {
  if (!confirm('Are you sure you want to delete this protocol?')) return;
  try {
    const res = await fetch(`/api/protocols/${id}`, { method: 'DELETE' });
    if (!res.ok) throw new Error('Failed to delete protocol');
    loadProtocolsPage();
  } catch (err) {
    alert(err.message);
  }
}

window.editProtocol = editProtocol;
window.deleteProtocol = deleteProtocol;

