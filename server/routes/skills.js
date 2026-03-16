const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { SkillRunner } = require('../services/ai/toolRunner');

router.use(requireAuth);

async function getSkillRunner(app) {
  if (app.locals?.skillRunner) return app.locals.skillRunner;
  const runner = new SkillRunner();
  await runner.loadSkills();
  return runner;
}

function parseSkillDocument(content) {
  const match = String(content || '').match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) {
    return {
      error: 'Skill files must start with frontmatter delimited by ---'
    };
  }

  const frontmatter = {};
  for (const line of match[1].split('\n')) {
    const colon = line.indexOf(':');
    if (colon === -1) continue;
    const key = line.slice(0, colon).trim();
    let value = line.slice(colon + 1).trim();
    if (value === 'true') value = true;
    else if (value === 'false') value = false;
    else if ((value.startsWith('{') && value.endsWith('}')) || (value.startsWith('[') && value.endsWith(']'))) {
      try { value = JSON.parse(value); } catch { /* keep raw */ }
    }
    frontmatter[key] = value;
  }

  if (!frontmatter.name) {
    return { error: 'Skill frontmatter must include name' };
  }

  return {
    name: String(frontmatter.name),
    description: String(frontmatter.description || ''),
    instructions: match[2].trim(),
    metadata: Object.fromEntries(
      Object.entries(frontmatter).filter(([key]) => !['name', 'description'].includes(key))
    )
  };
}

router.get('/', async (req, res) => {
  try {
    const runner = await getSkillRunner(req.app);
    const skills = runner.getAll().map((skill) => ({
      name: skill.name,
      description: skill.description,
      enabled: skill.enabled,
      draft: skill.metadata?.draft === true,
      category: skill.metadata?.category || 'general',
      trigger: skill.metadata?.trigger || '',
      source: skill.metadata?.source || 'local',
      autoCreated: skill.metadata?.auto_created === true,
      filePath: skill.filePath
    }));
    res.json(skills.sort((a, b) => {
      if (a.draft !== b.draft) return a.draft ? -1 : 1;
      return a.name.localeCompare(b.name);
    }));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/:name', async (req, res) => {
  try {
    const runner = await getSkillRunner(req.app);
    const skill = runner.getSkill(req.params.name);
    if (!skill) return res.status(404).json({ error: 'Skill not found' });
    const fs = require('fs');
    const content = fs.readFileSync(skill.filePath, 'utf-8');
    res.json({
      name: skill.name,
      content,
      meta: skill.metadata,
      enabled: skill.metadata?.enabled !== false
    });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/', async (req, res) => {
  try {
    const runner = await getSkillRunner(req.app);
    const parsed = parseSkillDocument(req.body.content);
    if (parsed.error) return res.status(400).json({ error: parsed.error });

    const result = runner.createSkill(
      req.body.filename || parsed.name,
      parsed.description,
      parsed.instructions,
      parsed.metadata
    );

    if (result.error) return res.status(400).json(result);
    res.status(201).json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.put('/:name', async (req, res) => {
  try {
    const runner = await getSkillRunner(req.app);
    if (typeof req.body.enabled === 'boolean' && !req.body.content) {
      const result = runner.setSkillEnabled(req.params.name, req.body.enabled);
      if (result.error) return res.status(404).json(result);
      return res.json(result);
    }

    const parsed = parseSkillDocument(req.body.content);
    if (parsed.error) return res.status(400).json({ error: parsed.error });
    const result = runner.updateSkill(req.params.name, {
      description: parsed.description,
      instructions: parsed.instructions,
      metadata: parsed.metadata
    });
    if (result.error) return res.status(404).json(result);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.delete('/:name', async (req, res) => {
  try {
    const runner = await getSkillRunner(req.app);
    const result = runner.deleteSkill(req.params.name);
    if (result.error) return res.status(404).json(result);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
