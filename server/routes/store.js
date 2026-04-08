const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { STORE_CATALOG } = require('../services/skills/catalog');
const { getSkillRunner } = require('../services/skills/runtime');
const {
  getCatalogInstallPath,
  injectCatalogMetadata,
  installCatalogSkill,
  listCatalog,
  listInstalledCatalogIds,
  uninstallCatalogSkill,
} = require('../services/skills/store_service');

router.use(requireAuth);
const CATALOG = STORE_CATALOG;

// ── Routes ─────────────────────────────────────────────────────────────────────

/** GET /api/store — return catalog with installed status */
router.get('/', async (req, res) => {
  try {
    const runner = await getSkillRunner(req.app);
    res.json(listCatalog(CATALOG, runner));
  } catch (error) {
    res.status(500).json({ error: error.message || 'Failed to load store catalog' });
  }
});

/** POST /api/store/:id/install — write the skill file */
router.post('/:id/install', async (req, res) => {
  try {
    const skill = CATALOG.find(s => s.id === req.params.id);
    if (!skill) return res.status(404).json({ error: 'Skill not found in catalog' });

    const skillRunner = req.app.locals?.skillRunner;
    const { skillPath } = await installCatalogSkill(skill, skillRunner);

    res.json({ success: true, id: skill.id, name: skill.name, filePath: skillPath });
  } catch (error) {
    res.status(500).json({ error: error.message || 'Failed to install skill' });
  }
});

/** DELETE /api/store/:id/uninstall — remove the skill file */
router.delete('/:id/uninstall', async (req, res) => {
  try {
    const skill = CATALOG.find(s => s.id === req.params.id);
    if (!skill) return res.status(404).json({ error: 'Skill not found in catalog' });
    await uninstallCatalogSkill(skill, req.app.locals?.skillRunner);

    res.json({ success: true, id: skill.id });
  } catch (error) {
    res.status(500).json({ error: error.message || 'Failed to uninstall skill' });
  }
});

router.CATALOG = CATALOG;
router.installCatalogSkill = installCatalogSkill;
router.uninstallCatalogSkill = uninstallCatalogSkill;
router.listInstalledSkillIds = (skillRunner) => listInstalledCatalogIds(CATALOG, skillRunner);
router.getCatalogInstallPath = getCatalogInstallPath;
router.injectCatalogMetadata = injectCatalogMetadata;

module.exports = router;
