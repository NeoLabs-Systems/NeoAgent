'use strict';

const assert = require('node:assert/strict');
const Sqlite = require('better-sqlite3');
const { afterEach, beforeEach, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const KEY_ENVS = ['OPENAI_API_KEY', 'GOOGLE_AI_KEY', 'GEMINI_API_KEY', 'DEEPGRAM_API_KEY'];

describe('speech-to-text provider resolution', () => {
  let ctx;
  let userId;
  let savedEnv;
  let resolveSttTarget;
  let setProviderSecret;

  beforeEach(async () => {
    savedEnv = Object.fromEntries(KEY_ENVS.map((key) => [key, process.env[key]]));
    for (const key of KEY_ENVS) delete process.env[key];
    ctx = createTestRuntime();
    ({ userId } = await createTestUser(ctx.db));
    ({ resolveSttTarget } = require('../../../server/services/voice/transcription'));
    ({ setProviderSecret } = require('../../../server/services/ai/settings'));
  });

  afterEach(() => {
    teardownTestRuntime(ctx);
    for (const [key, value] of Object.entries(savedEnv)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });

  const auto = { sttProvider: 'auto', sttModel: '' };

  test('auto uses the Gemini key saved in the app when no OpenAI key exists', () => {
    setProviderSecret(userId, 'google', 'app-gemini-key');
    const target = resolveSttTarget(userId, null, auto);
    assert.equal(target.provider, 'gemini');
    assert.equal(target.apiKey, 'app-gemini-key');
    assert.equal(target.model, '');
  });

  test('auto prefers OpenAI when its key is configured', () => {
    process.env.OPENAI_API_KEY = 'env-openai-key';
    process.env.GOOGLE_AI_KEY = 'env-gemini-key';
    assert.equal(resolveSttTarget(userId, null, auto).provider, 'openai');
  });

  test('an explicit provider is kept and gets its key from the app settings', () => {
    process.env.OPENAI_API_KEY = 'env-openai-key';
    setProviderSecret(userId, 'google', 'app-gemini-key');
    const target = resolveSttTarget(userId, null, { sttProvider: 'gemini', sttModel: 'gemini-x' });
    assert.equal(target.provider, 'gemini');
    assert.equal(target.model, 'gemini-x');
    assert.equal(target.apiKey, 'app-gemini-key');
  });

  test('auto without any key names the providers it tried', () => {
    assert.throws(() => resolveSttTarget(userId, null, auto), /No speech-to-text provider has an API key/);
  });
});

test('seeded OpenAI speech-to-text defaults migrate to auto once', () => {
  const db = new Sqlite(':memory:');
  db.exec(`
    CREATE TABLE user_settings (user_id INTEGER, key TEXT, value TEXT, UNIQUE(user_id, key));
    CREATE TABLE agent_settings (user_id INTEGER, agent_id TEXT, key TEXT, value TEXT, UNIQUE(user_id, agent_id, key));
  `);
  const insert = db.prepare('INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)');
  insert.run(1, 'seeded', 'voice_stt_provider', '"openai"');
  insert.run(1, 'seeded', 'voice_stt_model', '"gpt-live-transcribe"');
  insert.run(1, 'chosen', 'voice_stt_provider', '"openai"');
  insert.run(1, 'chosen', 'voice_stt_model', '"gpt-transcribe"');
  insert.run(1, 'gemini', 'voice_stt_provider', '"gemini"');
  insert.run(1, 'gemini', 'voice_stt_model', '"gemini-3-flash-preview"');

  const { migrateSeededSttDefaultsToAuto } = require('../../../lib/schema_migrations');
  migrateSeededSttDefaultsToAuto(db);
  migrateSeededSttDefaultsToAuto(db);

  const read = (agentId, key) => db.prepare(
    'SELECT value FROM agent_settings WHERE agent_id = ? AND key = ?',
  ).get(agentId, key).value;
  assert.equal(read('seeded', 'voice_stt_provider'), '"auto"');
  assert.equal(read('seeded', 'voice_stt_model'), '""');
  assert.equal(read('chosen', 'voice_stt_provider'), '"openai"');
  assert.equal(read('chosen', 'voice_stt_model'), '"gpt-transcribe"');
  assert.equal(read('gemini', 'voice_stt_provider'), '"gemini"');
  db.close();
});
