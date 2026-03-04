// ── NeoAgent App ──

const socket = io();
let isStreaming = false;

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
  if (page === 'activity') requestAnimationFrame(ensureCanvas);
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

// ── Activity Canvas ──

class ActivityCanvas {
  constructor(viewport) {
    this.vp = viewport;
    this.world = null;
    this.svg = null;
    this.tx = 0; this.ty = 40; this.zoom = 1;
    this.dragging = false;
    this.lastMX = 0; this.lastMY = 0;
    this.nodes = new Map();   // stepId -> { el, x, y, w, h }
    this.edges = [];           // [{from, to}]
    this.branchNextY = 0;
    this.branchPrevStep = null;
    this.NODE_W = 360;
    this.NODE_H_MIN = 80;
    this.GAP_Y = 56;
  }

  init() {
    this.vp.innerHTML = '';

    // World layer (cards) – transforms with pan/zoom
    this.world = document.createElement('div');
    Object.assign(this.world.style, {
      position: 'absolute', top: '0', left: '0',
      transformOrigin: '0 0',
    });
    this.vp.appendChild(this.world);

    // SVG connector layer – same transform as world
    this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    Object.assign(this.svg.style, {
      position: 'absolute', top: '0', left: '0',
      width: '1px', height: '1px',
      overflow: 'visible', pointerEvents: 'none',
      transformOrigin: '0 0',
    });
    this.vp.appendChild(this.svg);

    this._center();
    this._bindEvents();
  }

  _center() {
    const vw = this.vp.clientWidth || 800;
    this.tx = Math.max(20, (vw - this.NODE_W) / 2);
    this.ty = 40;
    this._transform();
  }

  _transform() {
    const t = `translate(${this.tx}px,${this.ty}px) scale(${this.zoom})`;
    this.world.style.transform = t;
    this.svg.style.transform = t;
  }

  _bindEvents() {
    this.vp.addEventListener('mousedown', e => {
      if (e.button !== 0) return;
      this.dragging = true;
      this.lastMX = e.clientX; this.lastMY = e.clientY;
      this.vp.style.cursor = 'grabbing';
    });
    window.addEventListener('mousemove', e => {
      if (!this.dragging) return;
      this.tx += e.clientX - this.lastMX;
      this.ty += e.clientY - this.lastMY;
      this.lastMX = e.clientX; this.lastMY = e.clientY;
      this._transform();
    });
    window.addEventListener('mouseup', () => {
      this.dragging = false;
      this.vp.style.cursor = 'grab';
    });
    this.vp.addEventListener('wheel', e => {
      e.preventDefault();
      const f = e.deltaY < 0 ? 1.1 : 0.9;
      const rect = this.vp.getBoundingClientRect();
      const cx = e.clientX - rect.left;
      const cy = e.clientY - rect.top;
      this.tx = cx - (cx - this.tx) * f;
      this.ty = cy - (cy - this.ty) * f;
      this.zoom = Math.max(0.15, Math.min(3, this.zoom * f));
      this._transform();
    }, { passive: false });
  }

