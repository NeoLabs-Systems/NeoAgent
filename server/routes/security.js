'use strict';

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const db = require('../db/database');
const { TOOL_CATEGORIES, getCategoryForTool } = require('../services/security/tool_categories');

router.use(requireAuth);

// ── Security mode ─────────────────────────────────────────────────────────────

// GET /api/security/mode — current global security mode
router.get('/mode', (req, res) => {
  const mode = req.app.locals.toolPolicyService.getSecurityMode(req.session.userId);
  res.json({ mode });
});

// PUT /api/security/mode — update global security mode
router.put('/mode', (req, res) => {
  const { mode } = req.body;
  if (!mode) return res.status(400).json({ error: 'mode is required' });
  try {
    req.app.locals.toolPolicyService.setSecurityMode(req.session.userId, mode);
    res.json({ ok: true, mode });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── Per-category policies ─────────────────────────────────────────────────────

// GET /api/security/policies — all category policies + current mode
router.get('/policies', (req, res) => {
  const { toolPolicyService } = req.app.locals;
  const policies = toolPolicyService.getPolicies(req.session.userId);
  const mode = toolPolicyService.getSecurityMode(req.session.userId);
  res.json({ policies, mode, categories: Object.keys(TOOL_CATEGORIES) });
});

// PUT /api/security/policies — update a single category policy
router.put('/policies', (req, res) => {
  const { category, policy } = req.body;
  if (!category || !policy) {
    return res.status(400).json({ error: 'category and policy are required' });
  }
  try {
    req.app.locals.toolPolicyService.setPolicy(req.session.userId, category, policy);
    res.json({ ok: true, category, policy });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── Approval decisions ────────────────────────────────────────────────────────

// POST /api/security/approvals/:approvalId — resolve a pending approval
router.post('/approvals/:approvalId', (req, res) => {
  const { approvalId } = req.params;
  const { decision, scope, runId, toolName, toolArgs } = req.body;

  if (!decision || !['approved', 'denied'].includes(decision)) {
    return res.status(400).json({ error: 'decision must be approved or denied' });
  }
  const normalizedScope = ['once', 'session', 'always'].includes(scope) ? scope : 'once';

  // 'always' scope: also persist the policy so this category is allowed going forward
  if (decision === 'approved' && normalizedScope === 'always' && toolName) {
    try {
      const category = getCategoryForTool(toolName, toolArgs ?? {});
      if (category) {
        req.app.locals.toolPolicyService.setPolicy(req.session.userId, category, 'allow');
      }
    } catch {}
  }

  const { approvalGateService } = req.app.locals;
  const resolved = approvalGateService.resolve(
    approvalId,
    req.session.userId,
    runId || null,
    toolName || null,
    toolArgs || {},
    decision,
    normalizedScope,
  );
  if (!resolved) {
    const storedApproval = approvalGateService.getStoredApproval?.(
      approvalId,
      req.session.userId,
    );
    if (storedApproval?.status === 'expired' || storedApproval?.status === 'timeout') {
      return res.status(410).json({
        error: 'Approval expired because the run was interrupted or the server restarted.',
      });
    }
    if (runId) {
      const run = db.prepare(
        'SELECT status FROM agent_runs WHERE id = ? AND user_id = ?'
      ).get(runId, req.session.userId);
      if (run?.status === 'interrupted') {
        return res.status(410).json({
          error: 'Approval expired because the run was interrupted or the server restarted.',
        });
      }
    }
    return res.status(404).json({ error: 'Approval not found or already resolved' });
  }
  res.json({ ok: true, approvalId, decision, scope: normalizedScope });
});

// ── Audit log ─────────────────────────────────────────────────────────────────

// GET /api/security/approval-log — paginated audit log
router.get('/approval-log', (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const offset = Number(req.query.offset) || 0;
  const rows = db.prepare(`
    SELECT id, run_id, tool_name, tool_args_json, decision, scope, decided_at
    FROM tool_approval_log
    WHERE user_id = ?
    ORDER BY decided_at DESC
    LIMIT ? OFFSET ?
  `).all(req.session.userId, limit, offset);
  const total = db.prepare(
    'SELECT COUNT(*) as count FROM tool_approval_log WHERE user_id = ?'
  ).get(req.session.userId)?.count ?? 0;
  res.json({ log: rows, total, limit, offset });
});

module.exports = router;
