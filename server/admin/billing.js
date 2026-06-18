'use strict';

let _billingPlans = [];
let _billingSubsOffset = 0;
const BILLING_SUBS_LIMIT = 50;

async function loadBilling() {
  // Check if billing is enabled by probing the plans endpoint.
  try {
    const r = await fetch('/admin/api/billing/plans');
    if (!r.ok) {
      document.getElementById('billing-plans-content').innerHTML =
        '<div class="empty">Billing is not enabled on this server. Set <code>NEOAGENT_BILLING_ENABLED=1</code> to enable it.</div>';
      document.getElementById('billing-subs-content').innerHTML = '';
      document.getElementById('nav-billing').style.display = '';
      return;
    }
    const data = await r.json();
    _billingPlans = data.plans || [];
    renderPlansTable(_billingPlans);
  } catch {
    document.getElementById('billing-plans-content').innerHTML = '<div class="empty">Failed to load billing data.</div>';
  }
  document.getElementById('nav-billing').style.display = '';
  _billingSubsOffset = 0;
  await loadBillingSubscriptions();
}

// Show the billing nav item on load if billing is enabled.
(async function checkBillingEnabled() {
  try {
    const r = await fetch('/admin/api/billing/plans');
    if (r.ok) document.getElementById('nav-billing').style.display = '';
  } catch {}
})();

function planRowHtml(plan) {
  const id = escAttr(plan.id);
  const intervalLabel = plan.interval ? `/ ${plan.interval}` : '';
  const price = plan.price_cents === 0 ? 'Free' : `${(plan.price_cents / 100).toFixed(2)} ${(plan.currency || 'usd').toUpperCase()} ${intervalLabel}`;
  const status = plan.is_active ? '<span style="color:var(--success)">Active</span>' : '<span style="color:var(--text-muted)">Inactive</span>';
  return `
    <tr data-plan-id="${id}">
      <td><strong>${esc(plan.name)}</strong><br><small style="color:var(--text-muted)">${esc(plan.id)}</small></td>
      <td>${esc(price)}</td>
      <td>${plan.token_limit_4h != null ? fmtTokens(plan.token_limit_4h) : '<span style="color:var(--text-muted)">Default</span>'}</td>
      <td>${plan.token_limit_weekly != null ? fmtTokens(plan.token_limit_weekly) : '<span style="color:var(--text-muted)">Default</span>'}</td>
      <td><code style="font-size:11px">${esc(plan.stripe_price_id || '—')}</code></td>
      <td>${status}</td>
      <td>
        <button class="btn btn-sm" onclick="billingEditPlan('${id}')">Edit</button>
        <button class="btn btn-sm btn-danger" onclick="billingDeletePlan('${id}')">Delete</button>
      </td>
    </tr>`;
}

function renderPlansTable(plans) {
  const el = document.getElementById('billing-plans-content');
  if (!plans.length) {
    el.innerHTML = '<div class="empty">No plans yet. Create one above.</div>';
    return;
  }
  el.innerHTML = `
    <table class="data-table">
      <thead><tr>
        <th>Plan</th><th>Price</th><th>4h Tokens</th><th>Weekly Tokens</th><th>Stripe Price ID</th><th>Status</th><th>Actions</th>
      </tr></thead>
      <tbody>${plans.map(planRowHtml).join('')}</tbody>
    </table>`;
}

function billingShowNewPlanForm() {
  billingOpenPlanModal(null);
}

function billingEditPlan(planId) {
  const plan = _billingPlans.find((p) => p.id === planId);
  billingOpenPlanModal(plan);
}

