'use strict';

// Finds and reads skill folders (SKILL.md plus bundled files).

const fs = require('fs');
const path = require('path');
const { isDir, readText } = require('./common');
const { collapse } = require('./memory_text');

const SKILL_FILE_SKIP = new Set(['.git', 'node_modules', '__pycache__', '.venv', 'venv', '.DS_Store']);
const MAX_SKILL_FILE_BYTES = 5 * 1024 * 1024;

// Files bundled with a skill (scripts, references, templates), relative to
// the skill folder, without SKILL.md itself.
function listSkillFiles(dir) {
  const files = [];
  const walk = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      if (SKILL_FILE_SKIP.has(entry.name)) continue;
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && full !== path.join(dir, 'SKILL.md')) {
        if (fs.statSync(full).size <= MAX_SKILL_FILE_BYTES) files.push(path.relative(dir, full));
      }
    }
  };
  walk(dir);
  return files;
}

// Every folder holding a SKILL.md under root, at any depth (Hermes nests
// skills in category folders). A skill's own subfolders are not searched.
function findSkillDirs(root) {
  const found = [];
  const walk = (dir, depth) => {
    if (depth > 4) return;
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    if (entries.some((entry) => entry.isFile() && entry.name === 'SKILL.md')) {
      found.push(dir);
      return;
    }
    for (const entry of entries) {
      if (entry.isDirectory() && !SKILL_FILE_SKIP.has(entry.name) && !entry.name.startsWith('.')) {
        walk(path.join(dir, entry.name), depth + 1);
      }
    }
  };
  if (isDir(root)) walk(root, 0);
  return found;
}

// A skill folder → { name, description, body, dir, files }. A SKILL.md
// without frontmatter still imports, named after its folder.
function readSkill(dir, origin) {
  const { parseFrontmatter } = require('../../server/services/skills/skills_sh');
  const text = readText(path.join(dir, 'SKILL.md'));
  if (text == null || !text.trim()) return null;
  const parsed = parseFrontmatter(text);
  const body = (parsed ? parsed.body : text).trim();
  const firstLine = body.split('\n').map((line) => line.replace(/^#+\s*/, '').trim()).find(Boolean) || '';
  return {
    name: String(parsed?.data.name || path.basename(dir)).trim(),
    description: collapse(parsed?.data.description || firstLine).slice(0, 300),
    body,
    dir,
    origin,
    files: listSkillFiles(dir),
  };
}

module.exports = {
  findSkillDirs,
  readSkill,
};
