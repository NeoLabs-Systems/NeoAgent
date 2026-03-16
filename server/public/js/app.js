// ── NeoAgent App ──

// Init mermaid if available
if (window.mermaid) {
  mermaid.initialize({ startOnLoad: false, theme: "dark" });
}

// ── Theme (follows OS preference automatically) ──

function applyTheme(isDark) {
  document.documentElement.dataset.theme = isDark ? "dark" : "light";
  if (window.mermaid) {
    mermaid.initialize({ startOnLoad: false, theme: isDark ? "dark" : "default" });
  }
  if (window.pixelWorld) {
    window.pixelWorld.syncTheme();
  }
}

const _mq = window.matchMedia("(prefers-color-scheme: dark)");
applyTheme(_mq.matches);
_mq.addEventListener("change", (e) => applyTheme(e.matches));



// Global utility to re-run mermaid
function renderMermaids() {
  if (window.mermaid) {
    try {
      mermaid.init(undefined, $$(".mermaid"));
    } catch (e) {
      console.error("Mermaid render error", e);
    }
  }
}

const socket = io();
let isStreaming = false;
const backgroundRunIds = new Set(); // tracks scheduler/heartbeat run IDs

// ── Utility ──

function $(sel) {
  return document.querySelector(sel);
}
function $$(sel) {
  return document.querySelectorAll(sel);
}

function toast(message, type = "info") {
  const container = $("#toasts");
  const el = document.createElement("div");
  el.className = `toast toast-${type}`;
  el.textContent = message;
  container.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

async function api(path, opts = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { "Content-Type": "application/json", ...opts.headers },
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });

  const contentType = (res.headers.get("content-type") || "").toLowerCase();
  let data = null;
  if (contentType.includes("application/json")) {
    data = await res.json();
  } else {
    const text = await res.text();
    data = { error: text || `Request failed (${res.status})` };
  }

  if (!res.ok) {
    const err = new Error(data?.error || `Request failed (${res.status})`);
    err.status = res.status;
    throw err;
  }
  return data || {};
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

function formatTime(ts) {
  return new Date(ts).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
}

// ── Navigation ──

const DEFAULT_PAGE = "chat";
const VALID_PAGES = new Set([
  "chat",
  "world",
  "messaging",
  "mcp",
  "scheduler",
  "memory",
  "skills",
  "protocols",
  "logs",
]);

function getPageFromLocation() {
  const match = window.location.pathname.match(/^\/app\/([^/]+)$/);
  const candidate = match?.[1] || (window.location.pathname === "/app" ? DEFAULT_PAGE : null);
  return VALID_PAGES.has(candidate) ? candidate : DEFAULT_PAGE;
}

function buildPageUrl(page) {
  return page === DEFAULT_PAGE ? "/app" : `/app/${page}`;
}

function navigateTo(page, { push = true } = {}) {
  if (!VALID_PAGES.has(page)) page = DEFAULT_PAGE;

  $$(".page").forEach((p) => p.classList.remove("active"));
  $$(".sidebar-btn").forEach((b) => b.classList.remove("active"));

  const pageEl = $(`#page-${page}`);
  if (pageEl) {
    pageEl.classList.add("active");
    const btn = $(`.sidebar-btn[data-page="${page}"]`);
    if (btn) btn.classList.add("active");
  }

  if (push) {
    const nextUrl = buildPageUrl(page);
    if (window.location.pathname !== nextUrl) {
      window.history.pushState({ page }, "", nextUrl);
    }
  }

  if (page === "memory") loadMemoryPage();
  if (page === "skills") loadSkillsPage();
  if (page === "mcp") loadMCPPage();
  if (page === "scheduler") loadSchedulerPage();
  if (page === "messaging") loadMessagingPage();
  if (page === "protocols") loadProtocolsPage();
  if (page === "world") {
    requestAnimationFrame(() => {
      ensureWorld();
      if (pixelWorld) {
        pixelWorld.resize();
        pixelWorld.refreshSummary();
      }
    });
  }
  if (page === "logs") loadLogsPage();
}

$$(".sidebar-btn[data-page]").forEach((btn) => {
  btn.addEventListener("click", () => navigateTo(btn.dataset.page));
});

window.addEventListener("popstate", () => {
  navigateTo(getPageFromLocation(), { push: false });
});

// ── Chat ──

const chatInput = $("#chatInput");
const chatMessages = $("#chatMessages");
const chatEmpty = $("#chatEmpty");
const sendBtn = $("#chatSendBtn");

chatInput.addEventListener("input", () => {
  chatInput.style.height = "auto";
  chatInput.style.height = Math.min(chatInput.scrollHeight, 200) + "px";
});

chatInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});

sendBtn.addEventListener("click", sendMessage);

function sendMessage() {
  const text = chatInput.value.trim();
  if (!text || isStreaming) return;

  chatEmpty.classList.add("hidden");
  appendMessage("user", text);
  chatInput.value = "";
  chatInput.style.height = "auto";

  isStreaming = true;
  sendBtn.disabled = true;

  const thinkingEl = document.createElement("div");
  thinkingEl.className = "chat-thinking";
  thinkingEl.id = "thinking";
  thinkingEl.innerHTML =
    '<div class="spinner"></div><span id="thinkingText">NeoAgent is thinking...</span>';
  chatMessages.appendChild(thinkingEl);
  chatMessages.scrollTop = chatMessages.scrollHeight;

  // Reset world focus for the incoming run
  resetWorldForNewRun();

  socket.emit("agent:run", { task: text });
}

function appendMessage(role, content) {
  const chunks = role === "assistant" ? content.split(/\n\n+/).filter(c => c.trim()) : [content];
  let firstBubble = null;
  for (const chunk of chunks) {
    const div = document.createElement("div");
    div.className = `chat-message ${role}`;

    const avatar = document.createElement("div");
    avatar.className = "chat-avatar";
    avatar.textContent = role === "user" ? "U" : "N";

    const bubble = document.createElement("div");
    bubble.className = "chat-bubble md-content";
    bubble.innerHTML = renderMarkdown(chunk);
    requestAnimationFrame(renderMermaids);

    div.appendChild(avatar);
    div.appendChild(bubble);
    chatMessages.appendChild(div);
    if (!firstBubble) firstBubble = bubble;
  }
  chatMessages.scrollTop = chatMessages.scrollHeight;
  return firstBubble;
}

