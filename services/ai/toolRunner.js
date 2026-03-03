const fs = require('fs');
const path = require('path');
const db = require('../../db/database');

const SKILLS_DIR = path.join(__dirname, '..', '..', 'agent-data', 'skills');

class SkillRunner {
  constructor() {
    this.skills = new Map();
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

  getSkillsForPrompt() {
    const skills = Array.from(this.skills.values());
    if (skills.length === 0) return '';

    let prompt = '\n## Available Skills\n';
    for (const skill of skills) {
      prompt += `\n### ${skill.name}\n${skill.description}\n`;
      if (skill.instructions) {
        prompt += `${skill.instructions.slice(0, 500)}\n`;
      }
    }
    return prompt;
  }

  getToolDefinitions() {
    const tools = [];
    for (const skill of this.skills.values()) {
      if (skill.metadata.tool) {
        tools.push({
          name: skill.name,
          description: skill.description,
          parameters: skill.metadata.parameters || { type: 'object', properties: {} }
        });
      }
    }
    return tools;
  }

  async executeTool(toolName, args) {
    const skill = this.skills.get(toolName);
    if (!skill) return null;

    if (skill.metadata.command) {
      const { CLIExecutor } = require('../cli/executor');
      const executor = new CLIExecutor();
      let command = skill.metadata.command;
      for (const [key, value] of Object.entries(args)) {
        command = command.replace(`{${key}}`, value);
      }
      return await executor.execute(command, { cwd: skill.dir });
    }

    return { skill: skill.name, instructions: skill.instructions, args };
  }

  createSkill(name, description, instructions, metadata = {}) {
    const safeName = name.replace(/[^a-z0-9-]/gi, '-').toLowerCase();
    const skillDir = path.join(SKILLS_DIR, safeName);
    if (!fs.existsSync(skillDir)) fs.mkdirSync(skillDir, { recursive: true });

    let frontmatter = `---\nname: ${safeName}\ndescription: ${description}\n`;
    if (metadata && Object.keys(metadata).length > 0) {
      frontmatter += `metadata: ${JSON.stringify(metadata)}\n`;
    }
    frontmatter += `---\n\n${instructions}`;

    const filePath = path.join(skillDir, 'SKILL.md');
    fs.writeFileSync(filePath, frontmatter);

    db.prepare('INSERT OR REPLACE INTO skills (name, description, file_path, metadata, auto_created, updated_at) VALUES (?, ?, ?, ?, 1, datetime(\'now\'))')
      .run(safeName, description, filePath, JSON.stringify(metadata));

    this.loadSkillFile(filePath);

    return { success: true, name: safeName, path: filePath };
  }

  getAll() {
    return Array.from(this.skills.values()).map(s => ({
      name: s.name,
      description: s.description,
      metadata: s.metadata,
      filePath: s.filePath
    }));
  }
}

module.exports = { SkillRunner };