  addNode(stepId, toolName, toolArgs) {
    // Hide empty state
    const empty = $('#activityEmpty');
    if (empty) empty.style.display = 'none';

    const meta = getToolMeta(toolName);
    const desc = describeArgs(toolName, toolArgs);
    const x = 0;
    const y = this.branchNextY;

    const el = document.createElement('div');
    el.className = `ac-node color-${meta.color}`;
    el.id = `ac-node-${stepId}`;
    el.style.cssText = `left:${x}px;top:${y}px;width:${this.NODE_W}px;`;
    el.innerHTML = `
      <div class="ac-header">
        <span class="ac-icon">${meta.icon}</span>
        <span class="ac-label">${escapeHtml(meta.label)}</span>
        <span class="ac-chip running" id="ac-status-${stepId}">working</span>
      </div>
      ${desc ? `<div class="ac-primary">${escapeHtml((desc.headline || '').slice(0, 220))}</div>
      ${desc.detail ? `<div class="ac-detail">${escapeHtml(desc.detail)}</div>` : ''}` : ''}
      <div class="ac-result hidden" id="ac-result-${stepId}"></div>`;

    // URL chip for browser navigation
    if ((toolName === 'browser_navigate' || toolName === 'browser_evaluate') && toolArgs?.url) {
      const chip = document.createElement('a');
      chip.className = 'ac-url-chip';
      chip.href = toolArgs.url;
      chip.target = '_blank';
      chip.rel = 'noopener noreferrer';
      const u = toolArgs.url;
      chip.textContent = u.length > 60 ? u.slice(0, 60) + '…' : u;
      el.querySelector('.ac-primary')?.before(chip) || el.appendChild(chip);
    }

    this.world.appendChild(el);

    // Measure real height now that it's in the DOM
    const h = el.offsetHeight || this.NODE_H_MIN;
    this.nodes.set(stepId, { el, x, y, w: this.NODE_W, h });

    // Watch for height changes (content expanding) and reflow downstream nodes
    const ro = new ResizeObserver(() => this._reflow(stepId));
    ro.observe(el);
    this.nodes.get(stepId).ro = ro;

    if (this.branchPrevStep) {
      this.edges.push([this.branchPrevStep, stepId]);
      this._drawEdge(this.branchPrevStep, stepId);
    }
    this.branchPrevStep = stepId;
    this.branchNextY = y + h + this.GAP_Y;

    // Animate in AFTER layout is set
    el.style.opacity = '0';
    el.style.transform = 'translateY(12px)';
    requestAnimationFrame(() => {
      el.style.transition = 'opacity 0.25s ease, transform 0.25s ease';
      el.style.opacity = '1';
      el.style.transform = 'translateY(0)';
    });

    this._scrollTo(x, y + h);
    return el;
  }

  updateNode(stepId, toolName, result, screenshotPath, status) {
    const info = this.nodes.get(stepId);
    if (!info) return;

    const statusEl = document.getElementById(`ac-status-${stepId}`);
    if (statusEl) {
      statusEl.className = `ac-chip ${status}`;
      statusEl.textContent = status === 'completed' ? 'done' : 'failed';
    }

    const resultEl = document.getElementById(`ac-result-${stepId}`);
    if (!resultEl) return;
    resultEl.classList.remove('hidden');

    if (screenshotPath) {
      const wrap = document.createElement('div');
      wrap.className = 'ac-screenshot-wrap';
      const a = document.createElement('a');
      a.href = screenshotPath; a.target = '_blank'; a.rel = 'noopener noreferrer';
      a.title = 'Open full screenshot';
      const img = document.createElement('img');
      img.className = 'ac-screenshot';
      img.src = screenshotPath; img.alt = ''; img.loading = 'lazy';
      img.onload = () => this._reflow(stepId);
      a.appendChild(img);
      wrap.appendChild(a);
      resultEl.appendChild(wrap);
    }

    const rd = describeResult(toolName, result);
    if (rd?.text) {
      const d = document.createElement('div');
      d.className = rd.type === 'code' ? 'ac-code' : rd.type === 'error' ? 'ac-text error' : rd.type === 'success' ? 'ac-success' : 'ac-text';
      d.textContent = rd.text;
      resultEl.appendChild(d);
    }
    if (rd?.meta) {
      const m = document.createElement('div');
      if (rd.statusClass) {
        m.className = `ac-status-badge ${rd.statusClass}`;
      } else {
        m.className = `ac-meta${rd.type === 'error' ? ' error' : ''}`;
      }
      m.textContent = rd.meta;
      resultEl.prepend(m);
    }

    setTimeout(() => this._reflow(stepId), 60);
  }