function appendToolCall(name, args, result) {
  const div = document.createElement("div");
  div.className = "chat-message assistant";
  const avatar = document.createElement("div");
  avatar.className = "chat-avatar";
  avatar.textContent = "N";
  const bubble = document.createElement("div");
  bubble.className = "chat-bubble";
  bubble.innerHTML = `<div class="chat-tool-call"><div class="tool-name">${escapeHtml(name)}</div>${args ? `<div class="tool-result">${escapeHtml(typeof args === "string" ? args : JSON.stringify(args, null, 2)).slice(0, 500)}</div>` : ""}${result ? `<div class="tool-result" style="border-top:1px solid var(--border);padding-top:6px;margin-top:6px;">${escapeHtml(typeof result === "string" ? result : JSON.stringify(result, null, 2)).slice(0, 1000)}</div>` : ""}</div>`;
  div.appendChild(avatar);
  div.appendChild(bubble);
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Status update (interim message from AI mid-task)
function appendInterimMessage(message) {
  const div = document.createElement("div");
  div.className = "chat-interim";
  div.innerHTML = `<div class="chat-interim-dot"></div><div class="chat-interim-text">${escapeHtml(message)}</div>`;
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Show a social platform message (WhatsApp etc.) in chat
function appendSocialMessage(platform, role, content, senderName) {
  const div = document.createElement("div");
  div.className =
    role === "user" ? "chat-message social" : "chat-message assistant";
  const avatar = document.createElement("div");
  avatar.className = "chat-avatar";
  avatar.textContent =
    platform === "whatsapp" ? "💬" : platform[0].toUpperCase();
  if (role === "user")
    avatar.style.cssText = "background:#25d36620;color:#25d366;font-size:12px;";
  const bubble = document.createElement("div");
  bubble.className = "chat-bubble";
  const badge = `<div class="chat-platform-badge ${platform.toLowerCase()}">${platform}</div>`;
  const sender =
    role === "user" && senderName
      ? `<div class="chat-sender">${escapeHtml(senderName)}</div>`
      : "";
  bubble.innerHTML = badge + sender + renderMarkdown(content);
  requestAnimationFrame(renderMermaids);
  div.appendChild(avatar);
  div.appendChild(bubble);
  chatMessages.appendChild(div);
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Load and render chat history from DB
async function loadChatHistory() {
  try {
    const data = await api("/agents/chat-history?limit=80");
    if (!data.messages || data.messages.length === 0) return;
    chatEmpty.classList.add("hidden");
    for (const msg of data.messages) {
      if (!msg.content) continue;
      if (msg.platform === "web") {
        appendMessage(msg.role, msg.content);
      } else {
        appendSocialMessage(
          msg.platform,
          msg.role,
          msg.content,
          msg.sender_name,
        );
      }
    }
  } catch {
    /* silently skip */
  }
}

// Load history on startup
loadChatHistory();

// Simple markdown renderer
function renderMarkdown(text) {
  if (!text) return "";
  let html = escapeHtml(text);

  // Mermaid blocks
  html = html.replace(/```mermaid\n([\s\S]*?)```/g, (match, code) => {
    return `<div class="mermaid-container" style="background:#0f172a;padding:12px;border-radius:8px;margin:8px 0;"><pre class="mermaid">${code}</pre></div>`;
  });

  // Code blocks
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, "<pre><code>$2</code></pre>");
  // Inline code
  html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
  // Bold
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  // Italic
  html = html.replace(/\*(.+?)\*/g, "<em>$1</em>");
  // Headers
  html = html.replace(/^### (.+)$/gm, "<h3>$1</h3>");
  html = html.replace(/^## (.+)$/gm, "<h2>$1</h2>");
  html = html.replace(/^# (.+)$/gm, "<h1>$1</h1>");

  // Tables
  html = html.replace(
    /\n\|?(.+)\|?\n\|?([-:| ]+)\|?\n((?:\|?.*\|?\n?)*)/g,
    (match, header, sub, body) => {
      if (!sub.includes("-")) return match;
      const thead =
        "<thead><tr>" +
        header
          .split("|")
          .filter((c) => c.trim())
          .map((c) => `<th>${c.trim()}</th>`)
          .join("") +
        "</tr></thead>";
      const tbody =
        "<tbody>" +
        body
          .trim()
          .split("\n")
          .map((row) => {
            const parts = row.split("|").filter((c) => c.trim() || c === "");
            if (parts.length === 0) return "";
            return (
              "<tr>" +
              parts.map((c) => `<td>${c.trim()}</td>`).join("") +
              "</tr>"
            );
          })
          .join("") +
        "</tbody>";
      return `\n<div class="table-responsive"><table class="md-table">${thead}${tbody}</table></div>\n`;
    },
  );

  // Lists
  html = html.replace(/^- (.+)$/gm, "<li>$1</li>");
  html = html.replace(/(<li>.*<\/li>)/s, "<ul>$1</ul>");
  // Links
  html = html.replace(
    /\[(.+?)\]\((.+?)\)/g,
    '<a href="$2" target="_blank">$1</a>',
  );
  // Line breaks
  html = html.replace(
    /\n(?!(?:<\/th>|<\/tr>|<\/td>|<\/thead>|<\/tbody>|<\/table>|<\/div>|<div|<table|<thead|<tbody|<tr|<th|<td|<pre|<\/pre>|<ul|<\/ul>|<li|<\/li>))/g,
    "<br>",
  );
  return html;
}

// ── World Helpers ──

const TOOL_META = {
  execute_command: { icon: "⚡", label: "Terminal", color: "cli" },
  browser_navigate: { icon: "🌐", label: "Browse", color: "browser" },
  browser_click: { icon: "🖱️", label: "Click", color: "browser" },
  browser_type: { icon: "⌨️", label: "Type", color: "browser" },
  browser_extract: { icon: "📋", label: "Extract", color: "browser" },
  browser_screenshot: { icon: "📷", label: "Screenshot", color: "browser" },
  browser_evaluate: { icon: "⚙️", label: "Script", color: "browser" },
  memory_write: { icon: "🧠", label: "Memory Write", color: "memory" },
  memory_read: { icon: "🧠", label: "Memory Read", color: "memory" },
  memory_save: { icon: "🧠", label: "Save Memory", color: "memory" },
  memory_recall: { icon: "🔍", label: "Recall Memory", color: "memory" },
  memory_update_core: { icon: "📌", label: "Core Memory", color: "memory" },
  think: { icon: "💭", label: "Thinking", color: "thinking" },
  send_message: { icon: "💬", label: "Message", color: "messaging" },
  make_call: { icon: "📞", label: "Call", color: "messaging" },
  http_request: { icon: "🔗", label: "HTTP Request", color: "http" },
  read_file: { icon: "📄", label: "Read File", color: "file" },
  write_file: { icon: "📝", label: "Write File", color: "file" },
  list_directory: { icon: "📁", label: "List Dir", color: "file" },
  spawn_subagent: { icon: "🤖", label: "Sub-Agent", color: "agent" },
};

function getToolMeta(name) {
  return TOOL_META[name] || { icon: "🔧", label: name, color: "tool" };
}

function describeArgs(toolName, args) {
  if (!args) return null;
  switch (toolName) {
    case "execute_command":
      return {
        headline: args.command,
        detail: args.cwd ? `Dir: ${args.cwd}` : null,
      };
    case "browser_navigate":
      return { headline: args.url };
    case "browser_click":
      return {
        headline: args.text ? `"${args.text}"` : args.selector || "element",
      };
    case "browser_type":
      return { headline: `"${args.text}"`, detail: `into ${args.selector}` };
    case "browser_screenshot":
      return {
        headline: args.selector ? `Element: ${args.selector}` : "Full page",
      };
    case "browser_extract":
      return { headline: args.selector || "Page content" };
    case "browser_evaluate":
      return { headline: args.script?.slice(0, 120) };
    case "memory_write":
      return {
        headline: `→ ${args.target}`,
        detail: args.content?.slice(0, 160),
      };
    case "memory_read":
      return {
        headline: `← ${args.target}`,
        detail: args.search ? `Search: "${args.search}"` : null,
      };
    case "memory_save":
      return {
        headline: args.content?.slice(0, 200),
        detail: `${args.category || "episodic"} · importance ${args.importance || 5}`,
      };
    case "memory_recall":
      return {
        headline: `"${args.query}"`,
        detail: args.limit ? `top ${args.limit}` : null,
      };
    case "memory_update_core":
      return {
        headline: `${args.key} → ${String(args.value || "").slice(0, 100)}`,
      };
    case "think":
      return { headline: args.thought?.slice(0, 400) };
    case "http_request":
      return { headline: `${args.method || "GET"} ${args.url}` };
    case "send_message":
      return {
        headline: args.content?.slice(0, 160),
        detail: `${args.platform} → ${args.to}`,
      };
    case "make_call":
      return {
        headline: `Calling ${args.to}`,
        detail: args.greeting?.slice(0, 100),
      };
    case "read_file":
      return { headline: args.path };
    case "write_file":
      return {
        headline: args.path,
        detail: `${(args.content || "").length} chars`,
      };
    case "list_directory":
      return { headline: args.path };
    case "spawn_subagent":
      return { headline: args.task?.slice(0, 200) };
    default: {
      const first = Object.values(args).find((v) => typeof v === "string");
      return first ? { headline: first.slice(0, 160) } : null;
    }
  }
}

function describeResult(toolName, result) {
  if (!result) return null;
  if (result.error) return { type: "error", text: result.error };
  switch (toolName) {
    case "execute_command": {
      const out = (
        result.stdout ||
        result.output ||
        result.stderr ||
        ""
      ).trim();
      const code = result.exitCode ?? result.exit_code;
      return {
        type: code === 0 || code == null ? "code" : "error",
        text: out.slice(0, 600) || "(no output)",
        meta: code != null ? `Exit ${code}` : null,
      };
    }
    case "browser_navigate":
    case "browser_click":
    case "browser_type":
    case "browser_screenshot":
    case "browser_evaluate":
      return { type: "screenshot", meta: result.title || null };
    case "memory_write":
      return { type: "success", text: "Saved ✓" };
    case "memory_read": {
      const txt =
        typeof result === "string"
          ? result
          : result.content || JSON.stringify(result);
      return { type: "output", text: txt.slice(0, 400) };
    }
    case "memory_save":
      return { type: "success", text: "Saved to memory ✓" };
    case "memory_update_core":
      return { type: "success", text: "Core memory updated ✓" };
    case "memory_recall": {
      const results = result?.results || [];
      if (!results.length) return { type: "output", text: "Nothing found" };
      const preview = results
        .slice(0, 3)
        .map((r) => `• ${r.content}`)
        .join("\n");
      return { type: "output", text: preview };
    }
    case "think":
      return null;
    case "http_request": {
      const s = result.status;
      const cls = s >= 200 && s < 300 ? "ok" : s >= 400 ? "err" : "warn";
      return {
        type: "output",
        text: (result.body || "").slice(0, 400),
        meta: `HTTP ${s}`,
        statusClass: cls,
      };
    }
    case "read_file":
      return { type: "code", text: (result.content || "").slice(0, 400) };
    case "write_file":
      return { type: "success", text: "File written ✓" };
    case "list_directory": {
      const items = (result.entries || [])
        .slice(0, 20)
        .map((e) => e.name || e)
        .join("\n");
      return { type: "code", text: items };
    }
    default: {
      const txt =
        typeof result === "string" ? result : JSON.stringify(result, null, 2);
      return { type: "output", text: txt.slice(0, 400) };
    }
  }
}

class PixelWorld {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.buffer = document.createElement("canvas");
    this.buffer.width = 384;
    this.buffer.height = 216;
    this.bctx = this.buffer.getContext("2d");
    this.dpr = Math.max(1, window.devicePixelRatio || 1);
    this.tick = 0;
    this.runId = null;
    this.runMode = "idle";
    this.activeTool = null;
    this.taskLabel = "No active run";
    this.statusLabel = "Ambient systems nominal";
    this.totalTools = 0;
    this.totalMessages = 0;
    this.helperCounter = 0;
    this.scanFlash = 0;
    this.socialPulse = 0;
    this.errorFlash = 0;
    this.recentEvents = [];
    this.historyLoaded = false;
    this.stepAssignments = new Map();
    this.structures = [
      { key: "core", x: 138, y: 78, w: 104, h: 64, color: "#22c55e", glow: 0, label: "Lead Desk" },
      { key: "browser", x: 20, y: 16, w: 96, h: 80, color: "#3b82f6", glow: 0, label: "Research Corner" },
      { key: "memory", x: 286, y: 18, w: 82, h: 78, color: "#f59e0b", glow: 0, label: "Archive Wall" },
      { key: "cli", x: 16, y: 108, w: 108, h: 84, color: "#f97316", glow: 0, label: "Ops Bench" },
      { key: "social", x: 288, y: 116, w: 80, h: 74, color: "#ec4899", glow: 0, label: "Comms Desk" },
    ];
    this.helperSlots = [
      { x: 134, y: 160 },
      { x: 250, y: 160 },
      { x: 164, y: 176 },
      { x: 222, y: 176 },
    ];
    this.mainAgent = {
      id: "lead-agent",
      name: "NeoAgent",
      type: "lead",
      x: 192,
      y: 104,
      tint: "#9ef7dc",
      phase: 0.8,
      focus: "core",
      specialty: "Orchestrating the whole task",
      status: "Waiting for the next task",
      lastActive: 0,
    };
    this.helpers = [];
    this.packets = [];
    this.palette = null;
    this.officeImages = {
      dark: this.loadImage("/assets/world-office-dark.png"),
      light: this.loadImage("/assets/world-office-light.png"),
    };
    this.ui = {
      modePill: $("#worldModePill"),
      toolPill: $("#worldToolPill"),
      task: $("#worldTaskValue"),
      status: $("#worldStatusValue"),
      mode: $("#worldModeValue"),
      run: $("#worldRunValue"),
      tools: $("#worldToolsValue"),
      helpers: $("#worldHelpersValue"),
      messages: $("#worldMessagesValue"),
      agents: $("#worldAgentList"),
      events: $("#worldEventList"),
      badge: $("#worldBadge"),
    };

    this.resize = this.resize.bind(this);
    this.loop = this.loop.bind(this);
    window.addEventListener("resize", this.resize);
    this.syncTheme();
    this.resize();
    this.renderAgents();
    this.renderEventList();
    this.renderHud();
    requestAnimationFrame(this.loop);
  }

  resize() {
    const rect = this.canvas.getBoundingClientRect();
    const width = Math.max(320, Math.floor(rect.width || this.canvas.clientWidth || 640));
    const height = Math.max(320, Math.floor(rect.height || this.canvas.clientHeight || 560));
    this.canvas.width = Math.floor(width * this.dpr);
    this.canvas.height = Math.floor(height * this.dpr);
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.imageSmoothingEnabled = false;
  }

  syncTheme() {
    const styles = getComputedStyle(document.documentElement);
    const isDark = document.documentElement.dataset.theme !== "light";
    this.palette = {
      isDark,
      bg0: styles.getPropertyValue("--bg-0").trim(),
      bg1: styles.getPropertyValue("--bg-1").trim(),
      bg2: styles.getPropertyValue("--bg-2").trim(),
      bg3: styles.getPropertyValue("--bg-3").trim(),
      text: styles.getPropertyValue("--text-primary").trim(),
      muted: styles.getPropertyValue("--text-muted").trim(),
      border: styles.getPropertyValue("--border").trim(),
      accent: styles.getPropertyValue("--accent").trim(),
      success: styles.getPropertyValue("--success").trim(),
      info: styles.getPropertyValue("--info").trim(),
      warning: styles.getPropertyValue("--warning").trim(),
      error: styles.getPropertyValue("--error").trim(),
      floor: isDark ? "#252b31" : "#eceff2",
      floorAlt: isDark ? "#2e353d" : "#dfe5ea",
      wall: isDark ? "#151a1f" : "#fcfdff",
      trim: isDark ? "#0d1115" : "#cfd6de",
      desk: isDark ? "#4b5563" : "#d1d8e0",
      deskTop: isDark ? "#667181" : "#e0e5eb",
      chair: isDark ? "#1b232c" : "#8f9bab",
      screen: isDark ? "#111827" : "#eff6ff",
      screenGlow: isDark ? "#60a5fa" : "#2563eb",
      glass: isDark ? "rgba(120, 162, 219, 0.18)" : "rgba(134, 189, 255, 0.28)",
      plant: isDark ? "#4ca56f" : "#5fba7f",
      plantDark: isDark ? "#2a6d48" : "#438e5f",
      shadow: isDark ? "rgba(0,0,0,0.26)" : "rgba(59,76,94,0.10)",
      paper: isDark ? "#dbeafe" : "#ffffff",
      rug: isDark ? "#2f3640" : "#dde4eb",
      rugLine: isDark ? "#3d4754" : "#c7d1db",
      wood: isDark ? "#705038" : "#c28d62",
      coffee: isDark ? "#2b211d" : "#6b4b38",
    };
  }

  loadImage(src) {
    const img = new Image();
    img.src = src;
    return img;
  }

  refreshSummary() {
    if (this.historyLoaded) return;
    api("/agents?limit=6")
      .then((data) => {
        this.historyLoaded = true;
        const runs = data.runs || [];
        if (!runs.length || this.runMode !== "idle") return;
        this.pushEvent("history", `${runs.length} recent runs archived in the background.`);
      })
      .catch(() => {});
  }

  resetForNewRun() {
    this.runId = null;
    this.runMode = "idle";
    this.activeTool = null;
    this.taskLabel = "No active run";
    this.statusLabel = "Ambient systems nominal";
    this.totalTools = 0;
    this.stepAssignments.clear();
    this.helpers = [];
    this.packets.length = 0;
    this.scanFlash = 0;
    this.errorFlash = 0;
    this.mainAgent.focus = "core";
    this.mainAgent.status = "Waiting for the next task";
    this.mainAgent.lastActive = this.tick;
    this.renderAgents();
    this.renderHud();
  }

  onRunStart(data) {
    this.runId = data.runId;
    this.runMode = "running";
    this.activeTool = "Boot sequence";
    this.scanFlash = 1;
    this.mainAgent.status = "Welcoming a new task";
    this.mainAgent.lastActive = this.tick;
    this.pushEvent("run", `${data.title || `Run ${data.runId}`} is now live.`);
    this.flashStructure("core", 1.2);
    this.renderAgents();
    this.renderHud(data.title || `Run ${data.runId}`, "NeoAgent is getting everything set up");
  }

  onThinking(data) {
    this.runMode = "running";
    this.activeTool = `Thinking step ${data.iteration}`;
    this.scanFlash = Math.min(1.4, this.scanFlash + 0.18);
    this.mainAgent.status = `Thinking through step ${data.iteration}`;
    this.mainAgent.lastActive = this.tick;
    this.pushEvent("think", `NeoAgent is thinking through step ${data.iteration}.`);
    this.renderAgents();
    this.renderHud(undefined, "NeoAgent is planning the next move");
  }

  onToolStart(data) {
    this.runMode = "running";
    this.activeTool = getToolMeta(data.toolName).label;
    this.totalTools += 1;
    const structureKey = this.getStructureForTool(data.toolName);
    const actor = this.assignActor(data.stepId, data.toolName, data.toolArgs, structureKey);
    const target = this.getStructure(structureKey);
    this.spawnPacket(actor, target, target.color, data.toolName);
    this.flashStructure(structureKey, 1.4);
    this.pushEvent("tool", `${actor.name} is using ${getToolMeta(data.toolName).label.toLowerCase()} for ${this.getShortToolText(data.toolName, data.toolArgs)}.`);
    this.renderAgents();
    this.renderHud(undefined, `${actor.name} is working through ${target.label}`);
  }

  onToolEnd(data) {
    const structureKey = this.getStructureForTool(data.toolName);
    const actor = this.resolveActorForStep(data.stepId);
    this.flashStructure(structureKey, data.status === "failed" ? 1.8 : 0.9);
    if (data.status === "failed") {
      this.runMode = "failed";
      this.errorFlash = 1;
      actor.status = "Hit an issue and is regrouping";
      actor.lastActive = this.tick;
      this.pushEvent("fault", `${actor.name} hit a snag while using ${getToolMeta(data.toolName).label.toLowerCase()}.`);
      this.renderHud(undefined, `${actor.name} ran into an error`);
    } else {
      actor.status = `Wrapped up ${getToolMeta(data.toolName).label.toLowerCase()}`;
      actor.lastActive = this.tick;
      this.pushEvent("sync", `${actor.name} finished ${getToolMeta(data.toolName).label.toLowerCase()} cleanly.`);
      this.renderHud(undefined, `${actor.name} finished successfully`);
    }
    this.renderAgents();
    this.stepAssignments.delete(data.stepId);
  }

  onRunComplete(data) {
    this.runMode = data.status === "failed" ? "failed" : "completed";
    this.activeTool = data.status === "failed" ? "Recovery" : "Cooling down";
    this.stepAssignments.clear();
    this.mainAgent.status =
      this.runMode === "failed" ? "Comforting the crew and recovering" : "Wrapping up with the crew";
    this.mainAgent.lastActive = this.tick;
    for (const helper of this.helpers) {
      helper.status =
        this.runMode === "failed" ? "Standing by for retry" : "Heading back after helping";
    }
    this.flashStructure("core", this.runMode === "failed" ? 1.6 : 1.2);
    this.pushEvent(
      this.runMode === "failed" ? "fault" : "done",
      data.content ? data.content.slice(0, 90) : this.runMode === "failed" ? "The team is recovering from a failed run." : "The team finished the run."
    );
    this.renderAgents();
    this.renderHud(undefined, this.runMode === "failed" ? "The crew is recovering from a rough run" : "The crew wrapped everything up nicely");
  }

  onRunError(data) {
    this.runMode = "failed";
    this.activeTool = "Recovery";
    this.errorFlash = 1.1;
    this.mainAgent.status = "Helping the crew recover";
    for (const helper of this.helpers) {
      helper.status = "Waiting for new instructions";
    }
    this.flashStructure("core", 1.6);
    this.pushEvent("fault", data.error || "Unknown run error");
    this.renderAgents();
    this.renderHud(undefined, data.error || "The crew hit an unexpected error");
  }

  onMessage(data) {
    this.totalMessages += 1;
    this.socialPulse = 1.2;
    this.flashStructure("social", 1.5);
    const actor = this.helpers.find((helper) => helper.focus === "social") || this.mainAgent;
    actor.status = "Greeting a new incoming message";
    actor.lastActive = this.tick;
    const target = this.getStructure("social");
    this.spawnPacket(actor, target, "#ff7db7", "message");
    this.pushEvent("msg", `${actor.name} noticed a ${data.platform} message: ${String(data.content || "").slice(0, 72)}`);
    this.renderAgents();
    this.renderHud(undefined, "A friendly ping just reached the message port");
  }

  getShortToolText(toolName, toolArgs) {
    const desc = describeArgs(toolName, toolArgs);
    return desc?.headline ? desc.headline.slice(0, 58) : "signal received";
  }

  getStructureForTool(toolName) {
    if (toolName.startsWith("browser_")) return "browser";
    if (toolName.startsWith("memory_")) return "memory";
    if (toolName === "execute_command") return "cli";
    if (toolName === "send_message" || toolName === "make_call") return "social";
    return "core";
  }

  getStructure(key) {
    return this.structures.find((item) => item.key === key) || this.structures[0];
  }

  assignActor(stepId, toolName, toolArgs, structureKey) {
    if (toolName === "spawn_subagent") {
      const helper = this.spawnHelper(toolArgs, structureKey);
      this.stepAssignments.set(stepId, helper.id);
      this.mainAgent.status = `Delegating work to ${helper.name}`;
      this.mainAgent.lastActive = this.tick;
      return helper;
    }

    const specialist = this.helpers
      .filter((helper) => helper.focus === structureKey)
      .sort((a, b) => a.lastActive - b.lastActive)[0];
    const actor = specialist || this.mainAgent;
    actor.focus = structureKey;
    actor.status = this.describeFriendlyAction(toolName, toolArgs);
    actor.lastActive = this.tick;
    this.stepAssignments.set(stepId, actor.id);
    return actor;
  }

  resolveActorForStep(stepId) {
    const actorId = this.stepAssignments.get(stepId);
    if (!actorId || actorId === this.mainAgent.id) return this.mainAgent;
    return this.helpers.find((helper) => helper.id === actorId) || this.mainAgent;
  }

  spawnHelper(toolArgs, structureKey) {
    const slot = this.helperSlots[this.helpers.length % this.helperSlots.length];
    this.helperCounter += 1;
    const specialty = this.inferHelperSpecialty(toolArgs, structureKey);
    const focus = this.inferHelperFocus(toolArgs, structureKey);
    const helper = {
      id: `helper-${this.helperCounter}`,
      name: `Scout-${this.helperCounter}`,
      type: "helper",
      x: slot.x,
      y: slot.y,
      tint: ["#9fd6ff", "#ffd36b", "#ff9dce", "#cdb8ff"][this.helperCounter % 4],
      phase: 0.5 + this.helperCounter,
      focus,
      specialty,
      status: `Joining the task to help with ${specialty.toLowerCase()}`,
      lastActive: this.tick,
    };
    this.helpers.push(helper);
    this.spawnPacket(this.mainAgent, helper, helper.tint, "delegate");
    this.pushEvent("team", `NeoAgent spawned ${helper.name} to help with ${specialty.toLowerCase()}.`);
    return helper;
  }

  inferHelperSpecialty(toolArgs, structureKey) {
    const headline =
      toolArgs?.task ||
      toolArgs?.prompt ||
      toolArgs?.description ||
      toolArgs?.content ||
      this.getStructure(structureKey).label;
    return String(headline).slice(0, 36);
  }

  inferHelperFocus(toolArgs, fallback) {
    const text = JSON.stringify(toolArgs || {}).toLowerCase();
    if (text.includes("browser") || text.includes("web") || text.includes("search") || text.includes("page")) return "browser";
    if (text.includes("memory") || text.includes("recall") || text.includes("history")) return "memory";
    if (text.includes("command") || text.includes("shell") || text.includes("terminal") || text.includes("file")) return "cli";
    if (text.includes("message") || text.includes("call") || text.includes("email")) return "social";
    return fallback;
  }

  describeFriendlyAction(toolName, toolArgs) {
    const headline = this.getShortToolText(toolName, toolArgs);
    if (toolName === "execute_command") return `Checking the command forge for ${headline}`;
    if (toolName.startsWith("browser_")) return `Exploring the web for ${headline}`;
    if (toolName.startsWith("memory_")) return `Digging through memory for ${headline}`;
    if (toolName === "send_message" || toolName === "make_call") return `Reaching out about ${headline}`;
    return `Working on ${headline}`;
  }

  spawnPacket(bot, structure, color, label) {
    const targetX = structure.x + Math.floor((structure.w || 2) / 2);
    const targetY = structure.y + ((structure.h || 2) > 2 ? 4 : 0);
    this.packets.push({
      x: bot.x,
      y: bot.y - 4,
      fromX: bot.x,
      fromY: bot.y - 4,
      toX: targetX,
      toY: targetY,
      color,
      label,
      progress: 0,
      speed: 0.018 + Math.random() * 0.018,
    });
  }

  flashStructure(key, amount) {
    const structure = this.getStructure(key);
    structure.glow = Math.max(structure.glow, amount);
  }

  pushEvent(tag, text) {
    this.recentEvents.unshift({
      tag,
      text,
      time: new Date(),
    });
    this.recentEvents = this.recentEvents.slice(0, 6);
    if (this.ui.badge) this.ui.badge.classList.remove("hidden");
    this.renderEventList();
  }

  renderAgents() {
    const list = this.ui.agents;
    if (!list) return;
    const roster = [this.mainAgent, ...this.helpers];
    list.innerHTML = roster
      .map((agent) => `
        <div class="world-agent-card">
          <div class="world-agent-topline">
            <span class="world-agent-title">${escapeHtml(agent.name)}</span>
            <span class="world-agent-chip ${agent.type === "lead" ? "lead" : "helper"}">${agent.type === "lead" ? "Lead" : "Helper"}</span>
          </div>
          <div class="world-agent-meta">${escapeHtml(agent.specialty)}</div>
          <div class="world-agent-status">${escapeHtml(agent.status)}</div>
        </div>
      `)
      .join("");
  }

  renderEventList() {
    const list = this.ui.events;
    if (!list) return;
    if (!this.recentEvents.length) {
      list.innerHTML = '<div class="world-empty-state">The world is idling. Start a task in chat to wake everything up.</div>';
      return;
    }
    list.innerHTML = this.recentEvents
      .map((event) => `
        <div class="world-event-entry">
          <div class="world-event-topline">
            <span class="world-event-tag">${escapeHtml(event.tag)}</span>
            <span class="world-event-time">${escapeHtml(formatTime(event.time))}</span>
          </div>
          <div class="world-event-text">${escapeHtml(event.text)}</div>
        </div>
      `)
      .join("");
  }

  renderHud(taskText, statusText) {
    if (taskText) this.taskLabel = taskText;
    if (statusText) this.statusLabel = statusText;
    const modeText =
      this.runMode === "running"
        ? "Running"
        : this.runMode === "completed"
          ? "Complete"
          : this.runMode === "failed"
            ? "Fault"
            : "Idle";
    if (this.ui.modePill) this.ui.modePill.textContent = modeText;
    if (this.ui.toolPill) this.ui.toolPill.textContent = this.activeTool || "Awaiting signal";
    if (this.ui.task) this.ui.task.textContent = this.taskLabel || (this.runId ? `Run ${this.runId}` : "No active run");
    if (this.ui.status) this.ui.status.textContent = this.statusLabel || this.getAmbientStatus();
    if (this.ui.mode) this.ui.mode.textContent = modeText;
    if (this.ui.run) this.ui.run.textContent = this.runId ? String(this.runId) : "None";
    if (this.ui.tools) this.ui.tools.textContent = String(this.totalTools);
    if (this.ui.helpers) this.ui.helpers.textContent = String(this.helpers.length);
    if (this.ui.messages) this.ui.messages.textContent = String(this.totalMessages);
  }

  getAmbientStatus() {
    if (this.runMode === "running") return "The office is busy and everyone is moving work forward";
    if (this.runMode === "completed") return "The office settled down after a clean handoff";
    if (this.runMode === "failed") return "The team is regrouping after a rough patch";
    return "The office is quiet and ready for the next task";
  }

  loop() {
    this.tick += 1;
    this.updateSimulation();
    this.draw();
    requestAnimationFrame(this.loop);
  }

  updateSimulation() {
    this.scanFlash *= 0.97;
    this.socialPulse *= 0.94;
    this.errorFlash *= 0.93;

    for (const structure of this.structures) {
      structure.glow *= 0.94;
    }

    this.mainAgent.phase += 0.025;
    for (const helper of this.helpers) helper.phase += 0.025;

    this.packets = this.packets.filter((packet) => {
      packet.progress += packet.speed;
      packet.x = packet.fromX + (packet.toX - packet.fromX) * packet.progress;
      packet.y = packet.fromY + (packet.toY - packet.fromY) * packet.progress - Math.sin(packet.progress * Math.PI) * 10;
      return packet.progress < 1;
    });
  }

  draw() {
    const ctx = this.bctx;
    const t = this.tick;
    ctx.clearRect(0, 0, 384, 216);
    this.drawOffice(ctx);
    this.drawStructures(ctx);
    this.drawWalkways(ctx);
    this.drawBots(ctx, t);
    this.drawPackets(ctx);
    this.drawStatusEffects(ctx, t);
    this.drawScanlines(ctx);

    this.ctx.save();
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.imageSmoothingEnabled = false;
    this.ctx.drawImage(this.buffer, 0, 0, this.canvas.width, this.canvas.height);
    this.ctx.restore();
  }

  drawOffice(ctx) {
    const ref = this.palette.isDark ? this.officeImages.dark : this.officeImages.light;
    if (ref && ref.complete && ref.naturalWidth > 0) {
      this.drawReferenceImage(ctx, ref, 384, 216);
      return;
    }

    const p = this.palette;
    ctx.fillStyle = p.floor;
    ctx.fillRect(0, 0, 384, 216);

    ctx.fillStyle = p.floorAlt;
    for (let y = 0; y < 216; y += 24) {
      for (let x = (y / 24) % 2 === 0 ? 0 : 12; x < 384; x += 24) {
        ctx.fillRect(x, y, 12, 12);
      }
    }

    ctx.fillStyle = p.wall;
    ctx.fillRect(12, 12, 360, 10);
    ctx.fillRect(12, 194, 360, 10);
    ctx.fillRect(12, 22, 10, 172);
    ctx.fillRect(362, 22, 10, 172);
    ctx.fillStyle = p.trim;
    ctx.fillRect(22, 22, 340, 2);
    ctx.fillRect(22, 192, 340, 2);
    ctx.fillRect(22, 22, 2, 170);
    ctx.fillRect(360, 22, 2, 170);

    ctx.fillStyle = p.glass;
    this.drawWindow(ctx, 118, 22, 62, 10);
    this.drawWindow(ctx, 190, 22, 62, 10);

    ctx.fillStyle = p.rug;
    ctx.fillRect(134, 68, 116, 74);
    ctx.fillStyle = p.rugLine;
    for (let x = 140; x < 240; x += 12) ctx.fillRect(x, 74, 2, 62);

    this.drawMeetingTable(ctx, 146, 80);
    this.drawShelfWall(ctx, 34, 34);
    this.drawShelfWall(ctx, 318, 34);
    this.drawCoffeeBar(ctx, 300, 150);
    this.drawPrinterNook(ctx, 34, 150);
    this.drawLounge(ctx, 168, 150);

    this.drawPlant(ctx, 30, 30);
    this.drawPlant(ctx, 346, 30);
    this.drawPlant(ctx, 30, 178);
    this.drawPlant(ctx, 346, 178);

    this.drawDeskCluster(ctx, 154, 80, "core");
    this.drawDeskCluster(ctx, 270, 42, "browser");
    this.drawDeskCluster(ctx, 56, 42, "memory");
    this.drawDeskCluster(ctx, 56, 146, "cli");
    this.drawDeskCluster(ctx, 270, 146, "social");
  }

  drawReferenceImage(ctx, image, targetWidth, targetHeight) {
    const imageRatio = image.naturalWidth / image.naturalHeight;
    const targetRatio = targetWidth / targetHeight;

    let drawWidth = targetWidth;
    let drawHeight = targetHeight;
    let offsetX = 0;
    let offsetY = 0;

    if (imageRatio > targetRatio) {
      drawWidth = targetWidth;
      drawHeight = Math.round(targetWidth / imageRatio);
      offsetY = Math.floor((targetHeight - drawHeight) / 2);
    } else {
      drawHeight = targetHeight;
      drawWidth = Math.round(targetHeight * imageRatio);
      offsetX = Math.floor((targetWidth - drawWidth) / 2);
    }

    ctx.fillStyle = this.palette.floor;
    ctx.fillRect(0, 0, targetWidth, targetHeight);
    ctx.drawImage(image, offsetX, offsetY, drawWidth, drawHeight);
  }

  drawPlant(ctx, x, y) {
    const p = this.palette;
    ctx.fillStyle = p.wood;
    ctx.fillRect(x, y + 8, 8, 7);
    ctx.fillStyle = p.plantDark;
    ctx.fillRect(x - 2, y + 2, 12, 8);
    ctx.fillStyle = p.plant;
    ctx.fillRect(x - 4, y, 16, 7);
  }

  drawWindow(ctx, x, y, w, h) {
    const p = this.palette;
    ctx.fillStyle = p.trim;
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = p.glass;
    ctx.fillRect(x + 2, y + 2, w - 4, h - 4);
    ctx.fillStyle = this.hexToRgba("#ffffff", p.isDark ? 0.12 : 0.3);
    ctx.fillRect(x + 8, y + 2, 2, h - 4);
    ctx.fillRect(x + 24, y + 2, 2, h - 4);
    ctx.fillRect(x + 40, y + 2, 2, h - 4);
  }

  drawMeetingTable(ctx, x, y) {
    const p = this.palette;
    ctx.fillStyle = p.shadow;
    ctx.fillRect(x + 4, y + 38, 92, 4);
    ctx.fillStyle = p.wood;
    ctx.fillRect(x, y, 100, 38);
    ctx.fillStyle = p.paper;
    ctx.fillRect(x + 12, y + 10, 18, 10);
    ctx.fillRect(x + 68, y + 10, 18, 10);
    ctx.fillStyle = p.chair;
    ctx.fillRect(x - 8, y + 6, 8, 10);
    ctx.fillRect(x - 8, y + 22, 8, 10);
    ctx.fillRect(x + 100, y + 6, 8, 10);
    ctx.fillRect(x + 100, y + 22, 8, 10);
  }

  drawShelfWall(ctx, x, y) {
    const p = this.palette;
    ctx.fillStyle = p.trim;
    ctx.fillRect(x, y, 34, 44);
    ctx.fillStyle = p.wood;
    for (let y0 = y + 4; y0 < y + 40; y0 += 12) {
      ctx.fillRect(x + 2, y0, 30, 2);
    }
    ctx.fillStyle = p.warning;
    ctx.fillRect(x + 5, y + 7, 5, 7);
    ctx.fillRect(x + 12, y + 7, 4, 7);
    ctx.fillRect(x + 18, y + 7, 6, 7);
    ctx.fillRect(x + 8, y + 19, 6, 7);
    ctx.fillRect(x + 18, y + 19, 4, 7);
    ctx.fillRect(x + 12, y + 31, 5, 7);
    ctx.fillRect(x + 20, y + 31, 7, 7);
  }

  drawCoffeeBar(ctx, x, y) {
    const p = this.palette;
    ctx.fillStyle = p.deskTop;
    ctx.fillRect(x, y, 44, 24);
    ctx.fillStyle = p.coffee;
    ctx.fillRect(x + 4, y + 4, 14, 12);
    ctx.fillStyle = p.paper;
    ctx.fillRect(x + 24, y + 5, 6, 8);
    ctx.fillRect(x + 32, y + 7, 5, 6);
  }

  drawPrinterNook(ctx, x, y) {
    const p = this.palette;
    ctx.fillStyle = p.deskTop;
    ctx.fillRect(x, y, 42, 24);
    ctx.fillStyle = p.screen;
    ctx.fillRect(x + 7, y + 5, 20, 10);
    ctx.fillStyle = p.paper;
    ctx.fillRect(x + 12, y + 2, 10, 5);
    ctx.fillRect(x + 30, y + 8, 7, 5);
  }

  drawLounge(ctx, x, y) {
    const p = this.palette;
    ctx.fillStyle = p.rug;
    ctx.fillRect(x, y, 48, 30);
    ctx.fillStyle = p.chair;
    ctx.fillRect(x + 4, y + 8, 14, 14);
    ctx.fillRect(x + 30, y + 8, 14, 14);
    ctx.fillStyle = p.wood;
    ctx.fillRect(x + 20, y + 11, 8, 8);
  }

  drawDeskCluster(ctx, x, y, key) {
    const p = this.palette;
    const structure = this.getStructure(key);
    ctx.fillStyle = p.shadow;
    ctx.fillRect(x - 4, y + structure.h + 2, structure.w + 8, 4);
    ctx.fillStyle = p.deskTop;
    ctx.fillRect(x, y, structure.w, structure.h);
    ctx.fillStyle = p.desk;
    ctx.fillRect(x + 4, y + 4, structure.w - 8, structure.h - 8);
    ctx.fillStyle = p.screen;
    ctx.fillRect(x + 8, y + 8, structure.w - 16, 10);
    ctx.fillStyle = p.screenGlow;
    ctx.fillRect(x + 10, y + 10, structure.w - 20, 4);
    ctx.fillStyle = p.paper;
    ctx.fillRect(x + 10, y + structure.h - 12, 10, 6);
    ctx.fillStyle = p.chair;
    ctx.fillRect(x + Math.floor(structure.w / 2) - 8, y + structure.h + 2, 16, 8);
    if (key === "memory") {
      ctx.fillStyle = p.warning;
      ctx.fillRect(x + structure.w - 18, y + 22, 10, 6);
    } else if (key === "browser") {
      ctx.fillStyle = p.info;
      ctx.fillRect(x + structure.w - 18, y + 22, 10, 6);
    } else if (key === "social") {
      ctx.fillStyle = "#ec4899";
      ctx.fillRect(x + structure.w - 18, y + 22, 10, 6);
    } else if (key === "cli") {
      ctx.fillStyle = "#f97316";
      ctx.fillRect(x + structure.w - 18, y + 22, 10, 6);
    } else {
      ctx.fillStyle = p.success;
      ctx.fillRect(x + structure.w - 18, y + 22, 10, 6);
    }
  }

  drawStructures(ctx) {
    for (const structure of this.structures) {
      const glowSize = Math.floor(structure.glow * 7);
      if (glowSize > 0) {
        ctx.fillStyle = this.hexToRgba(structure.color, 0.18);
        ctx.fillRect(structure.x - glowSize, structure.y - glowSize, structure.w + glowSize * 2, structure.h + glowSize * 2);
      }
      if (structure.glow > 0.08) {
        ctx.fillStyle = this.hexToRgba(structure.color, 0.18 + structure.glow * 0.08);
        ctx.fillRect(structure.x, structure.y, structure.w, 3);
      }
    }
  }

  drawWalkways(ctx) {
    const core = this.getStructure("core");
    for (const structure of this.structures) {
      if (structure.key === "core") continue;
      const x1 = core.x + Math.floor(core.w / 2);
      const y1 = core.y + core.h - 2;
      const x2 = structure.x + Math.floor(structure.w / 2);
      const y2 = structure.y + Math.floor(structure.h / 2);
      ctx.fillStyle = this.hexToRgba(structure.color, 0.06 + structure.glow * 0.08);
      for (let x = Math.min(x1, x2); x <= Math.max(x1, x2); x += 6) {
        ctx.fillRect(x, y1, 2, 2);
      }
      for (let y = Math.min(y1, y2); y <= Math.max(y1, y2); y += 6) {
        ctx.fillRect(x2, y, 2, 2);
      }
    }
  }

  drawBots(ctx, t) {
    const leadBounce = Math.sin(t * 0.08 + this.mainAgent.phase) > 0 ? 0 : 1;
    this.drawBot(ctx, this.mainAgent.x, this.mainAgent.y - leadBounce, this.mainAgent.tint, true, true);
    for (const helper of this.helpers) {
      const bounce = Math.sin(t * 0.08 + helper.phase) > 0 ? 0 : 1;
      this.drawBot(ctx, helper.x, helper.y - bounce, helper.tint, helper.lastActive + 80 > this.tick, false);
    }
  }

  drawBot(ctx, x, y, tint, active, isLead = false) {
    const p = this.palette;
    if (isLead) {
      ctx.fillStyle = this.hexToRgba(p.success, 0.18);
      ctx.fillRect(x - 12, y - 15, 24, 20);
    }
    ctx.fillStyle = p.shadow;
    ctx.fillRect(x - 8, y + 8, 16, 4);
    ctx.fillStyle = "#111318";
    ctx.fillRect(x - 7, y - 6, 14, 12);
    ctx.fillStyle = tint;
    ctx.fillRect(x - 6, y - 5, 12, 10);
    ctx.fillStyle = this.hexToRgba("#ffffff", 0.18);
    ctx.fillRect(x - 5, y - 4, 10, 2);
    ctx.fillStyle = p.paper;
    ctx.fillRect(x - 3, y - 1, 2, 2);
    ctx.fillRect(x + 1, y - 1, 2, 2);
    ctx.fillStyle = active ? p.success : p.chair;
    ctx.fillRect(x - 4, y + 5, 8, 3);
    ctx.fillRect(x - 7, y + 1, 3, 2);
    ctx.fillRect(x + 4, y + 1, 3, 2);
    ctx.fillStyle = "#111318";
    ctx.fillRect(x - 4, y + 8, 2, 3);
    ctx.fillRect(x + 2, y + 8, 2, 3);
    if (isLead) {
      ctx.fillStyle = p.success;
      ctx.fillRect(x - 2, y - 9, 4, 3);
    }
  }

  drawPackets(ctx) {
    for (const packet of this.packets) {
      ctx.fillStyle = packet.color;
      ctx.fillRect(Math.round(packet.x), Math.round(packet.y), 4, 4);
      ctx.fillStyle = this.palette.paper;
      ctx.fillRect(Math.round(packet.x) + 1, Math.round(packet.y) + 1, 2, 2);
    }
  }

  drawStatusEffects(ctx, t) {
    const p = this.palette;
    if (this.scanFlash > 0.02) {
      ctx.fillStyle = this.hexToRgba(p.info, Math.min(0.08, this.scanFlash * 0.06));
      const x = 24 + ((t * 2) % 320);
      ctx.fillRect(x, 20, 8, 176);
    }
    if (this.socialPulse > 0.02) {
      ctx.fillStyle = this.hexToRgba("#ec4899", Math.min(0.1, this.socialPulse * 0.08));
      ctx.fillRect(284, 122, 72, 62);
    }
    if (this.errorFlash > 0.02) {
      ctx.fillStyle = this.hexToRgba(p.error, Math.min(0.1, this.errorFlash * 0.1));
      ctx.fillRect(0, 0, 384, 216);
    }
  }

  drawScanlines(ctx) {
    ctx.fillStyle = this.palette.isDark ? "rgba(4, 8, 14, 0.015)" : "rgba(255, 255, 255, 0.015)";
    for (let y = 0; y < 216; y += 4) {
      ctx.fillRect(0, y, 384, 1);
    }
  }

  hexToRgba(hex, alpha) {
    const clean = hex.replace("#", "");
    const value = parseInt(clean, 16);
    const r = (value >> 16) & 255;
    const g = (value >> 8) & 255;
    const b = value & 255;
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
}

let pixelWorld = null;

function ensureWorld() {
  if (pixelWorld) return;
  const canvas = document.getElementById("worldCanvas");
  if (!canvas) return;
  pixelWorld = new PixelWorld(canvas);
  window.pixelWorld = pixelWorld;
}

function resetWorldForNewRun() {
  ensureWorld();
  if (pixelWorld) pixelWorld.resetForNewRun();
}

ensureWorld();
navigateTo(getPageFromLocation(), { push: false });

// ── Socket Events ──

socket.on("run:start", (data) => {
  if (
    data.triggerSource === "scheduler" ||
    data.triggerSource === "heartbeat"
  ) {
    backgroundRunIds.add(data.runId);
    return;
  }
  ensureWorld();
  if (pixelWorld) pixelWorld.onRunStart(data);
});

socket.on("run:thinking", (data) => {
  if (backgroundRunIds.has(data.runId)) return;
  const textEl = $("#thinkingText");
  if (textEl) textEl.textContent = `Thinking… (step ${data.iteration})`;
  ensureWorld();
  if (pixelWorld) pixelWorld.onThinking(data);
});

socket.on("run:tool_start", (data) => {
  if (backgroundRunIds.has(data.runId)) return;
  ensureWorld();
  if (pixelWorld) pixelWorld.onToolStart(data);
  const textEl = $("#thinkingText");
  if (textEl) textEl.textContent = `${data.toolName}…`;
});

socket.on("run:tool_end", (data) => {
  if (backgroundRunIds.has(data.runId)) return;
  ensureWorld();
  if (pixelWorld) pixelWorld.onToolEnd(data);
});

socket.on("run:stream", (data) => {
  if (
    backgroundRunIds.has(data.runId) ||
    data.triggerSource === "scheduler" ||
    data.triggerSource === "heartbeat" ||
    data.triggerSource === "messaging"
  )
    return;

  const text = data.content || data;
  const chunks = text.split(/\n\n+/).filter(c => c.trim().length > 0 || c === text);

  let streamContainer = $("#streamContainer");
  if (!streamContainer) {
    const thinking = $("#thinking");
    if (thinking) thinking.remove();

    streamContainer = document.createElement("div");
    streamContainer.id = "streamContainer";
    streamContainer.className = "chat-stream-group";
    chatMessages.appendChild(streamContainer);
  }

  streamContainer.innerHTML = "";
  for (let i = 0; i < chunks.length; i++) {
    const div = document.createElement("div");
    div.className = "chat-message assistant";
    if (i > 0) div.style.marginTop = "8px";
    div.innerHTML = `<div class="chat-avatar">${i === 0 ? 'N' : ''}</div><div class="chat-bubble md-content">${renderMarkdown(chunks[i])}</div>`;
    streamContainer.appendChild(div);
  }
  requestAnimationFrame(renderMermaids);
  chatMessages.scrollTop = chatMessages.scrollHeight;
});

socket.on("run:complete", (data) => {
  const isBackground =
    backgroundRunIds.has(data.runId) ||
    data.triggerSource === "scheduler" ||
    data.triggerSource === "heartbeat";
  if (isBackground) backgroundRunIds.delete(data.runId);

  if (!isBackground) {
    const thinking = $("#thinking");
    if (thinking) thinking.remove();

    const streamContainer = $("#streamContainer");
    if (streamContainer) {
      streamContainer.id = "";
      if (data.content) {
        const chunks = data.content.split(/\n\n+/).filter(c => c.trim().length > 0 || c === data.content);
        streamContainer.innerHTML = "";
        for (let i = 0; i < chunks.length; i++) {
          const div = document.createElement("div");
          div.className = "chat-message assistant";
          if (i > 0) div.style.marginTop = "8px";
          div.innerHTML = `<div class="chat-avatar">${i === 0 ? 'N' : ''}</div><div class="chat-bubble md-content">${renderMarkdown(chunks[i])}</div>`;
          streamContainer.appendChild(div);
        }
        requestAnimationFrame(renderMermaids);
      }
    } else if (data.content && data.triggerSource !== "messaging") {
      appendMessage("assistant", data.content);
    }

    ensureWorld();
    if (pixelWorld) pixelWorld.onRunComplete(data);

    isStreaming = false;
    sendBtn.disabled = false;
  }
});

socket.on("chat:cleared", () => {
  chatMessages.innerHTML = "";
  if (chatEmpty) chatEmpty.classList.remove("hidden");
});

socket.on("run:error", (data) => {
  const thinking = $("#thinking");
  if (thinking) thinking.remove();
  const errMsg = data.error || "Unknown error";
  appendMessage("assistant", `❌ ${errMsg}`);
  ensureWorld();
  if (pixelWorld) pixelWorld.onRunError(data);
  isStreaming = false;
  sendBtn.disabled = false;
  toast(errMsg, "error");
});

// AI sends a status update during a long task
socket.on("run:interim", (data) => {
  const textEl = $("#thinkingText");
  if (textEl) textEl.textContent = data.message;
  appendInterimMessage(data.message);
  ensureWorld();
  if (pixelWorld) pixelWorld.pushEvent("note", data.message);
});

// Incoming social message → show in chat + world visualization
socket.on("messaging:message", (data) => {
  appendSocialMessage(data.platform, "user", data.content, data.senderName);
  ensureWorld();
  if (pixelWorld) pixelWorld.onMessage(data);
});

socket.on("skill:draft_created", (data) => {
  toast(`Draft skill created: ${data.name}`, "success");
  if (!$("#skillList")?.classList.contains("hidden")) {
    loadSkillsPage();
  }
});

// ── Logs Tab ──

const logsContainer = $("#logsContainer");
let logsRequested = false;

function loadLogsPage() {
  if (!logsRequested) {
    socket.emit("client:request_logs");
    logsRequested = true;
  }
}

function appendLogEntry(log) {
  if (!logsContainer) return;

  const isAtBottom =
    logsContainer.scrollHeight - logsContainer.scrollTop <=
    logsContainer.clientHeight + 50;

  const el = document.createElement("div");
  el.style.marginBottom = "4px";
  el.style.borderBottom = "1px solid #1e293b";
  el.style.paddingBottom = "4px";
  el.style.wordBreak = "break-word";
  el.style.whiteSpace = "pre-wrap";

  let color = "#e2e8f0"; // info
  if (log.type === "error")
    color = "#f87171"; // red
  else if (log.type === "warn")
    color = "#fbbf24"; // yellow
  else if (log.type === "log") color = "#94a3b8"; // gray

  const timeStr = new Date(log.timestamp).toLocaleTimeString([], {
    hour12: false,
  });
  el.innerHTML = `<span style="color:#64748b;margin-right:8px;">[${timeStr}]</span><span style="color:${color};">${escapeHtml(log.message)}</span>`;

  logsContainer.appendChild(el);

  if (isAtBottom) {
    logsContainer.scrollTop = logsContainer.scrollHeight;
  }
}

socket.on("server:log", (log) => {
  appendLogEntry(log);
});

socket.on("server:log_history", (history) => {
  if (logsContainer) {
    logsContainer.innerHTML = "";
    history.forEach(appendLogEntry);
    logsContainer.scrollTop = logsContainer.scrollHeight;
  }
});

const clearLogsBtn = $("#clearLogsBtn");
if (clearLogsBtn) {
  clearLogsBtn.addEventListener("click", () => {
    if (logsContainer) logsContainer.innerHTML = "";
  });
}

const copyLogsBtn = $("#copyLogsBtn");
if (copyLogsBtn) {
  copyLogsBtn.addEventListener("click", async () => {
    try {
      let debugText = "=== SYSTEM DEBUG INFO ===\\n\\n";

      debugText += "--- CHAT HISTORY ---\\n";
      const chats = document.querySelectorAll(".chat-message");
      chats.forEach((c) => {
        const sender = c.classList.contains("user") ? "USER" : "AI";
        const content =
          c.querySelector(".md-content")?.innerText || c.innerText;
        debugText += `[${sender}]\\n${content.trim()}\\n\\n`;
      });

      debugText += "--- WORLD EVENT FEED ---\\n";
      const entries = document.querySelectorAll(".world-event-entry");
      entries.forEach((entry) => {
        const title = entry.querySelector(".world-event-tag")?.innerText || "EVENT";
        const details =
          entry.querySelector(".world-event-text")?.innerText || "No details";
        debugText += `${title}\\n${details}\\n\\n`;
      });

      debugText += "--- CONSOLE LOGS ---\\n";
      if (logsContainer) {
        debugText += logsContainer.innerText || "No logs available.";
      }

      await navigator.clipboard.writeText(debugText);

      const originalText = copyLogsBtn.textContent;
      copyLogsBtn.textContent = "Copied!";
      setTimeout(() => {
        copyLogsBtn.textContent = originalText;
      }, 2000);

      toast("Debug info copied to clipboard", "success");
    } catch (err) {
      toast("Failed to copy debug info: " + err.message, "error");
    }
  });
}

// ── Settings ──

let updateStatusPollTimer = null;
let updateFinishNotifiedAt = null;
let backendVersionLabel = null;

function clearUpdatePoll() {
  if (updateStatusPollTimer) {
    clearInterval(updateStatusPollTimer);
    updateStatusPollTimer = null;
  }
}

function setUpdateBadgeState(state) {
  const badge = $("#updateStateBadge");
  if (!badge) return;

  badge.classList.remove("badge-neutral", "badge-info", "badge-success", "badge-error", "badge-warning");
  if (state === "running") {
    badge.classList.add("badge-info");
    badge.textContent = "Running";
  } else if (state === "completed") {
    badge.classList.add("badge-success");
    badge.textContent = "Completed";
  } else if (state === "failed") {
    badge.classList.add("badge-error");
    badge.textContent = "Failed";
  } else {
    badge.classList.add("badge-neutral");
    badge.textContent = "Idle";
  }
}

function renderUpdateStatus(status) {
  const state = status?.state || "idle";
  const progress = Math.max(0, Math.min(100, Number(status?.progress || 0)));

  setUpdateBadgeState(state);
  $("#updateProgressBar").style.width = `${progress}%`;
  $("#updatePercentLabel").textContent = `${progress}%`;
  $("#updatePhaseLabel").textContent = status?.message || "No update running";

  const before = status?.versionBefore || "—";
  const after = status?.versionAfter || "—";
  const updateVersionLabel = `${before}${after !== "—" ? ` -> ${after}` : ""}`;
  const backendLabel = backendVersionLabel ? ` | Backend: ${backendVersionLabel}` : "";
  $("#updateVersionMeta").textContent = `Update Version: ${updateVersionLabel}${backendLabel}`;

  const changelog = $("#updateChangelog");
  changelog.innerHTML = "";
  const entries = Array.isArray(status?.changelog) ? status.changelog : [];
  if (!entries.length) {
    const li = document.createElement("li");
    li.className = "settings-update-empty";
    li.textContent = "No commit changes captured";
    changelog.appendChild(li);
  } else {
    for (const line of entries) {
      const li = document.createElement("li");
      li.textContent = line;
      changelog.appendChild(li);
    }
  }

  const logs = Array.isArray(status?.logs) ? status.logs : [];
  const logsText = logs.length ? logs.slice(-120).join("\n") : "Waiting for update job output…";
  const logsEl = $("#updateLogs");
  logsEl.textContent = logsText;
  logsEl.scrollTop = logsEl.scrollHeight;

  const btn = $("#updateAppBtn");
  if (state === "running") {
    btn.disabled = true;
    btn.textContent = "Updating…";
  } else {
    btn.disabled = false;
    btn.textContent = "Update App";
  }

  if ((state === "completed" || state === "failed") && status?.completedAt && updateFinishNotifiedAt !== status.completedAt) {
    updateFinishNotifiedAt = status.completedAt;
    toast(state === "completed" ? "Update completed." : "Update failed. See logs in Settings.", state === "completed" ? "success" : "error");
  }
}

async function refreshUpdateStatus() {
  try {
    const status = await api("/settings/update/status");
    renderUpdateStatus(status);

    if (status?.state !== "running") {
      clearUpdatePoll();
    }
  } catch (err) {
    // During restart window this can fail briefly; keep trying.
    // If endpoint is unavailable (older backend), stop polling to avoid console spam.
    if (err?.status === 404) {
      clearUpdatePoll();
      $("#updatePhaseLabel").textContent = "Update status unavailable on this server version.";
      $("#updatePercentLabel").textContent = "—";
      setUpdateBadgeState("idle");
      const btn = $("#updateAppBtn");
      if (btn) btn.disabled = false;
      return;
    }
    $("#updatePhaseLabel").textContent = "Reconnecting to server…";
    setUpdateBadgeState("running");
  }
}

function ensureUpdatePolling(force = false) {
  if (force) clearUpdatePoll();
  if (!updateStatusPollTimer) {
    updateStatusPollTimer = setInterval(refreshUpdateStatus, 1800);
  }
}

function formatInt(n) {
  return Number(n || 0).toLocaleString();
}

function renderTokenUsageSummary(summary) {
  const el = $("#tokenUsageSummary");
  if (!el) return;
  const totals = summary?.totals || {};
  el.innerHTML = `
    <div>Total: <strong>${formatInt(totals.totalTokens)}</strong> tokens across <strong>${formatInt(totals.totalRuns)}</strong> runs</div>
    <div>Last 7 days: <strong>${formatInt(totals.last7DaysTokens)}</strong> tokens in <strong>${formatInt(totals.last7DaysRuns)}</strong> runs</div>
    <div>Avg/run: <strong>${formatInt(totals.avgTokensPerRun)}</strong> tokens</div>
  `;
}

$("#settingsBtn").addEventListener("click", async () => {
  try {
    const [meta, settings] = await Promise.all([
      api("/settings/meta/models"),
      api("/settings")
    ]);

    try {
      const backendVersion = await api("/version");
      backendVersionLabel = `${backendVersion?.version || "unknown"}${backendVersion?.gitSha ? ` (${backendVersion.gitSha})` : ""}`;
      const vEl = $("#settingsAppVersion");
      if (vEl && backendVersionLabel !== "unknown") {
        vEl.textContent = `v${backendVersionLabel}`;
      }
    } catch {
      backendVersionLabel = "unavailable";
    }

    try {
      const tokenUsage = await api("/settings/token-usage/summary");
      renderTokenUsageSummary(tokenUsage);
    } catch (err) {
      const tokenBox = $("#tokenUsageSummary");
      if (tokenBox) tokenBox.textContent = "Token usage unavailable on this server version.";
    }

    $("#settingHeartbeat").checked =
      settings.heartbeat_enabled === true ||
      settings.heartbeat_enabled === "true";
    $("#settingHeadlessBrowser").checked =
      settings.headless_browser !== false &&
      settings.headless_browser !== "false";
    $("#settingAutoSkillLearning").checked =
      settings.auto_skill_learning !== false &&
      settings.auto_skill_learning !== "false";

    const enabledModels = Array.isArray(settings.enabled_models) ? settings.enabled_models : (meta.models || []).map(m => m.id);

    const chatModelSelect = $("#settingDefaultChatModel");
    const subagentModelSelect = $("#settingDefaultSubagentModel");

    if (chatModelSelect && subagentModelSelect && meta.models) {
      chatModelSelect.innerHTML = '<option value="auto">Smart Selector (Auto)</option>';
      subagentModelSelect.innerHTML = '<option value="auto">Smart Selector (Auto)</option>';

      for (const modelDef of meta.models) {
        const chatOption = document.createElement("option");
        chatOption.value = modelDef.id;
        chatOption.textContent = modelDef.label;
        chatModelSelect.appendChild(chatOption);

        const subagentOption = document.createElement("option");
        subagentOption.value = modelDef.id;
        subagentOption.textContent = modelDef.label;
        subagentModelSelect.appendChild(subagentOption);
      }

      chatModelSelect.value = settings.default_chat_model || "auto";
      subagentModelSelect.value = settings.default_subagent_model || "auto";

      const indicator = $("#modelIndicator");
      if (indicator) {
        if (settings.default_chat_model && settings.default_chat_model !== "auto") {
          const selectedModel = meta.models.find(m => m.id === settings.default_chat_model);
          indicator.textContent = selectedModel ? selectedModel.label : "Smart Selector Active";
        } else {
          indicator.textContent = "Smart Selector Active";
        }
      }
    }

    const container = $("#modelCheckboxesContainer");
    if (container) {
      container.innerHTML = "";
      if (meta.models) {
        for (const modelDef of meta.models) {
          const label = document.createElement("label");
          label.className = "flex items-center gap-2";
          label.style.cursor = "pointer";

          const checkbox = document.createElement("input");
          checkbox.type = "checkbox";
          checkbox.className = "dynamic-model-checkbox";
          checkbox.dataset.modelId = modelDef.id;
          checkbox.autocomplete = "off";
          checkbox.setAttribute("data-bwignore", "true");
          checkbox.checked = enabledModels.includes(modelDef.id);

          const span = document.createElement("span");
          span.textContent = modelDef.label;

          label.appendChild(checkbox);
          label.appendChild(span);
          container.appendChild(label);
        }
      }
    }
  } catch (err) {
    console.error("Failed to load settings:", err);
    $("#settingHeadlessBrowser").checked = true; // default headless
    const tokenBox = $("#tokenUsageSummary");
    if (tokenBox) tokenBox.textContent = "Token usage unavailable.";
    backendVersionLabel = "unavailable";
  }
  await refreshUpdateStatus();
  ensureUpdatePolling(true);
  $("#settingsModal").classList.remove("hidden");
});

$("#closeSettings").addEventListener("click", () => {
  clearUpdatePoll();
  $("#settingsModal").classList.add("hidden");
});
$("#cancelSettings").addEventListener("click", () => {
  clearUpdatePoll();
  $("#settingsModal").classList.add("hidden");
});

$("#saveSettings").addEventListener("click", async () => {
  try {
    const enabledModels = Array.from(document.querySelectorAll("#modelCheckboxesContainer .dynamic-model-checkbox"))
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.modelId);

    const defaultChatModel = $("#settingDefaultChatModel").value;
    const defaultSubagentModel = $("#settingDefaultSubagentModel").value;

    await api("/settings", {
      method: "PUT",
      body: {
        heartbeat_enabled: $("#settingHeartbeat").checked,
        headless_browser: $("#settingHeadlessBrowser").checked,
        auto_skill_learning: $("#settingAutoSkillLearning").checked,
        enabled_models: enabledModels,
        default_chat_model: defaultChatModel,
        default_subagent_model: defaultSubagentModel
      },
    });

    const indicator = $("#modelIndicator");
    if (indicator) {
      if (defaultChatModel !== "auto") {
        const selectedOption = $("#settingDefaultChatModel").options[$("#settingDefaultChatModel").selectedIndex];
        indicator.textContent = selectedOption ? selectedOption.text : "Smart Selector Active";
      } else {
        indicator.textContent = "Smart Selector Active";
      }
    }

    $("#settingsModal").classList.add("hidden");
    toast("Settings saved", "success");
  } catch (err) {
    toast("Failed to save settings", "error");
  }
});

$("#updateAppBtn").addEventListener("click", async () => {
  if (!confirm("Are you sure you want to run the update script? This will trigger neoagent update and restart the server.")) return;
  try {
    await api("/settings/update", { method: "POST" });
    updateFinishNotifiedAt = null;
    toast("Update started. Live progress is shown below.", "success");
    await refreshUpdateStatus();
    ensureUpdatePolling(true);
  } catch (err) {
    toast("Failed to trigger update: " + err.message, "error");
    await refreshUpdateStatus();
  }
});

// ── Logout ──

$("#logoutBtn").addEventListener("click", async () => {
  try {
    await fetch("/api/auth/logout", { method: "POST" });
    window.location.href = "/login";
  } catch (err) {
    window.location.href = "/login";
  }
});

// ── Memory Page ──

// Category badge colours
const CAT_COLORS = {
  user_fact: {
    bg: "#3b82f620",
    border: "#3b82f6",
    text: "#3b82f6",
    label: "User Fact",
  },
  preference: {
    bg: "#8b5cf620",
    border: "#8b5cf6",
    text: "#8b5cf6",
    label: "Preference",
  },
  personality: {
    bg: "#ec489920",
    border: "#ec4899",
    text: "#ec4899",
    label: "Personality",
  },
  episodic: {
    bg: "#22c55e20",
    border: "#22c55e",
    text: "#22c55e",
    label: "Episodic",
  },
};

let _memActiveCategory = "";
let _memCurrentPage = 0;

async function loadMemoryPage() {
  try {
    const data = await api("/memory");

    // Soul
    if ($("#soulEditor")) $("#soulEditor").value = data.soul || "";

    // Daily logs
    const dailyContainer = $("#dailyLogs");
    if (dailyContainer) {
      dailyContainer.innerHTML = "";
      for (const log of data.dailyLogs || []) {
        const card = document.createElement("div");
        card.className = "item-card";
        card.innerHTML = `<div class="item-card-header"><div class="item-card-title">${escapeHtml(log.date)}</div></div><pre class="code-block">${escapeHtml(log.content || "Empty")}</pre>`;
        dailyContainer.appendChild(card);
      }
    }

    // Core memory
    _renderCoreMemory(data.coreMemory || {});

    // API keys
    const keyContainer = $("#apiKeyList");
    if (keyContainer) {
      keyContainer.innerHTML = "";
      const keys = await api("/memory/api-keys");
      for (const [name, masked] of Object.entries(keys)) {
        const card = document.createElement("div");
        card.className = "item-card flex justify-between items-center";
        card.innerHTML = `<div><div class="item-card-title">${escapeHtml(name)}</div><div class="item-card-meta font-mono">${escapeHtml(masked)}</div></div>
          <button class="btn btn-sm btn-danger" data-action="deleteApiKey" data-name="${escapeHtml(name)}">&times;</button>`;
        keyContainer.appendChild(card);
      }
    }

    // Memories list
    await _loadMemoriesTab(_memActiveCategory);
    await loadSessionRecall();
  } catch (err) {
    toast("Failed to load memory", "error");
  }
}

async function loadSessionRecall(query = "") {
  const container = $("#sessionRecallList");
  if (!container) return;
  container.innerHTML =
    '<div class="empty-state"><p>Loading session recall…</p></div>';
  try {
    const results = query
      ? await api("/memory/conversations/search", {
          method: "POST",
          body: { query, limit: 8 },
        })
      : await api("/memory/conversations?limit=12");

    if (!results.length) {
      container.innerHTML =
        '<div class="empty-state"><p>No matching sessions yet.</p></div>';
      return;
    }

    container.innerHTML = "";
    for (const item of results) {
      const card = document.createElement("div");
      card.className = "item-card";

      if (item.matches) {
        const matches = item.matches
          .map(
            (match) => `<div style="margin-top:8px;padding:8px 10px;border:1px solid var(--border);border-radius:10px;">
              <div style="font-size:0.72rem;text-transform:uppercase;color:var(--text-muted);margin-bottom:4px;">${escapeHtml(match.role || "message")}</div>
              <div style="font-size:0.9rem;line-height:1.45;">${escapeHtml(match.excerpt || "")}</div>
            </div>`
          )
          .join("");

        card.innerHTML = `
          <div class="item-card-header">
            <div>
              <div class="item-card-title">${escapeHtml(item.title || "Session")}</div>
              <div class="item-card-meta">${escapeHtml(item.source || "session")} · ${escapeHtml(item.createdAt || "")}</div>
            </div>
            <span class="badge badge-neutral">${item.matchCount || item.matches.length} match${(item.matchCount || item.matches.length) === 1 ? "" : "es"}</span>
          </div>
          ${matches}
        `;
      } else {
        card.innerHTML = `
          <div class="item-card-header">
            <div>
              <div class="item-card-title">${escapeHtml(item.title || "Session")}</div>
              <div class="item-card-meta">${escapeHtml(item.status || "completed")} · ${escapeHtml(item.completedAt || item.createdAt || "")}</div>
            </div>
          </div>
          <div style="font-size:0.9rem;line-height:1.45;color:var(--text);">${escapeHtml(item.excerpt || "No excerpt available.")}</div>
        `;
      }

      container.appendChild(card);
    }
  } catch {
    container.innerHTML =
      '<div class="empty-state"><p>Session recall failed to load.</p></div>';
  }
}

async function _loadMemoriesTab(category = "") {
  const container = $("#memoryList");
  if (!container) return;
  container.innerHTML =
    '<div class="empty-state" style="grid-column:1/-1"><p>Loading…</p></div>';
  try {
    const params = new URLSearchParams({ limit: 60, offset: 0 });
    if (category) params.set("category", category);
    const memories = await api(`/memory/memories?${params}`);
    _renderMemories(memories, container);
  } catch {
    container.innerHTML =
      '<div class="empty-state" style="grid-column:1/-1"><p>Failed to load memories</p></div>';
  }
}

function _renderMemories(memories, container) {
  container.innerHTML = "";
  if (!memories.length) {
    container.innerHTML =
      '<div class="empty-state" style="grid-column:1/-1"><p>No memories yet. The agent will save things automatically, or you can add one manually.</p></div>';
    return;
  }
  for (const mem of memories) {
    const cat = CAT_COLORS[mem.category] || CAT_COLORS.episodic;
    const dots =
      "●".repeat(Math.round(mem.importance / 2)) +
      "○".repeat(5 - Math.round(mem.importance / 2));
    const date = new Date(mem.updated_at || mem.created_at);
    const dateStr = date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "2-digit",
    });

    const card = document.createElement("div");
    card.className = "card";
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
      <div style="margin-top:8px;font-size:0.75rem;color:var(--text-muted);letter-spacing:0.03em;">${dots} <span style="margin-left:4px;">importance ${mem.importance}</span>${mem.access_count > 0 ? ` · recalled ${mem.access_count}×` : ""}</div>`;
    container.appendChild(card);
  }
}

function _renderCoreMemory(core) {
  const container = $("#coreMemoryList");
  if (!container) return;
  container.innerHTML = "";
  if (!Object.keys(core).length) {
    const empty = document.createElement("p");
    empty.className = "text-muted";
    empty.style.cssText = "font-size:0.85rem;margin-bottom:8px;";
    empty.textContent = "No core memory entries yet.";
    container.appendChild(empty);
    return;
  }
  for (const [key, val] of Object.entries(core)) {
    const row = document.createElement("div");
    row.className = "item-card";
    row.style.marginBottom = "8px";
    const display = typeof val === "object" ? JSON.stringify(val) : String(val);
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
$$("[data-mem-tab]").forEach((tab) => {
  tab.addEventListener("click", () => {
    $$("[data-mem-tab]").forEach((t) => t.classList.remove("active"));
    $$(".mem-panel").forEach((p) => p.classList.remove("active"));
    tab.classList.add("active");
    $(`#mem-${tab.dataset.memTab}`)?.classList.add("active");
  });
});

