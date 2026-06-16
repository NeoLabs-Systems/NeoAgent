'use strict';

const fs = require('fs');
const path = require('path');
const db = require('../../db/database');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');

const SKILLS_DIR = path.join(AGENT_DATA_DIR, 'skills');
const USER_SKILLS_DIR = path.join(SKILLS_DIR, 'users');
const LEGACY_SKILL_USER_ID = 0;

function shellEscape(value) {
  const text = String(value ?? '');
  if (text.length === 0) {
    return "''";
  }
  return `'${text.replace(/'/g, `'\\''`)}'`;
}

// Shell metacharacters that must not appear in a skill command template.
const SHELL_METACHAR_RE = /[;&|`$\n\r(){}\\<>]/;

function isValidCommandTemplate(template) {
  // Strip all {placeholder} tokens, then reject any remaining shell metacharacters.
  const bare = String(template).replace(/\{[^{}]*\}/g, '');
  return !SHELL_METACHAR_RE.test(bare);
}

function clampText(value, maxChars) {
  const text = String(value || '').trim().replace(/\s+/g, ' ');
  if (!text) return '';
  if (text.length <= maxChars) return text;
  return `${text.slice(0, Math.max(0, maxChars - 1)).trimEnd()}...`;
}

function isValidUserId(userId) {
  return normalizeRuntimeUserId(userId) !== null;
}

function normalizeRuntimeUserId(userId) {
  if (typeof userId === 'number') {
    return Number.isInteger(userId) && userId > 0 ? userId : null;
  }
  if (typeof userId === 'string') {
    const trimmed = userId.trim();
    if (!trimmed) return null;
    const parsed = Number.parseInt(trimmed, 10);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
  }
  return null;
}

function normalizeStoredUserId(userId) {
  if (typeof userId === 'number' && Number.isInteger(userId)) {
    return userId;
  }
  if (typeof userId === 'string') {
    const trimmed = userId.trim();
    if (!trimmed) return LEGACY_SKILL_USER_ID;
    const parsed = Number.parseInt(trimmed, 10);
    return Number.isInteger(parsed) ? parsed : LEGACY_SKILL_USER_ID;
  }
  return LEGACY_SKILL_USER_ID;
}