  addResponse(content) {
    if (!content) return;
    const y = this.branchNextY;
    const el = document.createElement('div');
    el.className = 'ac-node ac-response';
    el.style.cssText = `left:0px;top:${y}px;width:${this.NODE_W}px;`;
    el.innerHTML = `
      <div class="ac-header">
        <span class="ac-icon">✅</span>
        <span class="ac-label">Response</span>
      </div>
      <div class="ac-response-body md-content">${renderMarkdown(content)}</div>`;
    this.world.appendChild(el);

    el.style.opacity = '0';
    el.style.transform = 'translateY(12px)';
    requestAnimationFrame(() => {
      el.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
      el.style.opacity = '1';
      el.style.transform = 'translateY(0)';
    });

    const tempH = el.offsetHeight || 100;
    const fakeId = `__response_${Date.now()}`;
    this.nodes.set(fakeId, { el, x: 0, y, w: this.NODE_W, h: tempH });

    if (this.branchPrevStep) {
      this.edges.push([this.branchPrevStep, fakeId]);
      this._drawEdge(this.branchPrevStep, fakeId);
    }
    this.branchPrevStep = fakeId;
    this.branchNextY = y + tempH + this.GAP_Y;

    el.style.opacity = '0';
    el.style.transform = 'translateY(12px)';
    requestAnimationFrame(() => {
      el.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
      el.style.opacity = '1';
      el.style.transform = 'translateY(0)';
    });

    setTimeout(() => this._reflow(fakeId), 80);
    this._scrollTo(0, y);
  }

  _reflow(stepId) {
    const info = this.nodes.get(stepId);
    if (!info) return;
    const newH = info.el.offsetHeight;
    if (newH <= info.h) return;
    const diff = newH - info.h;
    info.h = newH;
    // Push all nodes and branchNextY that sit below this one
    let maxY = 0;
    for (const [, n] of this.nodes) {
      if (n.y > info.y) {
        n.y += diff;
        n.el.style.top = `${n.y}px`;
      }
      maxY = Math.max(maxY, n.y + n.h);
    }
    this.branchNextY = maxY + this.GAP_Y;
    this._redrawEdges();
  }

  _drawEdge(fromId, toId) {
    const a = this.nodes.get(fromId);
    const b = this.nodes.get(toId);
    if (!a || !b) return;
    const x1 = a.x + a.w / 2, y1 = a.y + a.h;
    const x2 = b.x + b.w / 2, y2 = b.y;
    const mid = (y1 + y2) / 2;
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', `M${x1},${y1} C${x1},${mid} ${x2},${mid} ${x2},${y2}`);
    path.setAttribute('fill', 'none');
    path.setAttribute('stroke', 'var(--border)');
    path.setAttribute('stroke-width', '2');
    path.setAttribute('stroke-linecap', 'round');
    path.dataset.from = fromId; path.dataset.to = toId;
    this.svg.appendChild(path);
  }

  _redrawEdges() {
    while (this.svg.firstChild) this.svg.removeChild(this.svg.firstChild);
    for (const [from, to] of this.edges) this._drawEdge(from, to);
  }

  _scrollTo(x, y) {
    const vh = this.vp.clientHeight || 600;
    const screenY = y * this.zoom + this.ty;
    const margin = 80;
    if (screenY > vh - margin) {
      this.ty -= screenY - (vh - margin);
      this._transform();
    }
  }

  fitView() {
    if (!this.nodes.size) return;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const [, n] of this.nodes) {
      minX = Math.min(minX, n.x); minY = Math.min(minY, n.y);
      maxX = Math.max(maxX, n.x + n.w); maxY = Math.max(maxY, n.y + n.h);
    }
    const pad = 60;
    const vw = this.vp.clientWidth, vh = this.vp.clientHeight;
    const cw = maxX - minX + pad * 2, ch = maxY - minY + pad * 2;
    this.zoom = Math.min(1, vw / cw, vh / ch);
    this.tx = (vw - cw * this.zoom) / 2 + pad * this.zoom - minX * this.zoom;
    this.ty = (vh - ch * this.zoom) / 2 + pad * this.zoom - minY * this.zoom;
    this._transform();
  }

  clear() {
    for (const [, n] of this.nodes) { if (n.ro) n.ro.disconnect(); }
    this.nodes.clear(); this.edges = [];
    this.branchNextY = 0; this.branchPrevStep = null;
    if (this.world) this.world.innerHTML = '';
    if (this.svg) while (this.svg.firstChild) this.svg.removeChild(this.svg.firstChild);
    const empty = $('#activityEmpty');
    if (empty) empty.style.display = '';
    this._center();
  }
}

let activityCanvas = null;

function ensureCanvas() {
  if (activityCanvas) return;
  const wrap = document.getElementById('activityCanvasWrap');
  if (!wrap) return;
  activityCanvas = new ActivityCanvas(wrap);
  activityCanvas.init();
}