// Category filter
$("#memoryCategoryFilter")?.addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-cat]");
  if (!btn) return;
  _memActiveCategory = btn.dataset.cat;
  $$("#memoryCategoryFilter [data-cat]").forEach((b) => {
    b.className =
      b.dataset.cat === _memActiveCategory
        ? "btn btn-sm btn-primary"
        : "btn btn-sm btn-secondary";
  });
  await _loadMemoriesTab(_memActiveCategory);
});

// Semantic search
$("#memorySearchBtn")?.addEventListener("click", async () => {
  const q = $("#memorySearchInput")?.value?.trim();
  if (!q) {
    await _loadMemoriesTab(_memActiveCategory);
    return;
  }
  const container = $("#memoryList");
  container.innerHTML =
    '<div class="empty-state" style="grid-column:1/-1"><p>Searching…</p></div>';
  try {
    const results = await api("/memory/memories/recall", {
      method: "POST",
      body: { query: q, limit: 20 },
    });
    _renderMemories(results, container);
  } catch {
    container.innerHTML =
      '<div class="empty-state" style="grid-column:1/-1"><p>Search failed</p></div>';
  }
});

$("#memorySearchInput")?.addEventListener("keydown", (e) => {
  if (e.key === "Enter") $("#memorySearchBtn")?.click();
});

