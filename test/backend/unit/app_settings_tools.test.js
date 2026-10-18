'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const FLUTTER_LIB = path.join(__dirname, '..', '..', '..', 'flutter_app', 'lib');

let ctx;
let user;
let agentId;
let tools;
let emitted;
let app;

function dartSources() {
  return fs.readdirSync(FLUTTER_LIB)
    .filter((name) => name.endsWith('.dart'))
    .map((name) => fs.readFileSync(path.join(FLUTTER_LIB, name), 'utf8'))
    .join('\n');
}

function run(name, args) {
  return tools.executeAppSettingsTool(name, args, { userId: user.userId, agentId, app });
}

before(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
  agentId = require('../../../server/services/agents/manager').resolveAgentId(user.userId, null);
  tools = require('../../../server/services/ai/integrated_tools/app_settings');
  emitted = [];
  app = {
    locals: {
      io: { to: (room) => ({ emit: (event, payload) => emitted.push({ room, event, payload }) }) },
      integrationManager: {
        registry: { list: () => [{ key: 'google' }, { key: 'notion' }] },
        listProviders: () => [
          { id: 'google', label: 'Google', connection: { connected: true }, env: { configured: true } },
          { id: 'notion', label: 'Notion', connection: { connected: false }, env: { configured: false } },
        ],
      },
    },
  };
});

after(() => teardownTestRuntime(ctx));

test('settings_update changes an allowed setting and tells the app', async () => {
  const result = await run('settings_update', { key: 'voice_input_mode', value: 'ptt' });
  assert.equal(result.success, true);
  assert.equal(result.previous, 'hands_free');
  assert.equal(result.value, 'ptt');
  assert.match(result.link, /\/app\/open\/settings\/voice\/inputMode$/);
  assert.deepEqual(emitted.at(-1), {
    room: `user:${user.userId}`,
    event: 'settings:changed',
    payload: { agentId, keys: ['voice_input_mode'] },
  });

  const read = await run('settings_read', { keys: ['voice_input_mode'] });
  assert.equal(read.settings[0].value, 'ptt');
  assert.deepEqual(read.settings[0].choices.map((choice) => choice.value), ['hands_free', 'ptt']);
});

test('settings_update refuses values and keys outside the catalog', async () => {
  const badValue = await run('settings_update', { key: 'voice_input_mode', value: 'always_on' });
  assert.equal(badValue.success, false);
  assert.ok(badValue.choices.length > 0);

  const guessedKey = await run('settings_update', { key: 'input_mode', value: 'hands_free' });
  assert.equal(guessedKey.success, true);
  assert.equal(guessedKey.key, 'voice_input_mode');

  const badKey = await run('settings_update', { key: 'runtime_backend', value: 'host' });
  assert.equal(badKey.success, false);
  assert.match(badKey.error, /settings_link/);

  const badZone = await run('settings_update', { key: 'timezone', value: 'Mars/Olympus' });
  assert.equal(badZone.success, false);
});

test('related settings follow the change the assistant made', async () => {
  const store = require('../../../server/services/settings/store');
  store.applySettingsUpdate({ userId: user.userId, agentId, patch: { voice_live_voice: 'Kore' } });

  const provider = await run('settings_update', { key: 'voice_live_provider', value: 'openai' });
  assert.equal(provider.success, true);
  assert.equal(store.readSettingValue(user.userId, agentId, 'voice_live_voice'), '');

  const zone = await run('settings_update', { key: 'timezone', value: 'Europe/Berlin' });
  assert.equal(zone.success, true);
  assert.equal(store.readSettingValue(user.userId, agentId, 'timezone_auto'), false);
});

test('settings_read lists integrations and the places links can open', async () => {
  const read = await run('settings_read', { keys: ['timezone'] });
  assert.deepEqual(
    read.integrations.map(({ link, ...rest }) => rest),
    [
      { key: 'google', label: 'Google', connected: true, available: true },
      { key: 'notion', label: 'Notion', connected: false, available: false },
    ],
  );
  assert.match(read.integrations[1].link, /\/app\/open\/integrations\/notion$/);
  assert.ok(read.places.settingsPages.security.anchors.includes('twoFactor'));
  assert.match(read.places.settingsPages.security.link, /\/app\/open\/settings\/security$/);
  assert.match(read.places.sections.tasks.link, /\/app\/open\/tasks$/);
});

test('settings_link builds app links and rejects unknown places', async () => {
  assert.match((await run('settings_link', { section: 'integrations', focus: 'notion' })).url, /\/app\/open\/integrations\/notion$/);
  assert.match((await run('settings_link', { section: 'settings', page: 'security', focus: 'twoFactor' })).url, /\/app\/open\/settings\/security\/twoFactor$/);
  assert.match((await run('settings_link', { section: 'settings', page: 'models', focus: 'nope' })).error, /chatModel/);
  assert.match((await run('settings_link', { section: 'integrations', focus: 'dropbox' })).error, /google/);
  assert.match((await run('settings_link', { section: 'settings' })).error, /settings page/);
});

test('every linkable page, section and anchor exists in the Flutter app', () => {
  const { APP_SECTIONS, SETTINGS_PAGES } = require('../../../server/services/settings/app_links');
  const source = dartSources();
  const enumValues = (name) => {
    const body = source.match(new RegExp(`enum ${name} \\{([^}]*)\\}`))[1];
    return body.split(',').map((value) => value.trim()).filter(Boolean);
  };
  const pages = enumValues('SettingsPage');
  const sections = enumValues('AppSection');
  for (const section of Object.keys(APP_SECTIONS)) {
    assert.ok(sections.includes(section), `AppSection.${section} is missing`);
  }
  for (const [page, entry] of Object.entries(SETTINGS_PAGES)) {
    assert.ok(pages.includes(page), `SettingsPage.${page} is missing`);
    for (const anchor of entry.anchors) {
      assert.ok(
        source.includes(`anchor: '${anchor}'`) || source.includes(`id: '${anchor}'`),
        `settings anchor ${anchor} is missing`,
      );
    }
  }
});
