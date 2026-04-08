const { SkillRunner } = require('../ai/toolRunner');

async function getSkillRunner(app) {
  if (app?.locals?.skillRunner) {
    return app.locals.skillRunner;
  }
  const runner = new SkillRunner();
  await runner.loadSkills();
  return runner;
}

function serializeInstalledSkill(skill) {
  return {
    name: skill.name,
    description: skill.description,
    enabled: skill.enabled,
    draft: skill.metadata?.draft === true,
    category: skill.metadata?.category || 'general',
    trigger: skill.metadata?.trigger || '',
    source: skill.metadata?.source || 'local',
    autoCreated: skill.metadata?.auto_created === true,
    filePath: skill.filePath,
    storeId: skill.metadata?.store_id || '',
  };
}

function sortInstalledSkills(a, b) {
  if (a.draft !== b.draft) return a.draft ? -1 : 1;
  return a.name.localeCompare(b.name);
}

module.exports = {
  getSkillRunner,
  serializeInstalledSkill,
  sortInstalledSkills,
};
