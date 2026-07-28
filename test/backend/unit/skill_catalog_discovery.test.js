'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const {
  discoverBundledSkillPaths,
} = require('../../../server/services/skills/store_bundles');

test('skill catalog discovers SKILL.md files and honors catalog opt-out', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-skill-catalog-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const visible = path.join(root, 'productivity', 'visible');
  const hidden = path.join(root, 'productivity', 'hidden');
  fs.mkdirSync(visible, { recursive: true });
  fs.mkdirSync(hidden, { recursive: true });
  fs.writeFileSync(
    path.join(visible, 'SKILL.md'),
    '---\nname: visible\ndescription: Visible skill\n---\n\nInstructions.\n',
  );
  fs.writeFileSync(
    path.join(hidden, 'SKILL.md'),
    '---\nname: hidden\ndescription: Hidden skill\ncatalog: false\n---\n\nInstructions.\n',
  );

  assert.deepEqual(discoverBundledSkillPaths(root), ['productivity/visible']);
});