function normalizeSkillName(name) {
  return String(name || '')
    .trim()
    .replace(/[^a-z0-9-]/gi, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .toLowerCase();
}

function buildSkillKey(ownerType, ownerId, name) {
  return `${ownerType}:${ownerId ?? 'global'}:${name}`;
}

function parseMetadataJson(value) {
  if (!value || typeof value !== 'string') return {};
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

class SkillRunner {
  constructor(options = {}) {
    this.skills = new Map();
    this.runtimeManager = options.runtimeManager || null;
  }

  async loadSkills() {
    this.skills.clear();
    const dbSkills = db.prepare('SELECT * FROM skills').all();
    const dbSkillPaths = new Set(
      dbSkills
        .map((skill) => path.resolve(String(skill.file_path || '')))
        .filter(Boolean),
    );
    const loadedPaths = new Set();

    const loadDir = (dir) => {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (path.resolve(fullPath) === path.resolve(USER_SKILLS_DIR)) {
          continue;
        }
        if (entry.isDirectory()) {
          const skillFile = path.join(fullPath, 'SKILL.md');
          if (fs.existsSync(skillFile) && !dbSkillPaths.has(path.resolve(skillFile))) {
            this.loadSkillFile(skillFile, { ownerType: 'global' });
            loadedPaths.add(path.resolve(skillFile));
          }
          loadDir(fullPath);
        } else if (
          entry.name.endsWith('.md')
          && !loadedPaths.has(path.resolve(fullPath))
          && !dbSkillPaths.has(path.resolve(fullPath))
        ) {
          this.loadSkillFile(fullPath, { ownerType: 'global' });
          loadedPaths.add(path.resolve(fullPath));
        }
      }
    };

    if (fs.existsSync(SKILLS_DIR)) {
      loadDir(SKILLS_DIR);
    }
    for (const skill of dbSkills) {
      if (fs.existsSync(skill.file_path)) {
        this.loadSkillFile(skill.file_path, {
          ownerType: normalizeStoredUserId(skill.user_id) > 0 ? 'user' : 'legacy',
          userId: normalizeStoredUserId(skill.user_id),
          enabled: skill.enabled !== 0,
          metadata: parseMetadataJson(skill.metadata),
        });
      }
    }
  }

  loadSkillFile(filePath, options = {}) {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const skill = this.parseSkillMd(content, filePath, options);
      if (skill) {
        this.skills.set(skill.key, skill);
      }
    } catch (err) {
      console.error(`Failed to load skill from ${filePath}:`, err.message);
    }
  }

  parseSkillMd(content, filePath, options = {}) {
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)/);
    if (!frontmatterMatch) return null;

    const frontmatter = frontmatterMatch[1];
    const body = frontmatterMatch[2];

    const metadata = {};
    const lines = frontmatter.split('\n');
    for (const line of lines) {
      const match = line.match(/^(\w[\w-]*)\s*:\s*(.+)$/);
      if (match) {
        const key = match[1].trim();
        let value = match[2].trim();
        if (value.startsWith('{') || value.startsWith('[')) {
          try { value = JSON.parse(value); } catch {}
        } else if (value === 'true') value = true;
        else if (value === 'false') value = false;
        metadata[key] = value;
      }
    }

    const name = normalizeSkillName(metadata.name);
    if (!name) return null;

    const ownerType = options.ownerType || 'global';
    const userId = ownerType === 'user' || ownerType === 'legacy'
      ? normalizeStoredUserId(options.userId)
      : null;
    const mergedMetadata = {
      ...metadata,
      ...(options.metadata && typeof options.metadata === 'object' ? options.metadata : {}),
    };
    if (typeof options.enabled === 'boolean') {
      mergedMetadata.enabled = options.enabled;
    }

    return {
      key: buildSkillKey(ownerType, userId, name),
      name,
      description: metadata.description || '',
      metadata: mergedMetadata,
      instructions: body.trim(),
      filePath,
      dir: path.dirname(filePath),
      ownerType,
      userId,
      readOnly: ownerType !== 'user',
    };
  }

  getSkillsForPrompt(options = {}) {
    const maxTotalChars = options.maxTotalChars || 9000;
    const maxDescriptionChars = options.maxDescriptionChars || 220;
    const maxTriggerChars = options.maxTriggerChars || 120;
    const skills = this.getAll(options.userId)
      .filter((skill) => skill.metadata.enabled !== false)
      .sort((a, b) => {
        const categoryCompare = String(a.metadata?.category || 'general')
          .localeCompare(String(b.metadata?.category || 'general'));
        return categoryCompare || a.name.localeCompare(b.name);
      });
    if (skills.length === 0) return '';

    const lines = [
      '## Installed Skills',
      'These are reusable local workflows loaded into NeoAgent. Use a matching skill when it clearly fits the task. For exact metadata and file paths, use `list_skills`.',
    ];
    for (const skill of skills) {
      const parts = [`- \`${skill.name}\``];
      const tags = [];
      if (skill.metadata?.category) tags.push(skill.metadata.category);
      if (skill.metadata?.source) tags.push(skill.metadata.source);
      if (tags.length) {
        parts.push(`[${tags.join(' / ')}]`);
      }
      const description = clampText(skill.description, maxDescriptionChars);
      if (description) {
        parts.push(description);
      }
      const trigger = clampText(skill.metadata?.trigger || '', maxTriggerChars);
      if (trigger) {
        parts.push(`Trigger: ${trigger}`);
      }

      const nextLine = parts.join(' ');
      const candidate = `${lines.join('\n')}\n${nextLine}`;
      if (candidate.length > maxTotalChars) {
        lines.push(`- ...and ${skills.length - (lines.length - 2)} more skills. Use \`list_skills\` if you need the full catalog.`);
        break;
      }
      lines.push(nextLine);
    }
    return `\n${lines.join('\n')}`;
  }

  getToolDefinitions(options = {}) {
    const tools = [];
    for (const skill of this.getAll(options.userId)) {
      if (skill.metadata.enabled !== false && skill.metadata.tool) {
        tools.push({
          name: skill.name,
          description: skill.description,
          parameters: skill.metadata.parameters || { type: 'object', properties: {} }
        });
      }
    }
    return tools;
  }

  async executeTool(toolName, args, context = {}) {
    const skill = this.getSkill(toolName, context.userId);
    if (!skill) return null;
    const metricContext = {
      userId: context.userId,
      agentId: context.agentId || null,
      skillName: toolName,
    };
    this._recordSkillMetric(metricContext, { invocation: 1 });
    if (skill.metadata.enabled === false) {
      this._recordSkillMetric(metricContext, { failure: 1 });
      return { error: `Skill '${toolName}' is disabled` };
    }

    if (skill.metadata.command) {
      if (!isValidCommandTemplate(skill.metadata.command)) {
        this._recordSkillMetric(metricContext, { failure: 1 });
        return { error: `Skill '${toolName}' has an invalid command template` };
      }
      let command = skill.metadata.command;
      for (const [key, value] of Object.entries(args)) {
        command = command.replaceAll(`{${key}}`, shellEscape(value));
      }
      if (!isValidUserId(context.userId)) {
        this._recordSkillMetric(metricContext, { failure: 1 });
        return {
          error: 'Missing or invalid userId',
        };
      }
      if (!this.runtimeManager) {
        this._recordSkillMetric(metricContext, { failure: 1 });
        return {
          error: 'VM runtime is required',
        };
      }
      try {
        const result = await this.runtimeManager.executeCommand(context.userId, command);
        const failed = Boolean(result?.error) || (typeof result?.exitCode === 'number' && result.exitCode !== 0);
        this._recordSkillMetric(metricContext, failed ? { failure: 1 } : { success: 1 });
        return result;
      } catch (err) {
        const commandName = skill?.name || toolName || 'unknown';
        console.error('[SkillRunner] Skill command execution failed:', {
          userId: context.userId,
          commandName,
          command: String(command).slice(0, 200),
          error: err?.message || String(err),
        });
        this._recordSkillMetric(metricContext, { failure: 1 });
        return {
          error: 'Skill command execution failed',
          details: err?.message || String(err),
        };
      }
    }

    this._recordSkillMetric(metricContext, { failure: 1 });
    return {
      error: `Skill '${toolName}' is documentation-only and cannot execute directly.`,
      skill: skill.name,
      instructions: skill.instructions,
      args
    };
  }

  _recordSkillMetric(context, delta = {}) {
    if (!isValidUserId(context.userId)) return;
    db.prepare(
      `INSERT INTO skill_metrics (
        user_id, agent_id, skill_name, invocation_count, success_count,
        failure_count, correction_count, total_tokens, last_used_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
      ON CONFLICT(user_id, agent_id, skill_name) DO UPDATE SET
        invocation_count = invocation_count + excluded.invocation_count,
        success_count = success_count + excluded.success_count,
        failure_count = failure_count + excluded.failure_count,
        correction_count = correction_count + excluded.correction_count,
        total_tokens = total_tokens + excluded.total_tokens,
        last_used_at = datetime('now'),
        updated_at = datetime('now')`
    ).run(
      context.userId,
      context.agentId,
      context.skillName,
      Number(delta.invocation || 0),
      Number(delta.success || 0),
      Number(delta.failure || 0),
      Number(delta.correction || 0),
      Number(delta.tokens || 0),
    );
  }

  createSkill(userId, name, description, instructions, metadata = {}) {
    const ownerId = normalizeRuntimeUserId(userId);
    if (ownerId === null) {
      return { error: 'Missing or invalid userId' };
    }
    const safeName = normalizeSkillName(name);
    if (!safeName) {
      return { error: 'Skill name is required' };
    }
    if (this._findOwnedSkill(safeName, ownerId)) {
      return { error: `Skill '${safeName}' already exists` };
    }

    const metaToWrite = metadata && typeof metadata === 'object' ? metadata : {};
    const skillDir = path.join(USER_SKILLS_DIR, String(ownerId), safeName);
    if (!fs.existsSync(skillDir)) fs.mkdirSync(skillDir, { recursive: true });

    const frontmatter = this._buildFrontmatter(safeName, description, metaToWrite);
    const filePath = path.join(skillDir, 'SKILL.md');
    fs.writeFileSync(filePath, frontmatter + `\n\n${instructions}`);

    try {
      db.prepare(`
        INSERT INTO skills (user_id, name, description, file_path, metadata, enabled, auto_created, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 1, datetime('now'))
      `).run(
        ownerId,
        safeName,
        description,
        filePath,
        JSON.stringify(metaToWrite),
        metaToWrite.enabled === false ? 0 : 1,
      );
    } catch (err) {
      try {
        fs.unlinkSync(filePath);
      } catch {}
      try {
        const remaining = fs.readdirSync(skillDir);
        if (remaining.length === 0) fs.rmdirSync(skillDir);
      } catch {}
      if (String(err?.message || '').includes('UNIQUE')) {
        return { error: `Skill '${safeName}' already exists` };
      }
      throw err;
    }

    this.loadSkillFile(filePath, {
      ownerType: 'user',
      userId: ownerId,
      enabled: metaToWrite.enabled !== false,
      metadata: metaToWrite,
    });

    return { success: true, name: safeName, path: filePath };
  }

  updateSkill(userId, name, { description, instructions, metadata } = {}) {
    const ownerId = normalizeRuntimeUserId(userId);
    const skill = this.getSkill(name, ownerId);
    if (!skill) return { error: `Skill '${name}' not found` };
    if (!this._canEditSkill(skill, ownerId)) {
      return { error: `Skill '${skill.name}' is read-only`, code: 'forbidden' };
    }

    const newDesc = description !== undefined ? description : skill.description;
    const newInstructions = instructions !== undefined ? instructions : skill.instructions;
    // Merge: if metadata provided use it, otherwise preserve existing non-name/description fields
    let metaToWrite = {};
    if (metadata !== undefined) {
      metaToWrite = metadata;
    } else {
      const existing = { ...skill.metadata };
      delete existing.name;
      delete existing.description;
      metaToWrite = existing;
    }

    const frontmatter = this._buildFrontmatter(skill.name, newDesc, metaToWrite);
    fs.writeFileSync(skill.filePath, frontmatter + `\n\n${newInstructions}`);
    db.prepare(
      `UPDATE skills
       SET description = ?, metadata = ?, enabled = ?, updated_at = datetime('now')
       WHERE user_id = ? AND name = ?`
    ).run(
      newDesc,
      JSON.stringify(metaToWrite || {}),
      metaToWrite?.enabled === false ? 0 : 1,
      ownerId,
      skill.name,
    );
    this.loadSkillFile(skill.filePath, {
      ownerType: 'user',
      userId: ownerId,
      enabled: metaToWrite?.enabled !== false,
      metadata: metaToWrite,
    });

    return { success: true, name: skill.name, path: skill.filePath };
  }

  getSkill(name, userId = null) {
    const skillName = normalizeSkillName(name);
    if (!skillName) return null;
    const ownerId = normalizeRuntimeUserId(userId);
    if (ownerId !== null) {
      const owned = this._findOwnedSkill(skillName, ownerId);
      if (owned) return owned;
    }
    return this._findVisibleSkill(skillName, ownerId);
  }

  setSkillEnabled(userId, name, enabled) {
    const skill = this.getSkill(name, userId);
    if (!skill) return { error: `Skill '${name}' not found` };
    if (!this._canEditSkill(skill, normalizeRuntimeUserId(userId))) {
      return { error: `Skill '${skill.name}' is read-only`, code: 'forbidden' };
    }
    const metadata = { ...skill.metadata, enabled: !!enabled };
    return this.updateSkill(userId, skill.name, { metadata });
  }

  deleteSkill(userId, name) {
    const ownerId = normalizeRuntimeUserId(userId);
    const skill = this.getSkill(name, ownerId);
    if (!skill) return { error: `Skill '${name}' not found` };
    if (!this._canEditSkill(skill, ownerId)) {
      return { error: `Skill '${skill.name}' is read-only`, code: 'forbidden' };
    }

    try {
      fs.unlinkSync(skill.filePath);
      const dir = path.dirname(skill.filePath);
      if (path.basename(skill.filePath) === 'SKILL.md') {
        const remaining = fs.readdirSync(dir);
        if (remaining.length === 0) fs.rmdirSync(dir);
      }
    } catch (e) { /* ignore */ }

    db.prepare('DELETE FROM skills WHERE user_id = ? AND name = ?').run(ownerId, skill.name);
    this.skills.delete(skill.key);

    return { success: true, deleted: skill.name };
  }

  _buildFrontmatter(name, description, metadata = {}) {
    let fm = `---\nname: ${name}\ndescription: ${description}\n`;
    if (metadata && typeof metadata === 'object') {
      for (const [key, val] of Object.entries(metadata)) {
        if (key === 'name' || key === 'description') continue;
        fm += typeof val === 'object'
          ? `${key}: ${JSON.stringify(val)}\n`
          : `${key}: ${val}\n`;
      }
    }
    fm += `---`;
    return fm;
  }

  getAll(userId = null) {
    return this._getVisibleSkills(userId).map((s) => ({
      name: s.name,
      description: s.description,
      metadata: s.metadata,
      filePath: s.filePath,
      enabled: s.metadata.enabled !== false,
      userId: s.userId,
      ownerType: s.ownerType,
      readOnly: s.readOnly,
    }));
  }

  findSkillByWorkflowSignature(userId, workflowSignature) {
    const ownerId = normalizeRuntimeUserId(userId);
    if (ownerId === null || !workflowSignature) return null;
    return Array.from(this.skills.values()).find(
      (skill) => skill.ownerType === 'user'
        && skill.userId === ownerId
        && skill.metadata?.workflow_signature === workflowSignature,
    ) || null;
  }

  _findOwnedSkill(name, userId) {
    const ownerId = normalizeRuntimeUserId(userId);
    if (ownerId === null) return null;
    return this.skills.get(buildSkillKey('user', ownerId, normalizeSkillName(name))) || null;
  }

  _findVisibleSkill(name, userId) {
    const skillName = normalizeSkillName(name);
    return this._getVisibleSkills(userId).find((skill) => skill.name === skillName) || null;
  }

  _getVisibleSkills(userId = null) {
    const ownerId = normalizeRuntimeUserId(userId);
    const visible = Array.from(this.skills.values()).filter((skill) => {
      if (ownerId === null) return true;
      if (skill.ownerType === 'user') return skill.userId === ownerId;
      return true;
    });
    if (ownerId === null) return visible;
    const ownedNames = new Set(
      visible
        .filter((skill) => skill.ownerType === 'user' && skill.userId === ownerId)
        .map((skill) => skill.name),
    );
    return visible.filter((skill) => {
      if (skill.ownerType === 'user') return skill.userId === ownerId;
      return !ownedNames.has(skill.name);
    });
  }

  _canEditSkill(skill, userId) {
    const ownerId = normalizeRuntimeUserId(userId);
    return skill?.ownerType === 'user' && skill.userId === ownerId;
  }
}

module.exports = {
  SkillRunner,
  LEGACY_SKILL_USER_ID,
  USER_SKILLS_DIR,
  normalizeSkillName,
};