function billingOpenPlanModal(plan) {
  const isNew = !plan;
  const title = isNew ? 'New Plan' : `Edit Plan: ${plan.name}`;
  const html = `
    <div id="billing-plan-modal" style="position:fixed;inset:0;background:rgba(0,0,0,0.5);display:flex;align-items:center;justify-content:center;z-index:1000">
      <div style="background:var(--bg-card);border-radius:12px;padding:28px;width:540px;max-height:90vh;overflow-y:auto;box-shadow:0 8px 32px rgba(0,0,0,0.3)">
        <h2 style="margin:0 0 20px">${esc(title)}</h2>
        <form id="billing-plan-form" onsubmit="billingPlanFormSubmit(event)">
          <input type="hidden" id="bp-id" value="${esc(plan?.id || '')}">
          <label class="form-label">Plan ID <small>(set once, used as identifier)</small></label>
          <input class="form-input" id="bp-slug" value="${esc(plan?.id || '')}" ${isNew ? '' : 'disabled'} placeholder="plan_pro" style="margin-bottom:12px">
          <label class="form-label">Name</label>
          <input class="form-input" id="bp-name" value="${esc(plan?.name || '')}" required placeholder="Pro" style="margin-bottom:12px">
          <label class="form-label">Description</label>
          <input class="form-input" id="bp-desc" value="${esc(plan?.description || '')}" placeholder="Optional description" style="margin-bottom:12px">
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">
            <div>
              <label class="form-label">Price (cents)</label>
              <input class="form-input" id="bp-price" type="number" min="0" value="${plan?.price_cents ?? 0}" required>
            </div>
            <div>
              <label class="form-label">Currency</label>
              <input class="form-input" id="bp-currency" value="${esc(plan?.currency || 'usd')}" placeholder="usd">
            </div>
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">
            <div>
              <label class="form-label">Billing interval</label>
              <select class="form-input" id="bp-interval">
                <option value="month" ${plan?.interval === 'month' ? 'selected' : ''}>Monthly</option>
                <option value="year" ${plan?.interval === 'year' ? 'selected' : ''}>Yearly</option>
                <option value="" ${!plan?.interval ? 'selected' : ''}>One-time / Free</option>
              </select>
            </div>
            <div>
              <label class="form-label">Sort order</label>
              <input class="form-input" id="bp-sort" type="number" value="${plan?.sort_order ?? 0}">
            </div>
          </div>
          <label class="form-label">Stripe Price ID</label>
          <input class="form-input" id="bp-stripe-price" value="${esc(plan?.stripe_price_id || '')}" placeholder="price_..." style="margin-bottom:12px">
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">
            <div>
              <label class="form-label">4h token limit <small>(blank = default)</small></label>
              <input class="form-input" id="bp-tok-4h" type="number" min="0" value="${plan?.token_limit_4h ?? ''}" placeholder="2500000">
            </div>
            <div>
              <label class="form-label">Weekly token limit <small>(blank = default)</small></label>
              <input class="form-input" id="bp-tok-weekly" type="number" min="0" value="${plan?.token_limit_weekly ?? ''}" placeholder="10000000">
            </div>
          </div>
          <label class="form-label">Allowed model IDs <small>(comma-separated; blank = all)</small></label>
          <input class="form-input" id="bp-models" value="${esc((plan?.allowed_models || []).join(', '))}" placeholder="claude-opus-4-8, gpt-4o" style="margin-bottom:12px">
          <label class="form-label">Features <small>(comma-separated, shown on pricing page)</small></label>
          <input class="form-input" id="bp-features" value="${esc((plan?.features || []).join(', '))}" placeholder="Unlimited agents, Priority support" style="margin-bottom:16px">
          <label style="display:flex;align-items:center;gap:8px;margin-bottom:20px;cursor:pointer">
            <input type="checkbox" id="bp-active" ${!plan || plan.is_active ? 'checked' : ''}> Active
          </label>
          <div style="display:flex;gap:8px;justify-content:flex-end">
            <button type="button" class="btn" onclick="billingClosePlanModal()">Cancel</button>
            <button type="submit" class="btn btn-primary">${isNew ? 'Create' : 'Save'}</button>
          </div>
        </form>
      </div>
    </div>`;
  document.body.insertAdjacentHTML('beforeend', html);
}

function billingClosePlanModal() {
  document.getElementById('billing-plan-modal')?.remove();
}

async function billingPlanFormSubmit(e) {
  e.preventDefault();
  const id = document.getElementById('bp-id').value;
  const slug = document.getElementById('bp-slug').value.trim();
  const isNew = !id;

  const parseTokenLimit = (val) => {
    const n = parseInt(val, 10);
    return isNaN(n) || val === '' ? null : n;
  };
  const parseModels = (val) => val.split(',').map((s) => s.trim()).filter(Boolean);
  const parseFeatures = (val) => val.split(',').map((s) => s.trim()).filter(Boolean);

  const body = {
    id: isNew ? slug : undefined,
    name: document.getElementById('bp-name').value.trim(),
    description: document.getElementById('bp-desc').value.trim(),
    price_cents: parseInt(document.getElementById('bp-price').value, 10),
    currency: document.getElementById('bp-currency').value.trim() || 'usd',
    interval: document.getElementById('bp-interval').value || null,
    stripe_price_id: document.getElementById('bp-stripe-price').value.trim() || null,
    token_limit_4h: parseTokenLimit(document.getElementById('bp-tok-4h').value),
    token_limit_weekly: parseTokenLimit(document.getElementById('bp-tok-weekly').value),
    allowed_models: parseModels(document.getElementById('bp-models').value),
    features: parseFeatures(document.getElementById('bp-features').value),
    sort_order: parseInt(document.getElementById('bp-sort').value, 10) || 0,
    is_active: document.getElementById('bp-active').checked,
  };

  try {
    const url = isNew ? '/admin/api/billing/plans' : `/admin/api/billing/plans/${encodeURIComponent(id)}`;
    const method = isNew ? 'POST' : 'PUT';
    const r = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    const data = await r.json();
    if (!r.ok) { alert(data.error || 'Failed to save plan.'); return; }
    billingClosePlanModal();
    await loadBilling();
  } catch (err) {
    alert('Error: ' + err.message);
  }
}