$("#sessionSearchBtn")?.addEventListener("click", async () => {
  const query = $("#sessionSearchInput")?.value?.trim() || "";
  await loadSessionRecall(query);
});

$("#sessionSearchInput")?.addEventListener("keydown", (e) => {
  if (e.key === "Enter") $("#sessionSearchBtn")?.click();
});

// Soul save
$("#saveSoulBtn")?.addEventListener("click", async () => {
  try {
    await api("/memory/soul", {
      method: "PUT",
      body: { content: $("#soulEditor").value },
    });
    toast("Soul saved", "success");
  } catch {
    toast("Failed to save", "error");
  }
});

// Add Memory Modal
$("#addMemoryBtn")?.addEventListener("click", () => {
  $("#addMemoryModal")?.classList.remove("hidden");
});
$("#closeAddMemory")?.addEventListener("click", () =>
  $("#addMemoryModal")?.classList.add("hidden"),
);
$("#cancelAddMemory")?.addEventListener("click", () =>
  $("#addMemoryModal")?.classList.add("hidden"),
);

$("#confirmAddMemory")?.addEventListener("click", async () => {
  const content = $("#newMemoryContent")?.value?.trim();
  if (!content) {
    toast("Content is required", "error");
    return;
  }
  const category = $("#newMemoryCategory")?.value || "episodic";
  const importance = parseInt($("#newMemoryImportance")?.value) || 5;
  try {
    await api("/memory/memories", {
      method: "POST",
      body: { content, category, importance },
    });
    $("#addMemoryModal")?.classList.add("hidden");
    $("#newMemoryContent").value = "";
    await _loadMemoriesTab(_memActiveCategory);
    toast("Memory saved", "success");
  } catch {
    toast("Failed to save memory", "error");
  }
});

