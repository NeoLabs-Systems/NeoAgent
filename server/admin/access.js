'use strict';

// ── Access Settings ────────────────────────────────────────────────────────

let _revealedKey = null; // holds the API key shown after rotation (one-time)
let _revealTimer  = null;

async function loadAccess() {
  const el = document.getElementById('access-content');
  if (!el) return;
  try {
    const data = await api('/admin/api/settings').then((r) => r.json());
    renderAccess(el, data);
  } catch (err) {
    if (err.message !== 'unauthorized') el.innerHTML = '<div class="empty">Failed to load settings</div>';
  }
}

function renderAccess(el, { signupEnabled, apiKeyConfigured, apiKeyHint }) {
  el.innerHTML = `
    <!-- Signup -->
    <div class="card">
      <div class="card-title">User Signups</div>
      <div class="access-row">
        <div>
          <div class="access-label">Allow new registrations</div>
          <div class="access-desc">
            When disabled, only existing users can log in. The first account can always be created regardless of this setting.
          </div>
        </div>
        <label class="toggle" aria-label="Toggle signups">
          <input type="checkbox" id="signup-toggle" ${signupEnabled ? 'checked' : ''}
            onchange="setSignup(this.checked)">
          <span class="toggle-track"></span>
          <span class="toggle-thumb"></span>
        </label>
      </div>
      <div id="signup-status" class="access-status"></div>
    </div>

    <!-- API key -->
    <div class="card">
      <div class="card-title">Admin API Key</div>
      <div class="access-row">
        <div>
          <div class="access-label">Programmatic access</div>
          <div class="access-desc">
            Use <code>Authorization: Bearer &lt;key&gt;</code> to authenticate against any <code>/admin/api/*</code> endpoint from scripts or automation — without a browser session.
          </div>
        </div>
        <span class="badge ${apiKeyConfigured ? 'badge-ok' : 'badge-idle'}">
          ${apiKeyConfigured ? 'configured' : 'not set'}
        </span>
      </div>

      ${apiKeyConfigured ? `
        <div class="access-hint-row">
          <code class="api-key-hint">${esc(apiKeyHint)}</code>
          <span style="font-size:11px;color:var(--text-muted);">stored in .env — rotate to reveal</span>
        </div>` : ''}

      <div id="key-reveal-wrap" style="display:none;">
        <div class="key-reveal-box">
          <div style="font-size:11px;color:var(--text-muted);margin-bottom:6px;">
            New API key — copy it now. It will not be shown again.
          </div>
          <div style="display:flex;align-items:center;gap:8px;">
            <code id="key-reveal-value" class="api-key-full"></code>
            <button class="btn btn-ghost" style="padding:5px 10px;font-size:11px;flex-shrink:0;"
              onclick="copyApiKey()">Copy</button>
          </div>
          <div style="margin-top:8px;font-size:11px;color:var(--text-muted);" id="key-reveal-timer"></div>
        </div>
      </div>

      <div class="access-actions">
        <button class="btn btn-ghost" onclick="rotateApiKey(this)">
          ${apiKeyConfigured ? 'Rotate key' : 'Generate key'}
        </button>
        ${apiKeyConfigured ? `
          <button class="btn btn-danger" onclick="revokeApiKey(this)">Revoke key</button>` : ''}
      </div>
      <div id="apikey-status" class="access-status"></div>
    </div>`;

  // If we rotated in this page load, re-show the key
  if (_revealedKey) showReveal(_revealedKey);
}

async function setSignup(enabled) {
  const statusEl = document.getElementById('signup-status');
  if (statusEl) statusEl.textContent = '';
  try {
    const res = await api('/admin/api/settings/signup', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ enabled }),
    });
    if (res.ok) {
      showStatus('signup-status', enabled ? 'Signups enabled.' : 'Signups disabled.', false);
    } else {
      const b = await res.json().catch(() => ({}));
      showStatus('signup-status', b.error || 'Failed to update', true);
      // Revert the toggle
      const toggle = document.getElementById('signup-toggle');
      if (toggle) toggle.checked = !enabled;
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showStatus('signup-status', 'Network error', true);
    const toggle = document.getElementById('signup-toggle');
    if (toggle) toggle.checked = !enabled;
  }
}

async function rotateApiKey(btn) {
  if (!confirm(
    'Rotate admin API key?\n\n' +
    'The current key will stop working immediately.\n' +
    'Any scripts using it must be updated.\n\n' +
    'The new key will be shown once — copy it before leaving.'
  )) return;
  btn.disabled = true;
  btn.textContent = 'Rotating…';
  try {
    const res = await api('/admin/api/settings/apikey/rotate', { method: 'POST' });
    const data = await res.json();
    if (res.ok && data.apiKey) {
      _revealedKey = data.apiKey;
      await loadAccess(); // re-render to show badge + hint
    } else {
      showStatus('apikey-status', data.error || 'Failed to rotate', true);
      btn.disabled = false;
      btn.textContent = 'Rotate key';
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showStatus('apikey-status', 'Network error', true);
    btn.disabled = false;
    btn.textContent = 'Rotate key';
  }
}

async function revokeApiKey(btn) {
  if (!confirm('Revoke admin API key?\n\nAll programmatic access using this key will stop immediately.')) return;
  btn.disabled = true;
  btn.textContent = 'Revoking…';
  _revealedKey = null;
  try {
    const res = await api('/admin/api/settings/apikey', { method: 'DELETE' });
    if (res.ok) {
      await loadAccess();
    } else {
      const b = await res.json().catch(() => ({}));
      showStatus('apikey-status', b.error || 'Failed', true);
      btn.disabled = false;
      btn.textContent = 'Revoke key';
    }
  } catch (err) {
    if (err.message !== 'unauthorized') showStatus('apikey-status', 'Network error', true);
    btn.disabled = false;
    btn.textContent = 'Revoke key';
  }
}

function copyApiKey() {
  if (_revealedKey) navigator.clipboard.writeText(_revealedKey).catch(() => {});
}

function showReveal(key) {
  const wrap  = document.getElementById('key-reveal-wrap');
  const value = document.getElementById('key-reveal-value');
  if (!wrap || !value) return;
  value.textContent = key;
  wrap.style.display = 'block';
  // Auto-clear after 120 seconds
  clearTimeout(_revealTimer);
  let secs = 120;
  const timerEl = document.getElementById('key-reveal-timer');
  const tick = () => {
    if (!timerEl) return;
    if (secs <= 0) {
      wrap.style.display = 'none';
      _revealedKey = null;
      return;
    }
    timerEl.textContent = `Hides in ${secs}s`;
    secs--;
    _revealTimer = setTimeout(tick, 1000);
  };
  tick();
}

function showStatus(id, msg, isError) {
  const el = document.getElementById(id);
  if (!el) return;
  el.textContent = msg;
  el.style.color = isError ? 'var(--danger)' : 'var(--success)';
  setTimeout(() => { if (el) el.textContent = ''; }, 4000);
}
