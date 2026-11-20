'use strict';

const os = require('node:os');
const { analyticsConfig } = require('./analytics-config');
const { version } = require('../package.json');

const INTERVAL_MS = 60 * 60 * 1000;
const GIB = 1024 ** 3;

// Bucket machine capacities so reports do not contain exact hardware sizes.
function powerOfTwoBucket(value) {
  if (!Number.isFinite(value) || value <= 0) return 'unknown';
  const upper = 2 ** Math.ceil(Math.log2(value));
  return `${upper / 2}-${upper}`;
}

function hostSnapshot() {
  const cores = typeof os.availableParallelism === 'function' ? os.availableParallelism() : os.cpus().length;
  const memory = os.totalmem();
  const load = os.loadavg()[0];
  return {
    app_version: version,
    node_major: Number(process.versions.node.split('.')[0]),
    os: os.platform(),
    architecture: os.arch(),
    cpu_cores_range: powerOfTwoBucket(cores),
    ram_gib_range: powerOfTwoBucket(memory / GIB),
    memory_used_percent_band: Math.min(100, Math.max(0, Math.round((1 - os.freemem() / memory) * 10) * 10)),
    process_rss_mib_range: powerOfTwoBucket(process.memoryUsage().rss / (1024 ** 2)),
    uptime_hours_range: powerOfTwoBucket(process.uptime() / 3600),
    ...(os.platform() !== 'win32' && Number.isFinite(load) && cores > 0
      ? { load_per_core_percent_band: Math.min(200, Math.max(0, Math.round(load / cores * 10) * 10)) }
      : {}),
  };
}

async function reportHost(fetchImpl = globalThis.fetch) {
  const config = analyticsConfig();
  if (!config) return;
  try {
    // A stream label satisfies Countly's protocol without identifying an installation.
    const body = new URLSearchParams({
      app_key: config.appKey,
      device_id: 'aggregate-server',
      events: JSON.stringify([{ key: 'host-snapshot', count: 1, segmentation: hostSnapshot() }]),
    });
    await fetchImpl(config.endpoint, {
      method: 'POST',
      body,
      redirect: 'error',
      signal: AbortSignal.timeout(5000),
    });
  } catch (_) {
    // Analytics must not affect startup or application availability.
  }
}

function startHostAnalytics(server) {
  if (!analyticsConfig()) return;
  void reportHost();
  const timer = setInterval(() => { void reportHost(); }, INTERVAL_MS);
  timer.unref();
  server.once('close', () => clearInterval(timer));
}

module.exports = { hostSnapshot, reportHost, startHostAnalytics };