// Set core memory key
$("#setCoreBtn")?.addEventListener("click", async () => {
  const key = $("#coreKeySelect")?.value;
  const value = $("#coreValueInput")?.value?.trim();
  if (!key || !value) {
    toast("Key and value are required", "error");
    return;
  }
  try {
    await api(`/memory/core/${key}`, { method: "PUT", body: { value } });
    $("#coreValueInput").value = "";
    const core = await api("/memory/core");
    _renderCoreMemory(core);
    toast("Core memory updated", "success");
  } catch {
    toast("Failed to update core memory", "error");
  }
});

// API Keys
window.deleteApiKey = async (name) => {
  try {
    await api(`/memory/api-keys/${name}`, { method: "DELETE" });
    loadMemoryPage();
    toast("Key deleted", "success");
  } catch {
    toast("Failed to delete", "error");
  }
};

$("#addApiKeyBtn")?.addEventListener("click", () => {
  const name = prompt("Service name:");
  if (!name) return;
  const key = prompt("API key value:");
  if (!key) return;
  api(`/memory/api-keys/${name}`, { method: "PUT", body: { key } })
    .then(() => {
      loadMemoryPage();
      toast("Key added", "success");
    })
    .catch(() => toast("Failed to add key", "error"));
});

// Global click delegation for memory actions
document.addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const action = btn.dataset.action;

  if (action === "deleteApiKey") {
    window.deleteApiKey(btn.dataset.name);
  } else if (action === "deleteMemory") {
    if (!confirm("Delete this memory?")) return;
    try {
      await api(`/memory/memories/${btn.dataset.id}`, { method: "DELETE" });
      await _loadMemoriesTab(_memActiveCategory);
      toast("Memory deleted", "success");
    } catch {
      toast("Failed to delete", "error");
    }
  } else if (action === "editCore") {
    const newVal = prompt(`Edit ${btn.dataset.key}:`, btn.dataset.val);
    if (newVal === null) return;
    try {
      await api(`/memory/core/${btn.dataset.key}`, {
        method: "PUT",
        body: { value: newVal },
      });
      const core = await api("/memory/core");
      _renderCoreMemory(core);
      toast("Updated", "success");
    } catch {
      toast("Failed to update", "error");
    }
  } else if (action === "deleteCore") {
    if (!confirm(`Delete core key "${btn.dataset.key}"?`)) return;
    try {
      await api(`/memory/core/${btn.dataset.key}`, { method: "DELETE" });
      const core = await api("/memory/core");
      _renderCoreMemory(core);
      toast("Deleted", "success");
    } catch {
      toast("Failed to delete", "error");
    }
  }
});

// ── Skills Page ──

// Tab switching for skills page
document.querySelectorAll("[data-skills-tab]").forEach((tab) => {
  tab.addEventListener("click", () => {
    document
      .querySelectorAll("[data-skills-tab]")
      .forEach((t) => t.classList.remove("active"));
    tab.classList.add("active");
    const which = tab.dataset.skillsTab;
    $("#skillList").classList.toggle("hidden", which !== "installed");
    $("#skillStore").classList.toggle("hidden", which !== "store");
    if (which === "store") loadSkillStore();
    else loadSkillsPage();
  });
});

