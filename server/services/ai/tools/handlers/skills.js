'use strict';

const handlers = {
  async create_skill(args, ctx) {
    const { sk, userId } = ctx;
    const { SkillRunner } = require('../../toolRunner');
    const sharedRunner = sk();
    if (sharedRunner) {
    const result = sharedRunner.createSkill(userId, args.name, args.description, args.instructions, args.metadata);
    return result;
    }
    const runner = new SkillRunner();
    await runner.loadSkills();
    return runner.createSkill(userId, args.name, args.description, args.instructions, args.metadata);
  },

  async list_skills(args, ctx) {
    const { sk, userId } = ctx;
    const skillRunner = sk();
    if (!skillRunner) return { error: 'Skill runner not available' };
    if (args.name) {
    const skill = skillRunner.getSkill(args.name, userId);
    if (!skill) return { error: `No skill named '${args.name}'.` };
    if (skill.metadata.enabled === false) return { error: `Skill '${skill.name}' is disabled.` };
    return { name: skill.name, description: skill.description, metadata: skill.metadata, instructions: skill.instructions };
    }
    // Skill files live on the NeoAgent host, which the agent's tools
    // cannot read; their contents come from this tool instead.
    const all = skillRunner.getAll(userId).map(({ filePath: _filePath, ...skill }) => skill);
    return { skills: all, count: all.length };
  },

  async update_skill(args, ctx) {
    const { sk, userId } = ctx;
    const skillRunner = sk();
    if (!skillRunner) return { error: 'Skill runner not available' };
    // The model changes only the fields it names; the rest, including
    // the learning record of a learned skill, carries over.
    const current = skillRunner.getSkill(args.name, userId);
    const metadata = current && args.metadata && typeof args.metadata === 'object'
    ? { ...current.metadata, ...args.metadata }
    : args.metadata;
    return skillRunner.updateSkill(userId, args.name, {
    description: args.description,
    instructions: args.instructions,
    metadata
    });
  },

  async delete_skill(args, ctx) {
    const { sk, userId } = ctx;
    const skillRunner = sk();
    if (!skillRunner) return { error: 'Skill runner not available' };
    return skillRunner.deleteSkill(userId, args.name);
  },
};

module.exports = { handlers };