async function billingDeletePlan(planId) {
  if (!confirm(`Delete plan "${planId}"? It will be deactivated (not hard-deleted).`)) return;
  try {
    const r = await fetch(`/admin/api/billing/plans/${encodeURIComponent(planId)}`, { method: 'DELETE' });
    if (!r.ok) { const d = await r.json(); alert(d.error || 'Failed.'); return; }
    await loadBilling();
  } catch (err) {
    alert('Error: ' + err.message);
  }
}

async function loadBillingSubscriptions() {
  const statusFilter = document.getElementById('billing-sub-status-filter')?.value || '';
  const el = document.getElementById('billing-subs-content');
  el.innerHTML = '<div class="empty"><span class="spinner"></span></div>';
  try {
    const params = new URLSearchParams({ limit: BILLING_SUBS_LIMIT, offset: _billingSubsOffset });
    if (statusFilter) params.set('status', statusFilter);
    const r = await fetch('/admin/api/billing/subscriptions?' + params);
    if (!r.ok) { el.innerHTML = '<div class="empty">Failed to load subscriptions.</div>'; return; }
    const data = await r.json();
    renderSubsTable(data.subscriptions, data.total);
  } catch {
    el.innerHTML = '<div class="empty">Failed to load subscriptions.</div>';
  }
}

function renderSubsTable(rows, total) {
  const el = document.getElementById('billing-subs-content');
  if (!rows.length) { el.innerHTML = '<div class="empty">No subscriptions found.</div>'; return; }
  el.innerHTML = `
    <table class="data-table">
      <thead><tr>
        <th>User</th><th>Plan</th><th>Status</th><th>Period end</th><th>Actions</th>
      </tr></thead>
      <tbody>${rows.map(subRowHtml).join('')}</tbody>
    </table>`;

  const pag = document.getElementById('billing-subs-pagination');
  const hasPrev = _billingSubsOffset > 0;
  const hasNext = _billingSubsOffset + BILLING_SUBS_LIMIT < total;
  pag.innerHTML = `
    <span style="color:var(--text-muted);font-size:13px">${total} total</span>
    ${hasPrev ? `<button class="btn btn-sm" onclick="_billingSubsOffset-=${BILLING_SUBS_LIMIT};loadBillingSubscriptions()">← Prev</button>` : ''}
    ${hasNext ? `<button class="btn btn-sm" onclick="_billingSubsOffset+=${BILLING_SUBS_LIMIT};loadBillingSubscriptions()">Next →</button>` : ''}`;
}

function subRowHtml(sub) {
  const userLabel = esc(sub.display_name || sub.username || String(sub.user_id));
  const email = sub.email ? `<br><small style="color:var(--text-muted)">${esc(sub.email)}</small>` : '';
  const statusColor = { active: 'var(--success)', trialing: 'var(--warning)', past_due: 'var(--danger)', canceled: 'var(--text-muted)' }[sub.status] || 'var(--text-muted)';
  const periodEnd = sub.current_period_end ? sub.current_period_end.slice(0, 10) : '—';
  return `
    <tr>
      <td>${userLabel}${email}</td>
      <td>${esc(sub.plan_name)}</td>
      <td><span style="color:${statusColor}">${esc(sub.status)}</span></td>
      <td>${periodEnd}</td>
      <td><button class="btn btn-sm" onclick="billingOverrideSub(${sub.user_id})">Override</button></td>
    </tr>`;
}

async function billingOverrideSub(userId) {
  if (!_billingPlans.length) { alert('No plans available.'); return; }
  const options = _billingPlans.filter((p) => p.is_active).map((p) => `${p.id} — ${p.name}`).join('\n');
  const planId = prompt(`Enter plan ID to assign:\n\n${options}`);
  if (!planId) return;
  try {
    const r = await fetch(`/admin/api/billing/users/${userId}/subscription`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ planId: planId.trim() }),
    });
    const data = await r.json();
    if (!r.ok) { alert(data.error || 'Failed.'); return; }
    await loadBillingSubscriptions();
  } catch (err) {
    alert('Error: ' + err.message);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function esc(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function escAttr(str) {
  return esc(str);
}

function fmtTokens(n) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(0) + 'K';
  return String(n);
}