async function loadSkillStore(options = {}) {
  const wrap = $("#skillStore");
  const pageBody = wrap.closest(".page-body");
  const shouldPreserveState = !!options.preserveState;
  const previousState = {
    filter: wrap.dataset.storeFilter || "",
    pageScrollTop: pageBody ? pageBody.scrollTop : 0,
    panelScrollTop: wrap.scrollTop || 0,
  };

  wrap.innerHTML = '<div class="empty-state"><p>Loading store…</p></div>';
  try {
    const items = await api("/store");

    // Build category groups
    const cats = {};
    for (const item of items) {
      if (!cats[item.category]) cats[item.category] = [];
      cats[item.category].push(item);
    }

    const CAT_LABELS = {
      system: "⚙️ System",
      network: "📡 Network",
      info: "ℹ️ Info",
      dev: "🛠 Dev",
      productivity: "🗂 Productivity",
      fun: "🎲 Fun",
      maker: "🖨️ Maker",
    };

    wrap.innerHTML = "";

    // Search input
    const searchRow = document.createElement("div");
    searchRow.style.cssText = "margin-bottom:16px;";
    const searchInp = document.createElement("input");
    searchInp.type = "text";
    searchInp.className = "input";
    searchInp.placeholder = "Search skills…";
    searchInp.value = previousState.filter;
    searchRow.appendChild(searchInp);
    wrap.appendChild(searchRow);

    const cardsWrap = document.createElement("div");
    wrap.appendChild(cardsWrap);

    function renderStore(filter) {
      cardsWrap.innerHTML = "";
      let totalShown = 0;
      for (const [cat, catItems] of Object.entries(cats)) {
        const visible = catItems.filter(
          (i) =>
            !filter ||
            i.name.toLowerCase().includes(filter) ||
            i.description.toLowerCase().includes(filter),
        );
        if (!visible.length) continue;
        totalShown += visible.length;

        const section = document.createElement("div");
        section.style.cssText = "margin-bottom:28px;";
        section.innerHTML = `<div style="font-size:0.8rem;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-muted);margin-bottom:10px;">${CAT_LABELS[cat] || cat}</div>`;

        const grid = document.createElement("div");
        grid.style.cssText =
          "display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:10px;";

        for (const item of visible) {
          const card = document.createElement("div");
          card.className = "card";
          card.style.cssText =
            "display:flex;flex-direction:column;gap:8px;padding:14px;";
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
      if (!totalShown)
        cardsWrap.innerHTML =
          '<div class="empty-state"><p>No matching skills</p></div>';
    }

    renderStore(previousState.filter.trim().toLowerCase());

    searchInp.addEventListener("input", () => {
      wrap.dataset.storeFilter = searchInp.value;
      renderStore(searchInp.value.trim().toLowerCase());
    });

    cardsWrap.addEventListener("click", async (e) => {
      const btn = e.target.closest("[data-store-action]");
      if (!btn) return;
      const { storeAction, storeId } = btn.dataset;
      btn.disabled = true;
      btn.textContent = storeAction === "install" ? "Installing…" : "Removing…";
      try {
        if (storeAction === "install") {
          await api(`/store/${storeId}/install`, { method: "POST" });
          toast("Skill installed!", "success");
        } else {
          await api(`/store/${storeId}/uninstall`, { method: "DELETE" });
          toast("Skill removed", "info");
        }
        await loadSkillStore({ preserveState: true }); // refresh without jumping back to top
      } catch (err) {
        toast("Error: " + err.message, "error");
        btn.disabled = false;
      }
    });

    if (shouldPreserveState) {
      requestAnimationFrame(() => {
        if (pageBody) pageBody.scrollTop = previousState.pageScrollTop;
        wrap.scrollTop = previousState.panelScrollTop;
      });
    }
  } catch (err) {
    wrap.innerHTML =
      '<div class="empty-state"><p>Failed to load store</p></div>';
    console.error(err);
  }
}

async function loadSkillsPage() {
  try {
    const skills = await api("/skills");
    const container = $("#skillList");
    container.innerHTML = "";

    if (skills.length === 0) {
      container.innerHTML =
        '<div class="empty-state"><p>No skills installed yet. <a href="#" id="goToStore">Browse the store →</a></p></div>';
      document.getElementById("goToStore")?.addEventListener("click", (e) => {
        e.preventDefault();
        document.querySelector('[data-skills-tab="store"]')?.click();
      });
      return;
    }

    for (const skill of skills) {
      const card = document.createElement("div");
      card.className = "item-card";
      const badges = [
        `<span class="badge ${skill.enabled ? "badge-success" : "badge-neutral"}">${skill.enabled ? "Active" : "Disabled"}</span>`,
      ];
      if (skill.draft) badges.push('<span class="badge badge-warning">Draft</span>');
      if (skill.autoCreated) badges.push('<span class="badge badge-info">Auto-learned</span>');
      card.innerHTML = `
        <div class="item-card-header">
          <div>
            <div class="item-card-title">${escapeHtml(skill.name)}</div>
            <div class="item-card-meta">${escapeHtml(skill.description)}</div>
          </div>
          <div class="item-card-actions">
            ${badges.join("")}
            <button class="btn btn-sm btn-secondary" data-action="toggleSkill" data-name="${escapeHtml(skill.name)}" data-enabled="${skill.enabled ? "true" : "false"}">${skill.enabled ? "Disable" : "Enable"}</button>
            <button class="btn btn-sm btn-secondary" data-action="editSkill" data-name="${escapeHtml(skill.name)}">Edit</button>
            <button class="btn btn-sm btn-danger" data-action="deleteSkill" data-name="${escapeHtml(skill.name)}">&times;</button>
          </div>
        </div>
        <div class="item-card-meta">Trigger: ${escapeHtml(skill.trigger || "N/A")} | Category: ${escapeHtml(skill.category)} | Source: ${escapeHtml(skill.source || "local")}</div>
        <div class="item-card-meta" style="margin-top:6px;">${escapeHtml(skill.filePath || "")}</div>
      `;
      container.appendChild(card);
    }
  } catch (err) {
    toast("Failed to load skills", "error");
  }
}

window.editSkill = async (name) => {
  try {
    const data = await api(`/skills/${name}`);
    const content = prompt("Edit skill content:", data.content);
    if (content !== null) {
      await api(`/skills/${name}`, { method: "PUT", body: { content } });
      loadSkillsPage();
      toast("Skill updated", "success");
    }
  } catch (err) {
    toast("Failed to edit skill", "error");
  }
};

window.deleteSkill = async (name) => {
  if (!confirm(`Delete skill ${name}?`)) return;
  try {
    await api(`/skills/${name}`, { method: "DELETE" });
    loadSkillsPage();
    toast("Skill deleted", "success");
  } catch (err) {
    toast("Failed to delete", "error");
  }
};

window.toggleSkill = async (name, enabled) => {
  try {
    await api(`/skills/${name}`, {
      method: "PUT",
      body: { enabled },
    });
    loadSkillsPage();
    toast(enabled ? "Skill enabled" : "Skill disabled", "success");
  } catch (err) {
    toast("Failed to update skill", "error");
  }
};

// Skills event delegation
$("#skillList").addEventListener("click", (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const action = btn.dataset.action;
  if (action === "editSkill") window.editSkill(btn.dataset.name);
  else if (action === "deleteSkill") window.deleteSkill(btn.dataset.name);
  else if (action === "toggleSkill")
    window.toggleSkill(btn.dataset.name, btn.dataset.enabled !== "true");
});

$("#addSkillBtn").addEventListener("click", () => {
  const name = prompt("Skill filename (without .md):");
  if (!name) return;
  const content = `---\nname: ${name}\ndescription: \ntrigger: \ncategory: general\nenabled: true\n---\n\n# ${name}\n\nDescribe the skill here.`;
  api("/skills", { method: "POST", body: { filename: name, content } })
    .then(() => {
      loadSkillsPage();
      toast("Skill created", "success");
    })
    .catch(() => toast("Failed to create skill", "error"));
});

// ── MCP Servers Page ──

async function loadMCPPage() {
  try {
    const servers = await api("/mcp");
    const container = $("#mcpServerList");
    container.innerHTML = "";

    if (servers.length === 0) {
      container.innerHTML =
        '<div class="empty-state"><p>No MCP servers configured</p></div>';
      return;
    }

    for (const srv of servers) {
      const card = document.createElement("div");
      card.className = "item-card";
      card.innerHTML = `
        <div class="item-card-header">
          <div>
            <div class="item-card-title">${escapeHtml(srv.name)}</div>
            <div class="item-card-meta font-mono">${escapeHtml(srv.command)}</div>
          </div>
          <div class="item-card-actions">
            <span class="badge ${srv.status === "running" ? "badge-success" : "badge-neutral"}">${srv.status}</span>
            ${srv.status === "running"
          ? `<button class="btn btn-sm btn-secondary" data-action="stopMCP" data-id="${srv.id}">Stop</button>`
          : `<button class="btn btn-sm btn-primary" data-action="startMCP" data-id="${srv.id}">Start</button>`
        }
            ${srv.config?.auth?.type === "oauth" ? `<button class="btn btn-sm btn-primary" data-action="loginMCP" data-id="${srv.id}">Login</button>` : ""}
            <button class="btn btn-sm btn-secondary" data-action="editMCP" data-id="${srv.id}" data-name="${escapeHtml(srv.name)}" data-url="${escapeHtml(srv.command)}" data-config='${escapeHtml(JSON.stringify(srv.config || {}))}'>Edit</button>
            <button class="btn btn-sm btn-danger" data-action="deleteMCP" data-id="${srv.id}">&times;</button>
          </div>
        </div>
        ${srv.toolCount > 0 ? `<div class="item-card-meta">${srv.toolCount} tools available</div>` : ""}
      `;
      container.appendChild(card);
    }
  } catch (err) {
    toast("Failed to load MCP servers", "error");
  }
}

window.startMCP = async (id) => {
  try {
    await api(`/mcp/${id}/start`, { method: "POST" });
    loadMCPPage();
    toast("Server started", "success");
  } catch (err) {
    toast(err.message, "error");
  }
};

window.stopMCP = async (id) => {
  try {
    await api(`/mcp/${id}/stop`, { method: "POST" });
    loadMCPPage();
    toast("Server stopped", "success");
  } catch (err) {
    toast(err.message, "error");
  }
};

window.deleteMCP = async (id) => {
  if (!confirm("Delete this MCP server?")) return;
  try {
    await api(`/mcp/${id}`, { method: "DELETE" });
    loadMCPPage();
    toast("Server deleted", "success");
  } catch (err) {
    toast("Failed to delete", "error");
  }
};

// MCP event delegation
$("#mcpServerList").addEventListener("click", (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const id = btn.dataset.id;
  const action = btn.dataset.action;
  if (action === "startMCP") window.startMCP(id);
  else if (action === "stopMCP") window.stopMCP(id);
  else if (action === "deleteMCP") window.deleteMCP(id);
  else if (action === "loginMCP") {
    const w = window.open(
      `/api/mcp/${id}/start`,
      "oauth",
      "width=600,height=700",
    );
    // We expect the server to return 302 or JSON with `{status: 'oauth_redirect', url}` for a normal GET/POST
    // Let's first make an API call to get the URL, then window.open that URL
    api(`/mcp/${id}/start`, { method: "POST" })
      .then((res) => {
        if (res.status === "oauth_redirect") {
          window.open(res.url, "oauth", "width=600,height=700");
        } else {
          toast("Server started without needing login", "success");
          loadMCPPage();
        }
      })
      .catch((err) => toast("Login failed: " + err.message, "error"));
  } else if (action === "editMCP") {
    $("#mcpModalTitle").textContent = "Edit MCP Server";
    $("#mcpName").value = btn.dataset.name;
    $("#mcpUrl").value = btn.dataset.url;
    $("#mcpModal").dataset.id = id;

    // Auth fields
    const config = JSON.parse(btn.dataset.config || "{}");
    const auth = config.auth || {};
    $("#mcpAuthType").value = auth.type || "none";
    $("#mcpAuthToken").value = auth.token || "";
    $("#mcpAuthClientId").value = auth.clientId || "";
    $("#mcpAuthServerUrl").value = auth.authServerUrl || "";
    updateMcpAuthFields();

    $("#mcpModal").classList.remove("hidden");
  }
});

function updateMcpAuthFields() {
  const type = $("#mcpAuthType").value;

  if (type === "bearer") {
    $("#mcpAuthBearerGroup").classList.remove("hidden");
    $("#mcpAuthOauthGroup").classList.add("hidden");
  } else if (type === "oauth") {
    $("#mcpAuthBearerGroup").classList.add("hidden");
    $("#mcpAuthOauthGroup").classList.remove("hidden");
  } else {
    $("#mcpAuthBearerGroup").classList.add("hidden");
    $("#mcpAuthOauthGroup").classList.add("hidden");
  }
}

$("#mcpAuthType").addEventListener("change", updateMcpAuthFields);
$("#mcpAuthType").addEventListener("input", updateMcpAuthFields);

$("#addMcpBtn").addEventListener("click", () => {
  $("#mcpName").value = "";
  $("#mcpUrl").value = "";
  $("#mcpAuthType").value = "none";
  $("#mcpAuthToken").value = "";
  $("#mcpAuthClientId").value = "";
  $("#mcpAuthServerUrl").value = "";
  updateMcpAuthFields();

  $("#mcpModalTitle").textContent = "Add MCP Server";
  $("#mcpModal").dataset.id = "";
  $("#mcpModal").classList.remove("hidden");
});

$("#closeMcpModal").addEventListener("click", () =>
  $("#mcpModal").classList.add("hidden"),
);
$("#cancelMcpModal").addEventListener("click", () =>
  $("#mcpModal").classList.add("hidden"),
);

$("#saveMcpBtn").addEventListener("click", () => {
  const name = $("#mcpName").value.trim();
  const url = $("#mcpUrl").value.trim();
  if (!name || !url) {
    toast("Name and URL are required", "error");
    return;
  }

  const id = $("#mcpModal").dataset.id;
  const method = id ? "PUT" : "POST";
  const endpoint = id ? `/mcp/${id}` : "/mcp";

  const authType = $("#mcpAuthType").value;
  const auth = { type: authType };
  if (authType === "bearer") auth.token = $("#mcpAuthToken").value.trim();
  if (authType === "oauth") {
    auth.clientId = $("#mcpAuthClientId").value.trim();
    auth.authServerUrl = $("#mcpAuthServerUrl").value.trim();
  }

  api(endpoint, {
    method,
    body: { name, command: url, config: { auth }, enabled: true },
  })
    .then(() => {
      loadMCPPage();
      $("#mcpModal").classList.add("hidden");
      toast(id ? "Server updated" : "Server added", "success");
    })
    .catch((err) => toast("Failed to save server: " + err.message, "error"));
});

// Listen for popup messages to refresh auth
window.addEventListener("message", (e) => {
  if (e.data?.type === "mcp_oauth_success") {
    toast("OAuth authentication successful!", "success");
    loadMCPPage();
  }
});

// ── Scheduler Page ──

async function loadSchedulerPage() {
  try {
    const tasks = await api("/scheduler");
    const container = $("#taskList");
    container.innerHTML = "";

    if (tasks.length === 0) {
      container.innerHTML =
        '<div class="empty-state"><p>No scheduled tasks</p></div>';
      return;
    }

    for (const task of tasks) {
      const card = document.createElement("div");
      card.className = "item-card";
      card.innerHTML = `
        <div class="item-card-header">
          <div>
            <div class="item-card-title">${escapeHtml(task.name)}</div>
            <div class="item-card-meta font-mono">${escapeHtml(task.cronExpression)}</div>
          </div>
          <div class="item-card-actions">
            <span class="badge ${task.enabled ? "badge-success" : "badge-neutral"}">${task.enabled ? "Active" : "Paused"}</span>
            <button class="btn btn-sm btn-primary" data-action="runTask" data-id="${task.id}">Run Now</button>
            <button class="btn btn-sm btn-danger" data-action="deleteTask" data-id="${task.id}">&times;</button>
          </div>
        </div>
        <div class="item-card-meta">${escapeHtml(task.config?.prompt?.slice(0, 100) || "No prompt")}${task.lastRun ? ` | Last run: ${formatTime(task.lastRun)}` : ""}</div>
      `;
      container.appendChild(card);
    }
  } catch (err) {
    toast("Failed to load tasks", "error");
  }
}

window.runTask = async (id) => {
  try {
    await api(`/scheduler/${id}/run`, { method: "POST" });
    toast("Task started", "success");
  } catch (err) {
    toast(err.message, "error");
  }
};

window.deleteTask = async (id) => {
  if (!confirm("Delete this task?")) return;
  try {
    await api(`/scheduler/${id}`, { method: "DELETE" });
    loadSchedulerPage();
    toast("Task deleted", "success");
  } catch (err) {
    toast("Failed to delete", "error");
  }
};

// Scheduler event delegation
$("#taskList").addEventListener("click", (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const id = btn.dataset.id;
  const action = btn.dataset.action;
  if (action === "runTask") window.runTask(id);
  else if (action === "deleteTask") window.deleteTask(id);
});

$("#addTaskBtn").addEventListener("click", () => {
  const name = prompt("Task name:");
  if (!name) return;
  const cronExpression = prompt(
    "Cron expression (e.g., */30 * * * * for every 30 min):",
  );
  if (!cronExpression) return;
  const promptText = prompt("What should the agent do?");
  if (!promptText) return;

  api("/scheduler", {
    method: "POST",
    body: { name, cronExpression, prompt: promptText },
  })
    .then(() => {
      loadSchedulerPage();
      toast("Task created", "success");
    })
    .catch((err) => toast(err.message, "error"));
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
  {
    id: "text",
    label: "Text & Chat",
    description: "Send and receive messages",
  },
  {
    id: "voice",
    label: "Voice Calls",
    description: "Inbound & outbound phone calls",
  },
];

const MESSAGING_PLATFORMS = [
  {
    id: "whatsapp",
    name: "WhatsApp",
    group: "text",
    color: "#25D366",
    connectMethod: "qr",
  },
  {
    id: "telegram",
    name: "Telegram",
    group: "text",
    color: "#2AABEE",
    connectMethod: "config",
  },
  {
    id: "discord",
    name: "Discord",
    group: "text",
    color: "#5865F2",
    connectMethod: "config",
  },
  {
    id: "telnyx",
    name: "Telnyx Voice",
    group: "voice",
    color: "#00C8A0",
    connectMethod: "config",
  },
];

function normalizeWhatsAppWhitelistEntry(value) {
  const raw = String(value || "").trim().toLowerCase();
  if (!raw) return "";
  const base = raw.includes("@") ? raw.split("@")[0] : raw;
  const primary = base.includes(":") ? base.split(":")[0] : base;
  const digits = primary.replace(/\D/g, "");
  return digits || primary;
}

function normalizeWhatsAppWhitelist(list) {
  const seen = new Set();
  const normalized = [];
  for (const entry of Array.isArray(list) ? list : []) {
    const value = normalizeWhatsAppWhitelistEntry(entry);
    if (!value || seen.has(value)) continue;
    seen.add(value);
    normalized.push(value);
  }
  return normalized;
}

// Per-platform whitelist config
const PLATFORM_WHITELIST = {
  whatsapp: {
    settingKey: "platform_whitelist_whatsapp",
    label: "Approved contacts",
    emptyHint:
      "No approved contacts yet — senders are added via the allow popup.",
    allowAdd: false,
    saveFn: async (list) =>
      api("/settings", {
        method: "PUT",
        body: {
          platform_whitelist_whatsapp: JSON.stringify(
            normalizeWhatsAppWhitelist(list),
          ),
        },
      }),
  },
  telnyx: {
    settingKey: "platform_whitelist_telnyx",
    label: "Allowed callers",
    emptyHint:
      "Empty — all inbound callers blocked (or gated via secret code if set).",
    allowAdd: true,
    addPlaceholder: "e.g. +12125550100",
    saveFn: async (list) =>
      api("/messaging/telnyx/whitelist", {
        method: "PUT",
        body: { numbers: list },
      }),
  },
  discord: {
    settingKey: "platform_whitelist_discord",
    label: "Approved users, servers & channels",
    emptyHint:
      "No entries — all messages blocked. Add entries via the allow popup or manually below.",
    allowAdd: true,
    addTypes: ["user", "guild", "channel"],
    saveFn: async (list) =>
      api("/messaging/discord/whitelist", {
        method: "PUT",
        body: { ids: list },
      }),
  },
  telegram: {
    settingKey: "platform_whitelist_telegram",
    label: "Approved users & groups",
    emptyHint:
      "No entries — all messages blocked. Add entries via the allow popup or manually below.",
    allowAdd: true,
    addTypes: ["user", "group"],
    saveFn: async (list) =>
      api("/messaging/telegram/whitelist", {
        method: "PUT",
        body: { ids: list },
      }),
  },
};

async function loadMessagingPage() {
  try {
    const [statuses, settings] = await Promise.all([
      api("/messaging/status"),
      api("/settings"),
    ]);
    const container = $("#platformList");
    container.innerHTML = "";

    for (const group of MESSAGING_PLATFORM_GROUPS) {
      const groupPlatforms = MESSAGING_PLATFORMS.filter(
        (p) => p.group === group.id,
      );

      // Section header
      const section = document.createElement("div");
      section.style.cssText = "margin-bottom:28px;";

      const heading = document.createElement("div");
      heading.style.cssText =
        "display:flex;align-items:baseline;gap:10px;margin-bottom:14px;padding-bottom:8px;border-bottom:1px solid var(--border);";
      heading.innerHTML = `
        <span style="font-size:0.95rem;font-weight:700;">${escapeHtml(group.label)}</span>
        <span style="font-size:0.78rem;color:var(--text-muted);">${escapeHtml(group.description)}</span>`;
      section.appendChild(heading);

      // Grid — 2 cols for text/chat, single col for voice
      const grid = document.createElement("div");
      grid.style.cssText =
        group.id === "text"
          ? "display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px;"
          : "display:flex;flex-direction:column;gap:14px;";

      for (const platform of groupPlatforms) {
        const info = statuses[platform.id] || { status: "not_configured" };
        const wlCfg = PLATFORM_WHITELIST[platform.id];
        const isConnected = info.status === "connected";
        const isConnecting =
          info.status === "connecting" || info.status === "awaiting_qr";

        let wlList = [];
        try {
          const raw = settings[wlCfg.settingKey];
          if (raw) {
            wlList = typeof raw === "string" ? JSON.parse(raw) : raw;
          }
          if (!Array.isArray(wlList)) wlList = [];
        } catch {
          wlList = [];
        }

        // Auth subtitle
        let authSub = "";
        if (isConnected) {
          if (info.authInfo?.phoneNumber)
            authSub = escapeHtml(info.authInfo.phoneNumber);
          else if (info.authInfo?.tag) authSub = escapeHtml(info.authInfo.tag);
          else if (info.authInfo?.username)
            authSub = "@" + escapeHtml(info.authInfo.username);
        }

        const card = document.createElement("div");
        card.className = "card";
        card.style.cssText = "margin:0;";

        // ── Top row: logo + name + status + buttons
        const topRow = document.createElement("div");
        topRow.className = "flex items-center justify-between";
        topRow.innerHTML = `
          <div class="flex items-center gap-3">
            <div style="width:40px;height:40px;flex-shrink:0;border-radius:10px;overflow:hidden;">${_svgLogo[platform.id] || ""}</div>
            <div>
              <div class="item-card-title" style="font-size:0.97rem;">${escapeHtml(platform.name)}</div>
              <div class="flex items-center gap-2 mt-1" style="flex-wrap:wrap;">
                <span class="badge ${isConnected ? "badge-success" : "badge-neutral"}" style="font-size:0.7rem;">
                  ${escapeHtml(info.status.replace(/_/g, " "))}
                </span>
                ${authSub ? `<span class="text-xs text-muted">${authSub}</span>` : ""}
                ${!isConnected && info.lastConnected ? `<span class="text-xs text-muted">last seen ${formatTime(info.lastConnected)}</span>` : ""}
              </div>
            </div>
          </div>
          <div class="flex gap-2" style="flex-shrink:0;">
            ${isConnected
            ? `<button class="btn btn-sm btn-secondary" data-action="disconnectPlatform" data-platform="${platform.id}">Disconnect</button>
                 <button class="btn btn-sm btn-danger"     data-action="logoutPlatform"     data-platform="${platform.id}">Logout</button>`
            : isConnecting
              ? `<span class="text-muted text-sm" style="padding:0 4px;">Connecting…</span>`
              : `<button class="btn btn-sm btn-primary" data-action="connectPlatform" data-platform="${platform.id}" data-method="${platform.connectMethod}">Connect</button>`
          }
          </div>`;
        card.appendChild(topRow);

        // ── Whitelist collapsible strip
        const strip = document.createElement("div");
        strip.style.cssText =
          "border-top:1px solid var(--border);margin:14px -20px 0;";

        const arrowId = `wl-arrow-${platform.id}`;
        const labelId = `wl-label-${platform.id}`;
        const toggleBtn = document.createElement("button");
        toggleBtn.style.cssText =
          "display:flex;align-items:center;gap:7px;width:100%;background:none;border:none;cursor:pointer;padding:9px 20px;color:var(--text-muted);font-size:0.8rem;user-select:none;";
        toggleBtn.innerHTML = `<span id="${arrowId}" style="font-size:0.65rem;transition:transform 0.15s;display:inline-block;">&#9654;</span>
          <span id="${labelId}">${_wlLabel(wlCfg.label, wlList.length)}</span>`;

        const panel = document.createElement("div");
        panel.id = `wl-panel-${platform.id}`;
        panel.style.cssText = "display:none;padding:4px 20px 14px;";
        _buildWhitelistPanel(panel, wlList, wlCfg, platform.id);

        toggleBtn.addEventListener("click", () => {
          const open = panel.style.display !== "none";
          panel.style.display = open ? "none" : "block";
          document.getElementById(arrowId).style.transform = open
            ? ""
            : "rotate(90deg)";
        });

        strip.appendChild(toggleBtn);
        strip.appendChild(panel);
        card.appendChild(strip);

        // ── Telnyx-only: voice secret code ─────────────────────────────────
        if (platform.id === "telnyx") {
          const secretStrip = document.createElement("div");
          secretStrip.style.cssText =
            "border-top:1px solid var(--border);margin:0 -20px;";

          const secretArrowId = `secret-arrow-telnyx`;
          const secretToggle = document.createElement("button");
          secretToggle.style.cssText =
            "display:flex;align-items:center;gap:7px;width:100%;background:none;border:none;cursor:pointer;padding:9px 20px;color:var(--text-muted);font-size:0.8rem;user-select:none;";
          secretToggle.innerHTML = `<span id="${secretArrowId}" style="font-size:0.65rem;transition:transform 0.15s;display:inline-block;">&#9654;</span>
            <span>Voice secret code</span>`;

          const secretPanel = document.createElement("div");
          secretPanel.style.cssText = "display:none;padding:4px 20px 14px;";

          const currentSecret = settings["platform_voice_secret_telnyx"] || "";
          secretPanel.innerHTML = `
            <p class="text-xs text-muted" style="margin:0 0 8px;">Digits-only PIN non-whitelisted callers must type within 10 s of calling. Wrong code or timeout bans the number for 10 min. Leave empty to reject all non-whitelisted callers immediately.</p>
            <div style="display:flex;gap:8px;align-items:center;">
              <input id="telnyx-secret-input" type="password" class="input" style="flex:1;max-width:200px;" placeholder="e.g. 1234" value="${escapeHtml(currentSecret)}" autocomplete="off" inputmode="numeric"/>
              <button id="telnyx-secret-save" class="btn btn-primary btn-sm">Save</button>
              <button id="telnyx-secret-clear" class="btn btn-sm btn-secondary">Clear</button>
            </div>`;

          secretToggle.addEventListener("click", () => {
            const open = secretPanel.style.display !== "none";
            secretPanel.style.display = open ? "none" : "block";
            document.getElementById(secretArrowId).style.transform = open
              ? ""
              : "rotate(90deg)";
          });

          secretPanel.addEventListener("click", async (e) => {
            if (e.target.id === "telnyx-secret-save") {
              const val = document.getElementById("telnyx-secret-input").value;
              try {
                await api("/messaging/telnyx/voice-secret", {
                  method: "PUT",
                  body: { secret: val },
                });
                toast("Secret code saved", "success");
              } catch {
                toast("Failed to save secret", "error");
              }
            } else if (e.target.id === "telnyx-secret-clear") {
              document.getElementById("telnyx-secret-input").value = "";
              try {
                await api("/messaging/telnyx/voice-secret", {
                  method: "PUT",
                  body: { secret: "" },
                });
                toast("Secret code cleared", "success");
              } catch {
                toast("Failed to clear secret", "error");
              }
            }
          });

          secretStrip.appendChild(secretToggle);
          secretStrip.appendChild(secretPanel);
          card.appendChild(secretStrip);
        }

        grid.appendChild(card);
      }

      section.appendChild(grid);
      container.appendChild(section);
    }
  } catch (err) {
    console.error(err);
    toast("Failed to load messaging", "error");
  }
}

function _wlLabel(label, count) {
  return count
    ? `${label} <strong style="color:var(--text);font-weight:600;">(${count})</strong>`
    : `${label} <span style="opacity:0.55;">— none</span>`;
}

function _buildWhitelistPanel(panel, list, wlCfg, platformId) {
  panel.innerHTML = "";

  // Type-badge colours for Discord prefixed entries
  const TYPE_COLORS = {
    user: "#5865F2",
    guild: "#57F287",
    channel: "#FEE75C",
    group: "#2AABEE",
  };
  const TYPE_LABELS = {
    user: "User",
    guild: "Server",
    channel: "Channel",
    group: "Group",
  };

  if (!list.length) {
    const empty = document.createElement("p");
    empty.className = "text-xs text-muted";
    empty.style.margin = "0 0 6px";
    empty.textContent = wlCfg.emptyHint;
    panel.appendChild(empty);
  } else {
    const tags = document.createElement("div");
    tags.style.cssText =
      "display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px;";
    for (const entry of list) {
      // Parse optional prefix
      const colon = entry.indexOf(":");
      const entryType =
        colon > 0 &&
          ["user", "guild", "channel"].includes(entry.slice(0, colon))
          ? entry.slice(0, colon)
          : null;
      const entryId = colon > 0 ? entry.slice(colon + 1) : entry;

      const tag = document.createElement("span");
      tag.style.cssText =
        "display:inline-flex;align-items:center;gap:5px;background:var(--bg-secondary);border:1px solid var(--border);border-radius:999px;padding:2px 10px 2px 8px;font-size:0.81rem;";

      if (entryType) {
        const badge = document.createElement("span");
        badge.style.cssText = `background:${TYPE_COLORS[entryType] || "#888"};color:#000;border-radius:999px;padding:1px 7px;font-size:0.71rem;font-weight:600;`;
        badge.textContent = TYPE_LABELS[entryType] || entryType;
        tag.appendChild(badge);
        tag.appendChild(document.createTextNode(" " + entryId));
      } else {
        tag.appendChild(document.createTextNode(entry));
      }

      const removeBtn = document.createElement("button");
      removeBtn.style.cssText =
        "background:none;border:none;cursor:pointer;color:var(--text-muted);padding:0;font-size:1rem;line-height:1;margin-left:2px;";
      removeBtn.textContent = "×";
      removeBtn.title = "Remove";
      removeBtn.addEventListener("click", async () => {
        const newList = list.filter((n) => n !== entry);
        try {
          await wlCfg.saveFn(newList);
          list = newList;
          _buildWhitelistPanel(panel, list, wlCfg, platformId);
          const lbl = document.getElementById(`wl-label-${platformId}`);
          if (lbl) lbl.innerHTML = _wlLabel(wlCfg.label, newList.length);
        } catch {
          toast("Failed to remove", "error");
        }
      });
      tag.appendChild(removeBtn);
      tags.appendChild(tag);
    }
    panel.appendChild(tags);
  }

  if (wlCfg.allowAdd) {
    const row = document.createElement("div");
    row.style.cssText = "display:flex;gap:8px;align-items:center;";

    if (wlCfg.addTypes) {
      // Type selector + ID input for Discord
      const sel = document.createElement("select");
      sel.className = "input";
      sel.style.cssText = "flex:0 0 auto;width:110px;";
      for (const t of wlCfg.addTypes) {
        const opt = document.createElement("option");
        opt.value = t;
        opt.textContent = TYPE_LABELS[t] || t;
        sel.appendChild(opt);
      }
      const inp = document.createElement("input");
      inp.type = "text";
      inp.className = "input";
      inp.style.flex = "1";
      inp.placeholder = "Snowflake ID";
      const addBtn = document.createElement("button");
      addBtn.className = "btn btn-primary btn-sm";
      addBtn.textContent = "Add";
      addBtn.addEventListener("click", async () => {
        const id = inp.value.replace(/[^0-9]/g, "").trim();
        if (!id) return;
        const val = `${sel.value}:${id}`;
        if (list.includes(val)) {
          toast("Already in list", "info");
          return;
        }
        const newList = [...list, val];
        try {
          await wlCfg.saveFn(newList);
          list = newList;
          inp.value = "";
          _buildWhitelistPanel(panel, list, wlCfg, platformId);
          const lbl = document.getElementById(`wl-label-${platformId}`);
          if (lbl) lbl.innerHTML = _wlLabel(wlCfg.label, newList.length);
        } catch {
          toast("Failed to add", "error");
        }
      });
      inp.addEventListener("keydown", (e) => {
        if (e.key === "Enter") addBtn.click();
      });
      row.appendChild(sel);
      row.appendChild(inp);
      row.appendChild(addBtn);
    } else {
      // Plain input for telnyx numbers
      const inp = document.createElement("input");
      inp.type = "text";
      inp.className = "input";
      inp.style.flex = "1";
      inp.placeholder = wlCfg.addPlaceholder || "+12125550100";
      const addBtn = document.createElement("button");
      addBtn.className = "btn btn-primary btn-sm";
      addBtn.textContent = "Add";
      addBtn.addEventListener("click", async () => {
        const val = inp.value.replace(/[^0-9+]/g, "").trim();
        if (!val) return;
        if (list.includes(val)) {
          toast("Already in list", "info");
          return;
        }
        const newList = [...list, val];
        try {
          await wlCfg.saveFn(newList);
          list = newList;
          inp.value = "";
          _buildWhitelistPanel(panel, list, wlCfg, platformId);
          const lbl = document.getElementById(`wl-label-${platformId}`);
          if (lbl) lbl.innerHTML = _wlLabel(wlCfg.label, newList.length);
        } catch {
          toast("Failed to add", "error");
        }
      });
      inp.addEventListener("keydown", (e) => {
        if (e.key === "Enter") addBtn.click();
      });
      row.appendChild(inp);
      row.appendChild(addBtn);
    }
    panel.appendChild(row);
  }
}

async function loadWhitelistUI() {
  /* replaced — whitelist is now inline in each platform card */
}

// Platform action delegation
$("#platformList").addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-action]");
  if (!btn) return;
  const { action, platform, method } = btn.dataset;

  if (action === "connectPlatform") {
    if (method === "config") {
      if (platform === "telnyx") openTelnyxConfigModal();
      if (platform === "discord") openDiscordConfigModal();
      if (platform === "telegram") openTelegramConfigModal();
    } else {
      socket.emit("messaging:connect", { platform });
      toast(`Connecting to ${platform}…`, "info");
    }
  } else if (action === "disconnectPlatform") {
    try {
      await api("/messaging/disconnect", {
        method: "POST",
        body: { platform },
      });
      loadMessagingPage();
      toast(`${platform} disconnected`, "success");
    } catch (err) {
      toast(err.message, "error");
    }
  } else if (action === "logoutPlatform") {
    try {
      await api("/messaging/logout", { method: "POST", body: { platform } });
      loadMessagingPage();
      toast(`${platform} logged out`, "success");
    } catch (err) {
      toast(err.message, "error");
    }
  }
});

