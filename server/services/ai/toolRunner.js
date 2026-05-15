const fs = require('fs');
const path = require('path');
const db = require('../../db/database');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');

const SKILLS_DIR = path.join(AGENT_DATA_DIR, 'skills');

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
  if (typeof userId === 'number') {
    return Number.isInteger(userId) && userId > 0;
  }
  if (typeof userId === 'string') {
    return userId.trim() !== '';
  }
  return false;
}

class SkillRunner {
  constructor(options = {}) {
    this.skills = new Map();
    this.runtimeManager = options.runtimeManager || null;
  }

  async loadSkills() {
    this.skills.clear();
    if (!fs.existsSync(SKILLS_DIR)) return;

    const loadDir = (dir) => {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          const skillFile = path.join(fullPath, 'SKILL.md');
          if (fs.existsSync(skillFile)) {
            this.loadSkillFile(skillFile);
          }
          loadDir(fullPath);
        } else if (entry.name.endsWith('.md')) {
          this.loadSkillFile(fullPath);
        }
      }
    };

    loadDir(SKILLS_DIR);

    const dbSkills = db.prepare('SELECT * FROM skills WHERE enabled = 1').all();
    for (const skill of dbSkills) {
      if (fs.existsSync(skill.file_path)) {
        this.loadSkillFile(skill.file_path);
      }
    }
  }

  loadSkillFile(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const skill = this.parseSkillMd(content, filePath);
      if (skill) {
        this.skills.set(skill.name, skill);
      }
    } catch (err) {
      console.error(`Failed to load skill from ${filePath}:`, err.message);
    }
  }

  parseSkillMd(content, filePath) {
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

    if (!metadata.name) return null;

    return {
      name: metadata.name,
      description: metadata.description || '',
      metadata,
      instructions: body.trim(),
      filePath,
      dir: path.dirname(filePath)
    };
  }

  getSkillsForPrompt(options = {}) {
    const maxTotalChars = options.maxTotalChars || 9000;
    const maxDescriptionChars = options.maxDescriptionChars || 220;
    const maxTriggerChars = options.maxTriggerChars || 120;
    const skills = Array.from(this.skills.values())
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

  getToolDefinitions() {
    const tools = [];
    for (const skill of this.skills.values()) {
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
    const skill = this.skills.get(toolName);
    if (!skill) return null;
    if (skill.metadata.enabled === false) {
      return { error: `Skill '${toolName}' is disabled` };
    }

    if (skill.metadata.command) {
      if (!isValidCommandTemplate(skill.metadata.command)) {
        return { error: `Skill '${toolName}' has an invalid command template` };
      }
      let command = skill.metadata.command;
      for (const [key, value] of Object.entries(args)) {
        command = command.replaceAll(`{${key}}`, shellEscape(value));
      }
      if (!isValidUserId(context.userId)) {
        return {
          error: 'Missing or invalid userId',
        };
      }
      if (!this.runtimeManager) {
        return {
          error: 'VM runtime is required',
        };
      }
      try {
        return await this.runtimeManager.executeCommand(context.userId, command);
      } catch (err) {
        const commandName = skill?.name || toolName || 'unknown';
        console.error('[SkillRunner] Skill command execution failed:', {
          userId: context.userId,
          commandName,
          command: String(command).slice(0, 200),
          error: err?.message || String(err),
        });
        return {
          error: 'Skill command execution failed',
          details: err?.message || String(err),
        };
      }
    }

    return {
      error: `Skill '${toolName}' is documentation-only and cannot execute directly.`,
      skill: skill.name,
      instructions: skill.instructions,
      args
    };
  }

  createSkill(name, description, instructions, metadata = {}) {
    const safeName = name.replace(/[^a-z0-9-]/gi, '-').toLowerCase();
    const skillDir = path.join(SKILLS_DIR, safeName);
    if (!fs.existsSync(skillDir)) fs.mkdirSync(skillDir, { recursive: true });

    const frontmatter = this._buildFrontmatter(safeName, description, metadata);
    const filePath = path.join(skillDir, 'SKILL.md');
    fs.writeFileSync(filePath, frontmatter + `\n\n${instructions}`);

    db.prepare(`
      INSERT OR REPLACE INTO skills (name, description, file_path, metadata, enabled, auto_created, updated_at)
      VALUES (?, ?, ?, ?, ?, 1, datetime('now'))
    `).run(safeName, description, filePath, JSON.stringify(metadata), metadata.enabled === false ? 0 : 1);

    this.loadSkillFile(filePath);

    return { success: true, name: safeName, path: filePath };
  }

  updateSkill(name, { description, instructions, metadata } = {}) {
    const skill = this.skills.get(name);
    if (!skill) return { error: `Skill '${name}' not found` };

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

    const frontmatter = this._buildFrontmatter(name, newDesc, metaToWrite);
    fs.writeFileSync(skill.filePath, frontmatter + `\n\n${newInstructions}`);
    db.prepare('UPDATE skills SET description = ?, metadata = ?, enabled = ?, updated_at = datetime(\'now\') WHERE name = ?')
      .run(newDesc, JSON.stringify(metaToWrite || {}), metaToWrite?.enabled === false ? 0 : 1, name);
    this.loadSkillFile(skill.filePath);

    return { success: true, name, path: skill.filePath };
  }

  getSkill(name) {
    return this.skills.get(name) || null;
  }

  setSkillEnabled(name, enabled) {
    const skill = this.skills.get(name);
    if (!skill) return { error: `Skill '${name}' not found` };
    const metadata = { ...skill.metadata, enabled: !!enabled };
    return this.updateSkill(name, { metadata });
  }

  deleteSkill(name) {
    const skill = this.skills.get(name);
    if (!skill) return { error: `Skill '${name}' not found` };

    try {
      fs.unlinkSync(skill.filePath);
      const dir = path.dirname(skill.filePath);
      if (path.basename(skill.filePath) === 'SKILL.md') {
        const remaining = fs.readdirSync(dir);
        if (remaining.length === 0) fs.rmdirSync(dir);
      }
    } catch (e) { /* ignore */ }

    db.prepare('DELETE FROM skills WHERE name = ?').run(name);
    this.skills.delete(name);

    return { success: true, deleted: name };
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

  getAll() {
    return Array.from(this.skills.values()).map(s => ({
      name: s.name,
      description: s.description,
      metadata: s.metadata,
      filePath: s.filePath,
      enabled: s.metadata.enabled !== false
    }));
  }
}

module.exports = { SkillRunner };
