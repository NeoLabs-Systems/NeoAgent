'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { parseFrontmatter, parseSkillsShRef } = require('../../../server/services/skills/skills_sh');

test('skills.sh refs parse from page URLs, ids and the npx install command', () => {
  assert.deepEqual(
    parseSkillsShRef('https://www.skills.sh/vercel-labs/agent-skills/vercel-react-best-practices'),
    { source: 'vercel-labs/agent-skills', skillId: 'vercel-react-best-practices', name: 'vercel-react-best-practices' },
  );
  assert.deepEqual(
    parseSkillsShRef('owner/repo/skill'),
    { source: 'owner/repo', skillId: 'skill', name: 'skill' },
  );
  assert.deepEqual(
    parseSkillsShRef('npx skills add https://github.com/google-labs-code/stitch-skills --skill react:components'),
    { source: 'google-labs-code/stitch-skills', skillId: 'react:components', name: 'react:components' },
  );
  assert.equal(parseSkillsShRef('react'), null);
  assert.equal(parseSkillsShRef('https://skills.sh/owner/repo'), null);
  assert.equal(parseSkillsShRef('../../etc/passwd'), null);
});

test('skill frontmatter keeps block-scalar descriptions and skips nested keys', () => {
  const parsed = parseFrontmatter([
    '---',
    'name: "stitch::react-components"',
    'description: >-',
    '  Converts designs into',
    '  React components.',
    'metadata:',
    '  author: vercel',
    '---',
    '# Body',
  ].join('\n'));
  assert.equal(parsed.data.name, 'stitch::react-components');
  assert.equal(parsed.data.description, 'Converts designs into React components.');
  assert.equal(parsed.data.author, undefined);
  assert.equal(parsed.body, '# Body');
});

test('parseFeaturedPage reads the leaderboard a skills.sh page embeds', () => {
  const { parseFeaturedPage } = require('../../../server/services/skills/skills_sh');
  const html = [
    '<script>self.__next_f.push([1,"53:{\\"initialSkills\\":[',
    '{\\"source\\":\\"vercel-labs/skills\\",\\"skillId\\":\\"find-skills\\",\\"name\\":\\"find-skills\\",\\"installs\\":42,\\"weeklyInstalls\\":[1,2],\\"isOfficial\\":true},',
    '{\\"source\\":\\"bad source\\",\\"skillId\\":\\"x\\",\\"name\\":\\"x\\",\\"installs\\":1},',
    '{\\"source\\":\\"mattpocock/skills\\",\\"skillId\\":\\"grill-me\\",\\"name\\":\\"grill-me\\",\\"installs\\":7}',
    ']}"])</script>',
  ].join('');
  assert.deepEqual(parseFeaturedPage(html), [
    { id: 'vercel-labs/skills/find-skills', source: 'vercel-labs/skills', skillId: 'find-skills', name: 'find-skills', installs: 42, official: true },
    { id: 'mattpocock/skills/grill-me', source: 'mattpocock/skills', skillId: 'grill-me', name: 'grill-me', installs: 7, official: false },
  ]);
  assert.deepEqual(parseFeaturedPage('<html>nothing here</html>'), []);
});