$("#cancelQR").addEventListener("click", () => {
  $("#messagingQR").classList.add("hidden");
});

// ── Telnyx Config Modal ──────────────────────────────────────────────────────

async function openTelnyxConfigModal() {
  // Pre-fill from saved DB config if available
  let saved = {};
  try {
    const st = await api("/messaging/status/telnyx");
    // Config is not exposed in status; try settings instead
  } catch { }
  try {
    const s = await api("/settings");
    if (s.telnyx_config)
      saved =
        typeof s.telnyx_config === "string"
          ? JSON.parse(s.telnyx_config)
          : s.telnyx_config;
  } catch { }

  const TTS_VOICES = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"];
  const TTS_MODELS = ["tts-1", "tts-1-hd", "gpt-4o-mini-tts"];
  const STT_MODELS = ["whisper-1", "gpt-4o-transcribe"];

  const overlay = document.createElement("div");
  overlay.style.cssText =
    "position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;padding:16px;";

  overlay.innerHTML = `
    <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:28px 28px 22px;max-width:480px;width:100%;max-height:90vh;overflow-y:auto;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
        <div style="font-size:1.15rem;font-weight:700;">📞 Telnyx Voice — Configuration</div>
        <button id="telnyxModalClose" style="background:none;border:none;cursor:pointer;font-size:1.4rem;color:var(--text-muted);">×</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Telnyx API Key *</label>
          <input id="telnyx_apiKey" class="input" type="password" placeholder="KEY0..." value="${escapeHtml(saved.apiKey || "")}" autocomplete="off"/>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Telnyx Phone Number * <span style="color:var(--text-muted);font-size:0.78rem;">(E.164, e.g. +12125550100)</span></label>
          <input id="telnyx_phoneNumber" class="input" type="text" placeholder="+12125550100" value="${escapeHtml(saved.phoneNumber || "")}"/>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Call Control Application ID (Connection ID) *</label>
          <input id="telnyx_connectionId" class="input" type="text" placeholder="..." value="${escapeHtml(saved.connectionId || "")}"/>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Webhook Base URL * <span style="color:var(--text-muted);font-size:0.78rem;">(public URL this server is reachable at)</span></label>
          <input id="telnyx_webhookUrl" class="input" type="text" placeholder="https://xyz.ngrok.io" value="${escapeHtml(saved.webhookUrl || "")}"/>
          <div style="font-size:0.76rem;color:var(--text-muted);margin-top:4px;">Set your Telnyx webhook to: <code style="background:var(--bg-secondary);padding:1px 5px;border-radius:4px;">&lt;URL&gt;/api/telnyx/webhook</code></div>
        </div>
        <div style="display:flex;gap:12px;">
          <div style="flex:1;">
            <label class="label" style="display:block;margin-bottom:4px;">TTS Voice</label>
            <select id="telnyx_ttsVoice" class="input" style="width:100%;">
              ${TTS_VOICES.map((v) => `<option value="${v}"${(saved.ttsVoice || "alloy") === v ? " selected" : ""}>${v}</option>`).join("")}
            </select>
          </div>
          <div style="flex:1;">
            <label class="label" style="display:block;margin-bottom:4px;">TTS Model</label>
            <select id="telnyx_ttsModel" class="input" style="width:100%;">
              ${TTS_MODELS.map((m) => `<option value="${m}"${(saved.ttsModel || "tts-1") === m ? " selected" : ""}>${m}</option>`).join("")}
            </select>
          </div>
        </div>
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">STT Model</label>
          <select id="telnyx_sttModel" class="input" style="width:100%;">
            ${STT_MODELS.map((m) => `<option value="${m}"${(saved.sttModel || "whisper-1") === m ? " selected" : ""}>${m}</option>`).join("")}
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
  overlay.querySelector("#telnyxModalClose").addEventListener("click", close);
  overlay.querySelector("#telnyxModalCancel").addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) close();
  });

  overlay
    .querySelector("#telnyxModalSave")
    .addEventListener("click", async () => {
      const config = {
        apiKey: overlay.querySelector("#telnyx_apiKey").value.trim(),
        phoneNumber: overlay.querySelector("#telnyx_phoneNumber").value.trim(),
        connectionId: overlay
          .querySelector("#telnyx_connectionId")
          .value.trim(),
        webhookUrl: overlay.querySelector("#telnyx_webhookUrl").value.trim(),
        ttsVoice: overlay.querySelector("#telnyx_ttsVoice").value,
        ttsModel: overlay.querySelector("#telnyx_ttsModel").value,
        sttModel: overlay.querySelector("#telnyx_sttModel").value,
      };
      if (
        !config.apiKey ||
        !config.phoneNumber ||
        !config.connectionId ||
        !config.webhookUrl
      ) {
        toast("Please fill in all required fields", "error");
        return;
      }
      try {
        // Save config snapshot for pre-fill
        await api("/settings", {
          method: "PUT",
          body: { telnyx_config: JSON.stringify(config) },
        });
        await api("/messaging/connect", {
          method: "POST",
          body: { platform: "telnyx", config },
        });
        toast("Telnyx Voice connecting…", "success");
        close();
        setTimeout(loadMessagingPage, 1000);
      } catch (err) {
        toast("Failed to connect: " + (err.message || err), "error");
      }
    });
}

// ── Discord Config Modal ─────────────────────────────────────────────────────

async function openDiscordConfigModal() {
  let saved = {};
  try {
    const s = await api("/settings");
    if (s.discord_config)
      saved =
        typeof s.discord_config === "string"
          ? JSON.parse(s.discord_config)
          : s.discord_config;
  } catch { }

  const overlay = document.createElement("div");
  overlay.style.cssText =
    "position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;padding:16px;";

  overlay.innerHTML = `
    <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:28px 28px 22px;max-width:460px;width:100%;max-height:90vh;overflow-y:auto;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
        <div style="font-size:1.15rem;font-weight:700;">🎮 Discord — Configuration</div>
        <button id="discordModalClose" style="background:none;border:none;cursor:pointer;font-size:1.4rem;color:var(--text-muted);">×</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Bot Token *</label>
          <input id="discord_token" class="input" type="password" placeholder="MTxxxxxxxx..." value="${escapeHtml(saved.token || "")}" autocomplete="off"/>
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
  overlay.querySelector("#discordModalClose").addEventListener("click", close);
  overlay.querySelector("#discordModalCancel").addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) close();
  });

  overlay
    .querySelector("#discordModalSave")
    .addEventListener("click", async () => {
      const config = {
        token: overlay.querySelector("#discord_token").value.trim(),
      };
      if (!config.token) {
        toast("Bot token is required", "error");
        return;
      }
      try {
        await api("/settings", {
          method: "PUT",
          body: { discord_config: JSON.stringify(config) },
        });
        await api("/messaging/connect", {
          method: "POST",
          body: { platform: "discord", config },
        });
        toast("Discord connecting…", "success");
        close();
        setTimeout(loadMessagingPage, 1500);
      } catch (err) {
        toast("Failed to connect: " + (err.message || err), "error");
      }
    });
}

