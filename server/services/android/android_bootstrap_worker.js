'use strict';

const { AndroidController } = require('./controller');

function parseBoolean(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}

async function main() {
  const controller = new AndroidController({
    userId: process.env.NEOAGENT_ANDROID_BOOTSTRAP_USER_ID || null,
    runtimeBackend: 'host',
    manageProcessCleanup: false,
  });
  const headless = parseBoolean(process.env.NEOAGENT_ANDROID_BOOTSTRAP_HEADLESS);
  const timeoutMs = Math.max(120000, Number(process.env.NEOAGENT_ANDROID_BOOTSTRAP_TIMEOUT_MS) || 600000);

  try {
    await controller.bootstrapEmulator({ headless, timeoutMs });
  } catch (error) {
    try {
      await controller.markBootstrapFailure(error);
    } catch (markError) {
      try {
        console.error('[Android] Failed to record bootstrap failure:', markError?.message || markError);
      } catch {}
    }
    try {
      console.error('[Android] Bootstrap worker failed:', error?.message || error);
    } catch {}
    process.exit(1);
  }
}

process.on('unhandledRejection', (error) => {
  try {
    console.error('[Android] UnhandledRejection in bootstrap worker:', error?.message || error);
  } catch {}
  process.exit(1);
});

main().catch((error) => {
  try {
    console.error('[Android] Bootstrap worker crashed:', error?.message || error);
  } catch {}
  process.exit(1);
});
