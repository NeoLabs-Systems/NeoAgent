'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { spawn, spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');
const { createServiceLogger } = require('../../utils/logger');
const { GUEST_HOME } = require('./guest_paths');
const { guestPayloadDigest, normalizeRuntimeProfile, stageGuestPayload } = require('./guest_bootstrap');

const logger = createServiceLogger('GuestImage');
const BUILD_ROOT = path.join(DATA_DIR, 'runtime-containers', 'guest-image');
// Slim official Node base. Playwright's Chromium and its OS packages are added at
// build time so the image is self-contained and the browser revision always
// matches the pinned dependency.
const BASE_IMAGE = String(process.env.NEOAGENT_GUEST_BASE_IMAGE || 'node:22-bookworm-slim').trim();
const IMAGE_REPO = 'neoagent-guest-agent';
const BUILD_TIMEOUT_MS = Number(process.env.NEOAGENT_GUEST_IMAGE_BUILD_TIMEOUT_MS || 20 * 60 * 1000);
// The browser controller waits for this marker before launching Chromium. The
// QEMU guest writes it once cloud-init has installed the browser; here Chromium
// is baked into the image, so the marker is created at build time.
const BROWSER_READY_MARKER = '/var/lib/neoagent/browser-runtime-ready';

function docker(args, options = {}) {
  return spawnSync('docker', args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: options.timeout || 30000,
    ...options,
  });
}

function dockerOutput(args, options = {}) {
  const result = docker(args, options);
  if (result.error) throw new Error(`Docker is unavailable: ${result.error.message}`);
  if (result.status !== 0) {
    const detail = String(result.stderr || result.stdout || '').trim();
    throw new Error(`docker ${args[0]} failed: ${detail || `exit ${result.status}`}`);
  }
  return String(result.stdout || '').trim();
}

function dockerAvailable() {
  const result = docker(['info', '--format', '{{.ServerVersion}}'], { timeout: 5000 });
  return !result.error && result.status === 0;
}

// Container lifecycle commands wait on a daemon and on the guest's own shutdown,
// so they never run through the synchronous helper above.
function runDockerCommand(args, timeoutMs, stdio = ['ignore', 'inherit', 'inherit']) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', args, { stdio, windowsHide: true });
    let settled = false;
    const finish = (error, status = null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (error) reject(error);
      else resolve(status);
    };
    const timer = setTimeout(() => {
      const error = new Error(`docker ${args[0]} timed out after ${timeoutMs}ms`);
      error.code = 'DOCKER_COMMAND_TIMEOUT';
      try { child.kill('SIGKILL'); } catch {}
      finish(error);
    }, timeoutMs);
    timer.unref?.();
    child.once('error', (error) => finish(error));
    child.once('close', (status) => finish(null, status));
  });
}

// The build context is the staged guest payload (package.json + runtime/ + server/),
// the same file set the QEMU guest receives. Dependencies and the browser are
// installed once, at build time, so a container start never installs anything.
function dockerfileFor(profile) {
  const includeBrowser = ['browser', 'browser_cli'].includes(profile);
  return [
    `FROM ${BASE_IMAGE}`,
    'ENV NODE_ENV=production',
    `ENV NEOAGENT_GUEST_PROFILE=${profile}`,
    `ENV HOME=${GUEST_HOME}`,
    ...(includeBrowser ? ['ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright'] : []),
    'WORKDIR /opt/neoagent',
    'COPY package.json ./',
    includeBrowser
      ? 'RUN npm install --omit=dev --ignore-scripts --no-audit --no-fund'
        + ' && npx playwright install --with-deps chromium'
        + ' && npm cache clean --force'
      : 'RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force',
    'COPY runtime ./runtime',
    'COPY server ./server',
    // The guest agent runs as the host uid:gid on Linux so files it writes into the
    // home volume stay readable by the server process, so its home and any baked
    // runtime state must be writable by an arbitrary uid.
    `RUN mkdir -p ${GUEST_HOME}/workspace && chmod -R 0777 ${GUEST_HOME}`,
    ...(includeBrowser
      ? [
        'RUN chmod -R a+rX /ms-playwright',
        `RUN mkdir -p ${path.posix.dirname(BROWSER_READY_MARKER)} && touch ${BROWSER_READY_MARKER}`,
      ]
      : []),
    'CMD ["node", "server/guest_agent.js"]',
    '',
  ].join('\n');
}

// Builds and caches the per-profile guest-agent image. The tag is content
// addressed over the staged payload and the Dockerfile, so any change to the
// guest source, its dependencies, or the base image produces a new tag and a
// rebuild, while an unchanged tag reuses the cached image.
class GuestImageBuilder {
  #buildPromise = null;
  #cachedTag = null;

  constructor(options = {}) {
    this.profile = normalizeRuntimeProfile(options.runtimeProfile || 'browser_cli');
    this.contextDir = path.join(BUILD_ROOT, this.profile);
  }

  tag() {
    const digest = crypto.createHash('sha256')
      .update(guestPayloadDigest(this.profile))
      .update(dockerfileFor(this.profile))
      .digest('hex')
      .slice(0, 12);
    this.#cachedTag = `${IMAGE_REPO}:${this.profile}-${digest}`;
    return this.#cachedTag;
  }

  #prepareContext() {
    const dockerfile = dockerfileFor(this.profile);
    stageGuestPayload(this.contextDir, this.profile);
    fs.writeFileSync(path.join(this.contextDir, 'Dockerfile'), dockerfile);
    fs.writeFileSync(path.join(this.contextDir, '.dockerignore'), 'node_modules\n');
  }

  imageExists(tag) {
    const result = docker(['image', 'inspect', tag], { timeout: 10000 });
    return !result.error && result.status === 0;
  }

  // A side-effect-free snapshot for readiness polling: it never triggers a build.
  getState() {
    if (!dockerAvailable()) {
      return { dockerAvailable: false, imageBuilt: false, image: this.#cachedTag };
    }
    try {
      const tag = this.tag();
      return { dockerAvailable: true, imageBuilt: this.imageExists(tag), image: tag };
    } catch (error) {
      logger.warn(`Could not resolve the ${this.profile} guest image tag: ${error.message}`);
      return { dockerAvailable: true, imageBuilt: false, image: null };
    }
  }

  // Ensure the image exists, building it when it does not. Concurrent callers
  // share one in-flight build. Returns the resolved image tag.
  async ensure() {
    const tag = this.tag();
    if (this.imageExists(tag)) return tag;
    if (this.#buildPromise) return this.#buildPromise;
    this.#buildPromise = this.#build(tag).finally(() => { this.#buildPromise = null; });
    return this.#buildPromise;
  }

  async #build(tag) {
    logger.info(`Building ${tag} (one-time; installs guest dependencies${this.profile.includes('browser') ? ' and Chromium' : ''}).`);
    const startedAt = Date.now();
    this.#prepareContext();
    const status = await runDockerCommand(['build', '-t', tag, this.contextDir], BUILD_TIMEOUT_MS);
    if (status !== 0) {
      throw new Error(`Guest image build failed (docker build exited ${status}).`);
    }
    logger.info(`Built ${tag} in ${Math.round((Date.now() - startedAt) / 1000)}s.`);
    return tag;
  }
}

module.exports = {
  BASE_IMAGE,
  GuestImageBuilder,
  IMAGE_REPO,
  docker,
  dockerAvailable,
  dockerOutput,
  dockerfileFor,
  runDockerCommand,
};