function addActivityNode(stepId, toolName, toolArgs) {
  ensureCanvas();
  activityCanvas.addNode(stepId, toolName, toolArgs);
  const badge = $('#activityBadge');
  if (badge) badge.classList.remove('hidden');
}

function updateActivityNode(stepId, toolName, result, screenshotPath, status) {
  if (activityCanvas) activityCanvas.updateNode(stepId, toolName, result, screenshotPath, status);
}

function addActivityResponse(content) {
  ensureCanvas();
  if (content) activityCanvas.addResponse(content);
}

function clearActivity() {
  if (activityCanvas) activityCanvas.clear();
  else {
    const empty = $('#activityEmpty');
    if (empty) empty.style.display = '';
  }
  const badge = $('#activityBadge');
  if (badge) badge.classList.add('hidden');
}

$('#clearActivityBtn').addEventListener('click', clearActivity);
$('#fitViewBtn').addEventListener('click', () => activityCanvas?.fitView());

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
    ensureCanvas();
    for (const step of (data.steps || [])) {
      let toolInput = {};
      let result = null;
      try { toolInput = step.tool_input ? JSON.parse(step.tool_input) : {}; } catch {}
      try { result = step.result ? JSON.parse(step.result) : null; } catch {}
      activityCanvas.addNode(step.id, step.tool_name, toolInput);
      activityCanvas.updateNode(step.id, step.tool_name, result, step.screenshot_path || null, step.status);
    }
    if (data.response) activityCanvas.addResponse(data.response);
    setTimeout(() => activityCanvas?.fitView(), 100);
    const badge = $('#activityBadge');
    if (badge) badge.classList.remove('hidden');
  } catch (err) { toast('Failed to load run: ' + err.message, 'error'); }
}

// ── Socket Events ──

socket.on('run:thinking', (data) => {
  const textEl = $('#thinkingText');
  if (textEl) textEl.textContent = `Thinking… (step ${data.iteration})`;
});

socket.on('run:tool_start', (data) => {
  addActivityNode(data.stepId, data.toolName, data.toolArgs);
  const textEl = $('#thinkingText');
  if (textEl) textEl.textContent = `${data.toolName}…`;
});

socket.on('run:tool_end', (data) => {
  updateActivityNode(data.stepId, data.toolName, data.result, data.screenshotPath, data.status);
});

