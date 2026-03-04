const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { requireAuth } = require('../middleware/auth');

const SKILLS_DIR = path.join(__dirname, '../../agent-data/skills');

router.use(requireAuth);

// List all skills
router.get('/', (req, res) => {
  if (!fs.existsSync(SKILLS_DIR)) fs.mkdirSync(SKILLS_DIR, { recursive: true });

  const files = fs.readdirSync(SKILLS_DIR).filter(f => f.endsWith('.md'));
  const skills = files.map(f => {
    const content = fs.readFileSync(path.join(SKILLS_DIR, f), 'utf-8');
    const meta = parseSkillMeta(content);
    return {
      filename: f,
      name: meta.name || f.replace('.md', ''),
      description: meta.description || '',
      trigger: meta.trigger || '',
      enabled: meta.enabled !== false,
      category: meta.category || 'general'
    };
  });

  res.json(skills);
});

// Get a specific skill
router.get('/:filename', (req, res) => {
  const fp = path.join(SKILLS_DIR, req.params.filename);
  if (!fs.existsSync(fp)) return res.status(404).json({ error: 'Skill not found' });

  const content = fs.readFileSync(fp, 'utf-8');
  res.json({ filename: req.params.filename, content, meta: parseSkillMeta(content) });
});

// Create a new skill
router.post('/', (req, res) => {
  const { filename, content } = req.body;
  if (!filename || !content) return res.status(400).json({ error: 'filename and content required' });

  const baseName = filename.replace(/\.md$/i, '').replace(/[^a-zA-Z0-9_.-]/g, '');
  const safeName = baseName + '.md';
  const fp = path.join(SKILLS_DIR, safeName);

  if (!fs.existsSync(SKILLS_DIR)) fs.mkdirSync(SKILLS_DIR, { recursive: true });

  fs.writeFileSync(fp, content, 'utf-8');
  res.status(201).json({ filename: safeName, meta: parseSkillMeta(content) });
});

// Update a skill
router.put('/:filename', (req, res) => {
  const fp = path.join(SKILLS_DIR, req.params.filename);
  if (!fs.existsSync(fp)) return res.status(404).json({ error: 'Skill not found' });

  fs.writeFileSync(fp, req.body.content, 'utf-8');
  res.json({ filename: req.params.filename, meta: parseSkillMeta(req.body.content) });
});

// Delete a skill
router.delete('/:filename', (req, res) => {
  const fp = path.join(SKILLS_DIR, req.params.filename);
  if (!fs.existsSync(fp)) return res.status(404).json({ error: 'Skill not found' });

  fs.unlinkSync(fp);
  res.json({ success: true });
});

function parseSkillMeta(content) {
  const meta = {};
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return meta;

  const lines = match[1].split('\n');
  for (const line of lines) {
    const colon = line.indexOf(':');
    if (colon === -1) continue;
    const key = line.slice(0, colon).trim();
    let val = line.slice(colon + 1).trim();
    if (val === 'true') val = true;
    else if (val === 'false') val = false;
    meta[key] = val;
  }
  return meta;
}

module.exports = router;
