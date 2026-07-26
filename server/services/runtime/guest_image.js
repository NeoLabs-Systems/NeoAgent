'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn, spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');
const { stageGuestPayload, normalizeRuntimeProfile } = require('./guest_bootstrap');

// Where build contexts are staged. One directory per profile.
const BUILD_ROOT = path.join(DATA_DIR, 'runtime-vms', 'guest-image');
// Slim official Node base — Playwright browsers + OS deps are added at build time
// via `playwright install --with-deps`, so the image is self-contained and the
// browser version always matches the pinned `playwright-chromium` dependency.
const BASE_IMAGE = String(process.env.NEOAGENT_GUEST_BASE_IMAGE || 'node:20-bookworm-slim').trim();
const IMAGE_REPO = 'neoagent-guest-agent';
const BUILD_TIMEOUT_MS = Number(process.env.NEOAGENT_GUEST_IMAGE_BUILD_TIMEOUT_MS || 20 * 60 * 1000);

// The build context is the staged guest payload (package.json + runtime/ + server/).
// Dependencies and browsers are installed once, at image build time — never per
// container start. Copy package.json first so the dependency layer stays cached
// across source-only changes.
function dockerfileFor(profile) {
  const normalizedProfile = normalizeRuntimeProfile(profile);
  if (normalizedProfile === 'android' || normalizedProfile === 'cli') {
    return [
      `FROM ${BASE_IMAGE}`,
      'ENV NODE_ENV=production',
      `ENV NEOAGENT_GUEST_PROFILE=${normalizedProfile}`,
      'WORKDIR /opt/neoagent',
      'COPY package.json ./',
      'RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force',
      'COPY runtime ./runtime',
      'COPY server ./server',
      // World-writable runtime dir so the agent works whether the container runs
      // as root (macOS) or as the host uid:gid (Linux, for shared file ownership).
      'RUN mkdir -p /opt/neoagent/.runtime && chmod -R 0777 /opt/neoagent/.runtime',
      'CMD ["node", "server/guest_agent.js"]',
      '',
    ].join('\n');
  }
  return [
    `FROM ${BASE_IMAGE}`,
    'ENV NODE_ENV=production',
    'ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright',
    `ENV NEOAGENT_GUEST_PROFILE=${normalizedProfile}`,
    'WORKDIR /opt/neoagent',
    'COPY package.json ./',
    // Install deps without running package postinstall scripts, then fetch the
    // matching Chromium and its OS dependencies explicitly. This mirrors the
    // proven QEMU guest bootstrap and keeps the browser revision deterministic.
    'RUN npm install --omit=dev --ignore-scripts --no-audit --no-fund \\',
    ' && npx playwright install --with-deps chromium \\',
    ' && npm cache clean --force',
    'COPY runtime ./runtime',
    'COPY server ./server',
    // World-writable runtime dir + browser cache so the agent works whether the
    // container runs as root (macOS) or as the host uid:gid (Linux, for shared
    // file ownership). Chromium needs PLAYWRIGHT_BROWSERS_PATH readable by all.
    'RUN mkdir -p /opt/neoagent/.runtime && chmod -R 0777 /opt/neoagent/.runtime && chmod -R a+rX /ms-playwright',
    // Chromium is baked in at build time, so the runtime-ready marker the browser
    // controller polls for (BROWSER_READY_MARKER in server/services/browser/controller.js)
    // is already satisfied. Create it here so ensureBrowser() launches immediately
    // instead of waiting out its full 10-minute timeout for a marker that only the
    // legacy QEMU per-boot bootstrap ever writes.
    'RUN mkdir -p /var/lib/neoagent && touch /var/lib/neoagent/browser-runtime-ready',
    'CMD ["node", "server/guest_agent.js"]',
    '',
  ].join('\n');
}

// Stable content hash over every staged file plus the Dockerfile, so the image
// tag changes whenever the guest source, its dependencies, or the base image
// change. A new tag forces a rebuild; an unchanged tag reuses the cached image.
function hashBuildContext(contextDir, dockerfile) {
  const hash = crypto.createHash('sha256');
  hash.update(dockerfile);
  const walk = (dir) => {
    for (const name of fs.readdirSync(dir).sort()) {
      const full = path.join(dir, name);
      const stat = fs.statSync(full);
      if (stat.isDirectory()) {
        walk(full);
      } else {
        hash.update(path.relative(contextDir, full));
        hash.update(fs.readFileSync(full));
      }
    }
  };
  walk(contextDir);
  return hash.digest('hex').slice(0, 12);
}

