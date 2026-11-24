'use strict';

// Skills tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'create_skill',
    persistent: true,
    group: 'skills', access: 'write', sideEffect: 'config', stateScope: 'skills', latencyClass: 'local',
    capabilities: ['skill', 'create'],
    policy: { category: 'skill_mutation' },
    description: 'Create a new SKILL.md file — a persistent custom tool or workflow you can call by name in future runs. Use this sparingly and only for genuinely reusable, well-specified capabilities.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Skill name in kebab-case (e.g. check-disk-health)' },
        description: { type: 'string', description: 'One-line description of what this skill does' },
        instructions: { type: 'string', description: 'Full markdown body: how to use this skill, example commands, expected output, etc.' },
        metadata: { type: 'object', description: 'Optional extra frontmatter fields. Use { "command": "...", "tool": true } to make it an executable tool with parameter substitution via {param}.' }
      },
      required: ['name', 'description', 'instructions']
    }
  },
  {
    name: 'list_skills',
    group: 'skills', access: 'read', stateScope: 'skills', latencyClass: 'local',
    capabilities: ['skill', 'list'],
    description: 'List all currently loaded skills (both built-in and self-created ones). Pass a skill name to load that skill\'s full instructions before following it.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Skill name whose full instructions to load (optional)' }
      }
    }
  },
  {
    name: 'update_skill',
    persistent: true,
    group: 'skills', access: 'write', sideEffect: 'config', stateScope: 'skills', latencyClass: 'local',
    capabilities: ['skill', 'update'],
    policy: { category: 'skill_mutation' },
    description: 'Update an existing skill, including learned ones — change its description, instructions or metadata. Load the current instructions with list_skills first and send the full revised text.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Exact skill name to update' },
        description: { type: 'string', description: 'New description (optional)' },
        instructions: { type: 'string', description: 'New instructions body (optional)' },
        metadata: { type: 'object', description: 'Metadata fields to change (optional); fields not given are kept' }
      },
      required: ['name']
    }
  },
  {
    name: 'delete_skill',
    group: 'skills', access: 'write', sideEffect: 'config', stateScope: 'skills', latencyClass: 'local',
    capabilities: ['skill', 'delete'],
    policy: { category: 'skill_mutation' },
    description: 'Permanently delete a skill by name.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Exact skill name to delete' }
      },
      required: ['name']
    }
  },
];
