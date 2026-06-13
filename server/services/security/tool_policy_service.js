'use strict';

const db = require('../../db/database');
const { SAFE_TOOLS, DEFAULT_POLICY, getCategoryForTool } = require('./tool_categories');

const VALID_POLICIES = new Set(['allow', 'allow_always', 'deny', 'require_approval']);
const VALID_CATEGORIES = new Set(Object.keys(DEFAULT_POLICY));
const VALID_MODES = new Set(['default', 'allow_all', 'always_ask']);
const SECURITY_MODE_SETTING_KEY = 'tool_security_mode';

class ToolPolicyService {
  /**
   * Returns the user's global security mode.
   * 'default'    — respect individual category policies (standard)
   * 'allow_all'  — bypass all policy and approval checks
   * 'always_ask' — always require approval regardless of category policy
   *
   * @returns {'default'|'allow_all'|'always_ask'}
   */
  getSecurityMode(userId) {
    const row = db.prepare(
      'SELECT value FROM user_settings WHERE user_id = ? AND key = ?'
    ).get(userId, SECURITY_MODE_SETTING_KEY);
    const mode = row?.value;
    return VALID_MODES.has(mode) ? mode : 'default';
  }

  setSecurityMode(userId, mode) {
    if (!VALID_MODES.has(mode)) {
      throw new Error(`Invalid security mode: ${mode}. Must be default, allow_all, or always_ask`);
    }
    db.prepare(`
      INSERT INTO user_settings (user_id, key, value)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
    `).run(userId, SECURITY_MODE_SETTING_KEY, mode);
  }

  /**
   * Returns the effective policy for a tool call.
   * Fast path: SAFE_TOOLS bypass everything.
   * Otherwise: DB row → DEFAULT_POLICY fallback.
   *
   * @returns {'allow'|'allow_always'|'deny'|'require_approval'}
   */
  getPolicy(userId, toolName, toolArgs = {}) {
    if (SAFE_TOOLS.has(toolName)) return 'allow';

    const category = getCategoryForTool(toolName, toolArgs);
    if (!category) return 'allow';

    const row = db.prepare(
      'SELECT policy FROM tool_policies WHERE user_id = ? AND category = ?'
    ).get(userId, category);

    return row?.policy ?? DEFAULT_POLICY[category] ?? 'allow';
  }

  /**
   * Upserts a policy for a user+category. Validates inputs.
   */
  setPolicy(userId, category, policy) {
    if (!VALID_CATEGORIES.has(category)) {
      throw new Error(`Unknown tool category: ${category}`);
    }
    if (!VALID_POLICIES.has(policy)) {
      throw new Error(`Invalid policy value: ${policy}. Must be allow, allow_always, deny, or require_approval`);
    }
    db.prepare(`
      INSERT INTO tool_policies (user_id, category, policy, updated_at)
      VALUES (?, ?, ?, datetime('now'))
      ON CONFLICT(user_id, category) DO UPDATE SET policy = excluded.policy, updated_at = excluded.updated_at
    `).run(userId, category, policy);
  }

  /**
   * Returns all category policies for a user, filling defaults for missing rows.
   */
  getPolicies(userId) {
    const rows = db.prepare(
      'SELECT category, policy FROM tool_policies WHERE user_id = ?'
    ).all(userId);
    const stored = Object.fromEntries(rows.map((r) => [r.category, r.policy]));
    const result = {};
    for (const [category, defaultPolicy] of Object.entries(DEFAULT_POLICY)) {
      result[category] = stored[category] ?? defaultPolicy;
    }
    return result;
  }
}

module.exports = { ToolPolicyService };