function docker(args, opts = {}) {
  return spawnSync('docker', args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: opts.timeout || 30000,
    ...opts,
  });
}

function dockerAvailable() {
  const result = docker(['info'], { timeout: 5000 });
  return !result.error && result.status === 0;
}

function runDockerCommand(args, options = {}) {
  const timeoutMs = Number(options.timeout || BUILD_TIMEOUT_MS);
  const spawnImpl = options.spawnImpl || spawn;
  return new Promise((resolve, reject) => {
    const child = spawnImpl('docker', args, {
      stdio: options.stdio || ['ignore', 'inherit', 'inherit'],
      windowsHide: true,
    });
    let settled = false;
    const finish = (error, status = null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (error) reject(error);
      else resolve(status);
    };
    const timeout = setTimeout(() => {
      const error = new Error(`docker ${args[0]} timed out after ${timeoutMs}ms`);
      error.code = 'DOCKER_COMMAND_TIMEOUT';
      try { child.kill('SIGKILL'); } catch {}
      finish(error);
    }, timeoutMs);
    timeout.unref?.();
    child.once('error', (error) => finish(error));
    child.once('close', (status) => finish(null, status));
  });
}

// Builds and caches the per-profile guest-agent Docker image. The image bakes in
// the guest agent, its dependencies, and (for browser_cli) the Chromium browser,
// so containers start the agent directly with no runtime installation step.
class GuestImageBuilder {
  #buildPromise = null;
  #cachedTag = null;
  #cachedBuiltAt = 0;

  constructor(options = {}) {
    this.profile = normalizeRuntimeProfile(options.runtimeProfile || 'browser_cli');
    this.contextDir = path.join(BUILD_ROOT, this.profile);
  }

  // Stage the build context on disk and return its content-addressed image tag.
  prepareContext() {
    const dockerfile = dockerfileFor(this.profile);
    stageGuestPayload(this.contextDir, this.profile);
    fs.writeFileSync(path.join(this.contextDir, 'Dockerfile'), dockerfile);
    fs.writeFileSync(path.join(this.contextDir, '.dockerignore'), 'node_modules\n');
    const tag = `${IMAGE_REPO}:${this.profile}-${hashBuildContext(this.contextDir, dockerfile)}`;
    this.#cachedTag = tag;
    return tag;
  }

  imageExists(tag) {
    const result = docker(['image', 'inspect', tag], { timeout: 10000 });
    return !result.error && result.status === 0;
  }

  // Returns { dockerAvailable, imageBuilt, image } without triggering a build.
  // Cheap enough to call from readiness polling (only stages the context once).
  getState() {
    if (!dockerAvailable()) {
      return { dockerAvailable: false, imageBuilt: false, image: this.#cachedTag };
    }
    let tag = this.#cachedTag;
    try {
      if (!tag) tag = this.prepareContext();
    } catch (err) {
      console.warn(`[GuestImage:${this.profile}] Failed to stage build context: ${err.message}`);
      return { dockerAvailable: true, imageBuilt: false, image: null };
    }
    return { dockerAvailable: true, imageBuilt: this.imageExists(tag), image: tag };
  }

  // Ensure the image exists, building it if necessary. Concurrent callers share
  // the same in-flight build. Returns the resolved image tag.
  async ensure() {
    const tag = this.prepareContext();
    if (this.imageExists(tag)) {
      this.#cachedBuiltAt = Date.now();
      return tag;
    }
    if (this.#buildPromise) return this.#buildPromise;
    this.#buildPromise = this.#build(tag).finally(() => { this.#buildPromise = null; });
    return this.#buildPromise;
  }

  async #build(tag) {
    console.log(`[GuestImage:${this.profile}] Building guest image ${tag} (one-time; downloads browser + deps)…`);
    const started = Date.now();
    let status;
    try {
      status = await runDockerCommand(['build', '-t', tag, this.contextDir], {
        timeout: BUILD_TIMEOUT_MS,
      });
    } catch (error) {
      throw new Error(`Guest image build failed: ${error.message}`, { cause: error });
    }
    if (status !== 0) {
      throw new Error(`Guest image build for ${tag} exited with status ${status}`);
    }
    this.#cachedBuiltAt = Date.now();
    console.log(`[GuestImage:${this.profile}] Built ${tag} in ${Math.round((Date.now() - started) / 1000)}s`);
    return tag;
  }
}

module.exports = {
  GuestImageBuilder,
  dockerAvailable,
  runDockerCommand,
  BASE_IMAGE,
};
