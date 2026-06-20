'use strict';

const dotenv = require('dotenv');
const {
  ENV_FILE,
  LEGACY_ENV_FILE,
  ensureRuntimeDirs,
  migrateLegacyRuntime,
} = require('../runtime/paths');

let loaded = false;

function loadBenchmarkEnv() {
  if (loaded) return;
  migrateLegacyRuntime();
  ensureRuntimeDirs();
  dotenv.config({ path: LEGACY_ENV_FILE });
  dotenv.config({ path: ENV_FILE, override: true });
  loaded = true;
}

module.exports = {
  loadBenchmarkEnv,
};