// ── Telegram Config Modal ─────────────────────────────────────────────

async function openTelegramConfigModal() {
  let saved = {};
  try {
    const s = await api("/settings");
    if (s.telegram_config)
      saved =
        typeof s.telegram_config === "string"
          ? JSON.parse(s.telegram_config)
          : s.telegram_config;
  } catch { }

  const overlay = document.createElement("div");
  overlay.style.cssText =
    "position:fixed;inset:0;z-index:10000;background:rgba(0,0,0,0.55);display:flex;align-items:center;justify-content:center;padding:16px;";

  overlay.innerHTML = `
    <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:14px;padding:28px 28px 22px;max-width:460px;width:100%;max-height:90vh;overflow-y:auto;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
        <div style="font-size:1.15rem;font-weight:700;">✈️ Telegram — Configuration</div>
        <button id="telegramModalClose" style="background:none;border:none;cursor:pointer;font-size:1.4rem;color:var(--text-muted);">&#xD7;</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px;">
        <div>
          <label class="label" style="display:block;margin-bottom:4px;">Bot Token *</label>
          <input id="telegram_token" class="input" type="password" placeholder="123456:ABCdef..." value="${escapeHtml(saved.botToken || "")}" autocomplete="off"/>
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
  overlay.querySelector("#telegramModalClose").addEventListener("click", close);
  overlay
    .querySelector("#telegramModalCancel")
    .addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) close();
  });

  overlay
    .querySelector("#telegramModalSave")
    .addEventListener("click", async () => {
      const config = {
        botToken: overlay.querySelector("#telegram_token").value.trim(),
      };
      if (!config.botToken) {
        toast("Bot token is required", "error");
        return;
      }
      try {
        await api("/settings", {
          method: "PUT",
          body: { telegram_config: JSON.stringify(config) },
        });
        await api("/messaging/connect", {
          method: "POST",
          body: { platform: "telegram", config },
        });
        toast("Telegram connecting…", "success");
        close();
        setTimeout(loadMessagingPage, 1500);
      } catch (err) {
        toast("Failed to connect: " + (err.message || err), "error");
      }
    });
}

socket.on("messaging:qr", (data) => {
  $("#messagingQR").classList.remove("hidden");
  const container = $("#qrContainer");
  container.innerHTML = `<img src="https://api.qrserver.com/v1/create-qr-code/?data=${encodeURIComponent(data.qr)}&size=280x280" alt="QR Code">`;
});

socket.on("messaging:connected", (data) => {
  $("#messagingQR").classList.add("hidden");
  toast(`${data.platform} connected!`, "success");
  loadMessagingPage();
});

socket.on("messaging:sent", (data) => {
  appendSocialMessage(data.platform, "assistant", data.content, "me");
});

socket.on("messaging:disconnected", () => loadMessagingPage());
socket.on("messaging:logged_out", () => loadMessagingPage());

socket.on("messaging:error", (data) => {
  toast(data && data.error ? data.error : "Messaging error", "error");
});

socket.on("messaging:blocked_sender", (data) => {
  // Show a persistent banner so the user can see the raw ID and add it to the whitelist
  const platform = data.platform || "whatsapp";
  const rawId = data.sender || data.chatId || "unknown";
  const bannerId = `blocked-banner-${rawId.replace(/[^a-zA-Z0-9]/g, "")}`;
  if (document.getElementById(bannerId)) return; // don't stack duplicates

  const platformLabel =
    platform === "telnyx"
      ? "📞 Blocked call"
      : platform === "discord"
        ? "🎮 Blocked Discord message"
        : platform === "telegram"
          ? "✈️ Blocked Telegram message"
          : "⚠ Blocked message";

  const banner = document.createElement("div");
  banner.id = bannerId;
  banner.style.cssText =
    "position:fixed;bottom:80px;right:20px;z-index:9999;max-width:380px;background:var(--bg-card);border:1px solid var(--border);border-left:4px solid #f59e0b;border-radius:10px;padding:14px 16px;box-shadow:0 4px 24px rgba(0,0,0,0.25);font-size:0.86rem;";
  banner.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;">
      <div>
        <div style="font-weight:600;margin-bottom:4px;">${platformLabel}</div>
        <div style="color:var(--text-muted);margin-bottom:10px;">${platform === "telnyx" ? "From" : "Sender"}: <code style="font-size:0.82rem;background:var(--bg-secondary);padding:1px 6px;border-radius:4px;">${escapeHtml(rawId)}</code>${data.senderName ? ` &mdash; ${escapeHtml(data.senderName)}` : ""}${data.meta ? ` <span style="font-size:0.78rem;">(${escapeHtml(data.meta)})</span>` : ""}</div>
        <div style="display:flex;flex-wrap:wrap;gap:8px;" id="wb-btns-${bannerId}">
          ${data.suggestions && data.suggestions.length
      ? data.suggestions
        .map(
          (s, i) =>
            `<button class="btn btn-sm btn-primary" id="wb-sug-${bannerId}-${i}" data-pid="${escapeHtml(s.prefixedId)}">${escapeHtml(s.label)}</button>`,
        )
        .join("")
      : `<button class="btn btn-sm btn-primary" id="wb-add-${bannerId}">Add to whitelist</button>`
    }
          <button class="btn btn-sm btn-secondary" id="wb-dismiss-${bannerId}">Dismiss</button>
        </div>
      </div>
    </div>`;

  document.body.appendChild(banner);

  document
    .getElementById(`wb-dismiss-${bannerId}`)
    .addEventListener("click", () => banner.remove());

  // Helper: add a prefixed/plain ID to a platform whitelist, refresh cards
  async function _wbSave(platform, entryKey) {
    if (platform === "telnyx") {
      const s = await api("/settings");
      let list = [];
      try {
        list = JSON.parse(s.platform_whitelist_telnyx || "[]");
        if (!Array.isArray(list)) list = [];
      } catch {
        list = [];
      }
      if (!list.includes(entryKey)) list.push(entryKey);
      await api("/messaging/telnyx/whitelist", {
        method: "PUT",
        body: { numbers: list },
      });
    } else if (platform === "discord") {
      const s = await api("/settings");
      let list = [];
      try {
        list = JSON.parse(s.platform_whitelist_discord || "[]");
        if (!Array.isArray(list)) list = [];
      } catch {
        list = [];
      }
      const prefixed = entryKey.includes(":") ? entryKey : `user:${entryKey}`;
      if (!list.includes(prefixed)) list.push(prefixed);
      await api("/messaging/discord/whitelist", {
        method: "PUT",
        body: { ids: list },
      });
    } else if (platform === "telegram") {
      const s = await api("/settings");
      let list = [];
      try {
        list = JSON.parse(s.platform_whitelist_telegram || "[]");
        if (!Array.isArray(list)) list = [];
      } catch {
        list = [];
      }
      const prefixed = entryKey.includes(":") ? entryKey : `user:${entryKey}`;
      if (!list.includes(prefixed)) list.push(prefixed);
      await api("/messaging/telegram/whitelist", {
        method: "PUT",
        body: { ids: list },
      });
    } else {
      // whatsapp
      const s = await api("/settings");
      let list = [];
      try {
        list = JSON.parse(s.platform_whitelist_whatsapp || "[]");
        if (!Array.isArray(list)) list = [];
      } catch {
        list = [];
      }
      if (!list.includes(entryKey)) list.push(entryKey);
      await api("/settings", {
        method: "PUT",
        body: { platform_whitelist_whatsapp: JSON.stringify(list) },
      });
    }
  }

  // Wire suggestion buttons (Discord) or the single Add button (other platforms)
  if (data.suggestions && data.suggestions.length) {
    data.suggestions.forEach((s, i) => {
      const btn = document.getElementById(`wb-sug-${bannerId}-${i}`);
      if (!btn) return;
      btn.addEventListener("click", async () => {
        try {
          await _wbSave(platform, s.prefixedId);
          toast(`Added ${s.prefixedId} to whitelist`, "success");
          banner.remove();
          if (document.querySelector("#page-messaging.active"))
            loadMessagingPage();
        } catch (err) {
          toast("Failed to save: " + err.message, "error");
        }
      });
    });
  } else {
    const addBtn = document.getElementById(`wb-add-${bannerId}`);
    if (addBtn)
      addBtn.addEventListener("click", async () => {
        const key =
          platform === "whatsapp"
            ? normalizeWhatsAppWhitelistEntry(rawId)
            : rawId.replace(/[^0-9]/g, "") || rawId;
        try {
          await _wbSave(platform, key);
          toast(`Added ${key} to whitelist`, "success");
          banner.remove();
          if (document.querySelector("#page-messaging.active"))
            loadMessagingPage();
        } catch (err) {
          toast("Failed to save: " + err.message, "error");
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
    const res = await fetch("/api/protocols");
    if (!res.ok) throw new Error("Failed to load protocols");
    const protocols = await res.json();
    renderProtocolsList(protocols);
  } catch (err) {
    console.error(err);
  }
}

function renderProtocolsList(protocols) {
  const container = $("#protocolsList");
  if (protocols.length === 0) {
    container.innerHTML =
      '<div class="empty-state">No protocols found. Create one.</div>';
    return;
  }
  container.className = "protocols-list";
  container.innerHTML = protocols
    .map(
      (p) => `
    <div class="item-card">
      <div class="item-card-header">
        <div class="item-card-title">${p.name}</div>
        <div class="item-card-actions">
          <button class="btn btn-sm btn-secondary" onclick="editProtocol(${p.id})">Edit</button>
          <button class="btn btn-sm btn-danger" onclick="deleteProtocol(${p.id})">&times;</button>
        </div>
      </div>
      <div class="item-card-meta">${p.description || "No description"}</div>
    </div>
  `,
    )
    .join("");
}

$("#closeProtocolModal")?.addEventListener("click", () =>
  $("#protocolModal")?.classList.add("hidden"),
);
$("#cancelProtocolModal")?.addEventListener("click", () =>
  $("#protocolModal")?.classList.add("hidden"),
);

$("#addProtocolBtn")?.addEventListener("click", () => {
  currentProtocolId = null;
  $("#protocolModalTitle").textContent = "Add Protocol";
  $("#protocolName").value = "";
  $("#protocolDesc").value = "";
  $("#protocolContent").value = "";
  $("#protocolModal")?.classList.remove("hidden");
});

$("#saveProtocolBtn").addEventListener("click", async () => {
  const name = $("#protocolName").value.trim();
  const description = $("#protocolDesc").value.trim();
  const content = $("#protocolContent").value.trim();

  if (!name || !content) {
    alert("Name and Content are required");
    return;
  }

  const payload = { name, description, content };
  const method = currentProtocolId ? "PUT" : "POST";
  const url = currentProtocolId
    ? `/api/protocols/${currentProtocolId}`
    : "/api/protocols";

  try {
    const res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || "Failed to save: " + res.status);
    }
    $("#protocolModal")?.classList.add("hidden");
    loadProtocolsPage();
  } catch (err) {
    alert(err.message);
  }
});

async function editProtocol(id) {
  try {
    const res = await fetch(`/api/protocols/${id}`);
    if (!res.ok) throw new Error("Failed to load protocol");
    const p = await res.json();

    currentProtocolId = p.id;
    $("#protocolModalTitle").textContent = "Edit Protocol";
    $("#protocolName").value = p.name;
    $("#protocolDesc").value = p.description || "";
    $("#protocolContent").value = p.content;
    $("#protocolModal")?.classList.remove("hidden");
  } catch (err) {
    alert(err.message);
  }
}

async function deleteProtocol(id) {
  if (!confirm("Are you sure you want to delete this protocol?")) return;
  try {
    const res = await fetch(`/api/protocols/${id}`, { method: "DELETE" });
    if (!res.ok) throw new Error("Failed to delete protocol");
    loadProtocolsPage();
  } catch (err) {
    alert(err.message);
  }
}

window.editProtocol = editProtocol;
window.deleteProtocol = deleteProtocol;