socket.on('run:stream', (data) => {
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

  isStreaming = false;
  sendBtn.disabled = false;
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
  ensureCanvas();
  const stepId = `msg-${Date.now()}`;
  activityCanvas.addNode(stepId, 'send_message', { platform: data.platform, to: data.chatId, content: data.content });
  activityCanvas.updateNode(stepId, 'send_message', { received: true, from: data.senderName }, null, 'completed');
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

async function loadMemoryPage() {
  try {
    const data = await api('/memory');
    $('#memoryEditor').value = data.memory || '';
    $('#soulEditor').value = data.soul || '';

    const dailyContainer = $('#dailyLogs');
    dailyContainer.innerHTML = '';
    for (const log of (data.dailyLogs || [])) {
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `<div class="item-card-header"><div class="item-card-title">${escapeHtml(log.date)}</div></div><pre class="code-block">${escapeHtml(log.content || 'Empty')}</pre>`;
      dailyContainer.appendChild(card);
    }

    const keyContainer = $('#apiKeyList');
    keyContainer.innerHTML = '';
    const keys = await api('/memory/api-keys');
    for (const [name, masked] of Object.entries(keys)) {
      const card = document.createElement('div');
      card.className = 'item-card flex justify-between items-center';
      card.innerHTML = `<div><div class="item-card-title">${escapeHtml(name)}</div><div class="item-card-meta font-mono">${escapeHtml(masked)}</div></div>
        <button class="btn btn-sm btn-danger" data-action="deleteApiKey" data-name="${escapeHtml(name)}">&times;</button>`;
      keyContainer.appendChild(card);
    }
  } catch (err) {
    toast('Failed to load memory', 'error');
  }
}

// Memory tab switching
$$('[data-mem-tab]').forEach(tab => {
  tab.addEventListener('click', () => {
    $$('[data-mem-tab]').forEach(t => t.classList.remove('active'));
    $$('.mem-panel').forEach(p => p.classList.remove('active'));
    tab.classList.add('active');
    $(`#mem-${tab.dataset.memTab}`).classList.add('active');
  });
});

$('#saveMemoryBtn').addEventListener('click', async () => {
  try {
    await api('/memory/memory', { method: 'PUT', body: { content: $('#memoryEditor').value } });
    toast('Memory saved', 'success');
  } catch (err) { toast('Failed to save', 'error'); }
});

$('#saveSoulBtn').addEventListener('click', async () => {
  try {
    await api('/memory/soul', { method: 'PUT', body: { content: $('#soulEditor').value } });
    toast('Soul saved', 'success');
  } catch (err) { toast('Failed to save', 'error'); }
});

window.deleteApiKey = async (name) => {
  try {
    await api(`/memory/api-keys/${name}`, { method: 'DELETE' });
    loadMemoryPage();
    toast('Key deleted', 'success');
  } catch (err) { toast('Failed to delete', 'error'); }
};

// Event delegation for memory page
document.addEventListener('click', e => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const action = btn.dataset.action;
  if (action === 'deleteApiKey') window.deleteApiKey(btn.dataset.name);
});

$('#addApiKeyBtn').addEventListener('click', () => {
  const name = prompt('Service name:');
  if (!name) return;
  const key = prompt('API key value:');
  if (!key) return;
  api(`/memory/api-keys/${name}`, { method: 'PUT', body: { key } })
    .then(() => { loadMemoryPage(); toast('Key added', 'success'); })
    .catch(() => toast('Failed to add key', 'error'));
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
const MESSAGING_PLATFORMS = [
  { id: 'whatsapp', name: 'WhatsApp',    icon: '💬', color: '#25d366', connectMethod: 'qr'     },
  { id: 'telnyx',   name: 'Telnyx Voice',icon: '📞', color: '#00C8A0', connectMethod: 'config' },
  { id: 'discord',  name: 'Discord',     icon: '🎮', color: '#5865F2', connectMethod: 'config' },
];

async function loadMessagingPage() {
  try {
    const statuses = await api('/messaging/status');
    const container = $('#platformList');
    container.innerHTML = '';

    for (const platform of MESSAGING_PLATFORMS) {
      const info = statuses[platform.id] || { status: 'not_configured' };
      const isConnected = info.status === 'connected';
      const isConnecting = info.status === 'connecting' || info.status === 'awaiting_qr';

      const card = document.createElement('div');
      card.className = 'card mb-4';
      card.innerHTML = `
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div style="font-size:2rem;line-height:1;">${platform.icon}</div>
            <div>
              <div class="item-card-title">${escapeHtml(platform.name)}</div>
              <div class="flex items-center gap-2 mt-1">
                <span class="badge ${isConnected ? 'badge-success' : isConnecting ? 'badge-neutral' : 'badge-neutral'}">
                  ${escapeHtml(info.status.replace(/_/g, ' '))}
                </span>
                ${info.lastConnected ? `<span class="text-xs text-muted">last connected ${formatTime(info.lastConnected)}</span>` : ''}
                ${isConnected && info.authInfo?.phoneNumber ? `<span class="text-xs text-muted">${escapeHtml(info.authInfo.phoneNumber)}</span>` : ''}
              ${isConnected && info.authInfo?.tag ? `<span class="text-xs text-muted">${escapeHtml(info.authInfo.tag)}</span>` : ''}
              </div>
            </div>
          </div>
          <div class="flex gap-2">
            ${isConnected
              ? `<button class="btn btn-sm btn-secondary" data-action="disconnectPlatform" data-platform="${platform.id}">Disconnect</button>
                 <button class="btn btn-sm btn-danger" data-action="logoutPlatform" data-platform="${platform.id}">Logout</button>`
              : isConnecting
                ? `<span class="text-muted text-sm">Connecting…</span>`
                : `<button class="btn btn-sm btn-primary" data-action="connectPlatform" data-platform="${platform.id}" data-method="${platform.connectMethod}">Connect</button>`
            }
          </div>
        </div>
      `;
      container.appendChild(card);
    }
    // Also render whitelist cards below platform list
    await loadWhitelistUI();
  } catch (err) {
    toast('Failed to load messaging', 'error');
  }

}

async function loadWhitelistUI() {
  const wrap = $('#whitelistSection');
  if (!wrap) return;
  wrap.innerHTML = '';

  // WhatsApp whitelist
  await _renderWhitelistCard(wrap, {
    settingKey: 'platform_whitelist_whatsapp',
    title: 'WhatsApp Whitelist',
    meta: 'Blocked senders trigger an allow popup. Add numbers here to pre-approve contacts.',
    saveFn: async (list) => {
      await api('/settings', { method: 'PUT', body: { platform_whitelist_whatsapp: JSON.stringify(list) } });
    }
  });

  // Telnyx whitelist
  await _renderWhitelistCard(wrap, {
    settingKey: 'platform_whitelist_telnyx',
    title: 'Telnyx Voice Whitelist',
    meta: 'Calls from numbers not on this list will be rejected. Leave empty to allow all inbound calls.',
    saveFn: async (list) => {
      await api('/messaging/telnyx/whitelist', { method: 'PUT', body: { numbers: list } });
    }
  });

  // Discord whitelist
  await _renderWhitelistCard(wrap, {
    settingKey: 'platform_whitelist_discord',
    title: 'Discord Whitelist',
    meta: 'Messages from user/server IDs not on this list trigger an allow popup. Leave empty to allow everyone.',
    placeholder: 'Discord user or server (guild) ID',
    saveFn: async (list) => {
      await api('/messaging/discord/whitelist', { method: 'PUT', body: { ids: list } });
    }
  });
}

async function _renderWhitelistCard(wrap, { settingKey, title, meta, placeholder, saveFn }) {
  let numbers = [];
  try {
    const settings = await api('/settings');
    const raw = settings[settingKey];
    if (raw) numbers = typeof raw === 'string' ? JSON.parse(raw) : raw;
  } catch { /* leave empty */ }

  const container = document.createElement('div');
  wrap.appendChild(container);

  function renderNumbers() {
    container.innerHTML = '';
    const card = document.createElement('div');
    card.className = 'card mb-4';

    const header = document.createElement('div');
    header.className = 'flex items-center justify-between mb-3';
    header.innerHTML = `
      <div>
        <div class="item-card-title">${escapeHtml(title)}</div>
        <div class="item-card-meta">${escapeHtml(meta)}</div>
      </div>`;
    card.appendChild(header);

    const tags = document.createElement('div');
    tags.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin-bottom:12px;min-height:32px;';
    for (const num of numbers) {
      const tag = document.createElement('span');
      tag.style.cssText = 'display:inline-flex;align-items:center;gap:6px;background:var(--bg-secondary);border:1px solid var(--border);border-radius:999px;padding:3px 12px;font-size:0.85rem;';
      tag.innerHTML = `${escapeHtml(num)} <button style="background:none;border:none;cursor:pointer;color:var(--text-muted);padding:0;font-size:1rem;line-height:1;" data-remove="${escapeHtml(num)}">×</button>`;
      tag.querySelector('button').addEventListener('click', async () => {
        numbers = numbers.filter(n => n !== num);
        await doSave(numbers);
        renderNumbers();
      });
      tags.appendChild(tag);
    }
    if (!numbers.length) {
      const empty = document.createElement('span');
      empty.className = 'text-muted text-sm';
      empty.textContent = 'No whitelist active — all allowed';
      tags.appendChild(empty);
    }
    card.appendChild(tags);

    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px;';
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.className = 'input';
    inp.placeholder = placeholder || 'e.g. +447911123456 or 15550000000';
    inp.style.flex = '1';
    const addBtn = document.createElement('button');
    addBtn.className = 'btn btn-primary btn-sm';
    addBtn.textContent = 'Add';
    addBtn.addEventListener('click', async () => {
      const val = inp.value.replace(/[^0-9]/g, '').trim();
      if (!val) return;
      if (numbers.includes(val)) { toast('Already in list', 'info'); return; }
      numbers.push(val);
      await doSave(numbers);
      inp.value = '';
      renderNumbers();
    });
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') addBtn.click(); });
    row.appendChild(inp);
    row.appendChild(addBtn);
    card.appendChild(row);

    container.appendChild(card);
  }

  async function doSave(list) {
    try {
      await saveFn(list);
      toast('Whitelist saved', 'success');
    } catch (err) { toast('Failed to save whitelist', 'error'); }
  }

  renderNumbers();
}

// Platform action delegation
$('#platformList').addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const { action, platform, method } = btn.dataset;

  if (action === 'connectPlatform') {
    if (method === 'config') {
      if (platform === 'telnyx')  openTelnyxConfigModal();
      if (platform === 'discord') openDiscordConfigModal();
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

  const platformLabel = platform === 'telnyx' ? '📞 Blocked call'
    : platform === 'discord' ? '🎮 Blocked Discord message'
    : '⚠ Blocked message';

  const banner = document.createElement('div');
  banner.id = bannerId;
  banner.style.cssText = 'position:fixed;bottom:80px;right:20px;z-index:9999;max-width:380px;background:var(--bg-card);border:1px solid var(--border);border-left:4px solid #f59e0b;border-radius:10px;padding:14px 16px;box-shadow:0 4px 24px rgba(0,0,0,0.25);font-size:0.86rem;';
  banner.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;">
      <div>
        <div style="font-weight:600;margin-bottom:4px;">${platformLabel}</div>
        <div style="color:var(--text-muted);margin-bottom:10px;">${platform === 'telnyx' ? 'From' : 'Sender'}: <code style="font-size:0.82rem;background:var(--bg-secondary);padding:1px 6px;border-radius:4px;">${escapeHtml(rawId)}</code>${data.senderName ? ` &mdash; ${escapeHtml(data.senderName)}` : ''}${data.meta ? ` <span style="font-size:0.78rem;">(${escapeHtml(data.meta)})</span>` : ''}</div>
        <div style="display:flex;gap:8px;">
          <button class="btn btn-sm btn-primary" id="wb-add-${bannerId}">Add to whitelist</button>
          <button class="btn btn-sm btn-secondary" id="wb-dismiss-${bannerId}">Dismiss</button>
        </div>
      </div>
    </div>`;

  document.body.appendChild(banner);

  document.getElementById(`wb-dismiss-${bannerId}`).addEventListener('click', () => banner.remove());

  document.getElementById(`wb-add-${bannerId}`).addEventListener('click', async () => {
    const digits = rawId.replace(/[^0-9]/g, '');
    const key = digits || rawId;
    try {
      if (platform === 'telnyx') {
        const settings = await api('/settings');
        let list = [];
        try {
          const raw = settings.platform_whitelist_telnyx;
          if (Array.isArray(raw)) list = raw;
          else if (typeof raw === 'string') list = JSON.parse(raw);
          if (!Array.isArray(list)) list = [];
        } catch { list = []; }
        if (!list.includes(key)) list.push(key);
        await api('/messaging/telnyx/whitelist', { method: 'PUT', body: { numbers: list } });
      } else if (platform === 'discord') {
        const settings = await api('/settings');
        let list = [];
        try {
          const raw = settings.platform_whitelist_discord;
          if (Array.isArray(raw)) list = raw;
          else if (typeof raw === 'string') list = JSON.parse(raw);
          if (!Array.isArray(list)) list = [];
        } catch { list = []; }
        if (!list.includes(key)) list.push(key);
        await api('/messaging/discord/whitelist', { method: 'PUT', body: { ids: list } });
      } else {
        const settings = await api('/settings');
        let list = [];
        try {
          const raw = settings.platform_whitelist_whatsapp;
          if (Array.isArray(raw)) list = raw;
          else if (typeof raw === 'string') list = JSON.parse(raw);
          if (!Array.isArray(list)) list = [];
        } catch { list = []; }
        if (!list.includes(key)) {
          list.push(key);
          await api('/settings', { method: 'PUT', body: { platform_whitelist_whatsapp: JSON.stringify(list) } });
        }
      }
      toast(`Added ${key} to whitelist`, 'success');
      banner.remove();
      // Refresh whitelist UI if already on messaging page
      if (document.querySelector('#page-messaging.active')) await loadWhitelistUI();
    } catch (err) {
      toast('Failed to save: ' + err.message, 'error');
    }
  });
});

// ── Browser Page (removed - integrated into flow) ──

// ── Init ──

// model is fixed: grok-4-1-fast-reasoning; nothing to load here

