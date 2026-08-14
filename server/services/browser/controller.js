'use strict';

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { spawn } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');
const { validateCloudUrlWithDns } = require('../../utils/cloud-security');
const { runProcess } = require('../android/process');
const {
  chooseBrowserIdentity,
  detectBotChallenge,
  generateHumanMousePath,
  normalizeChallengeRetry,
  normalizeReferrerMode,
  rand,
} = require('./anti_detection');

const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
const BROWSER_PROFILE_ROOT = path.join(DATA_DIR, 'browser-profiles');
if (!fs.existsSync(BROWSER_PROFILE_ROOT)) fs.mkdirSync(BROWSER_PROFILE_ROOT, { recursive: true });
const BROWSER_READY_MARKER = '/var/lib/neoagent/browser-runtime-ready';

// Injected into every page in the cloud VM browser context to deny local device access.
const DEVICE_DENY_SCRIPT = `(() => {
  const denied = () => Promise.reject(Object.assign(
    new DOMException('Permission denied', 'NotAllowedError'),
    { name: 'NotAllowedError' }
  ));

  // Camera and microphone
  if (navigator.mediaDevices) {
    navigator.mediaDevices.getUserMedia = denied;
    navigator.mediaDevices.getDisplayMedia = denied;
  }

  // Geolocation
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition = function(_success, error) {
      if (error) error({ code: 1, message: 'User denied Geolocation' });
    };
    navigator.geolocation.watchPosition = function(_success, error) {
      if (error) error({ code: 1, message: 'User denied Geolocation' });
      return 0;
    };
    navigator.geolocation.clearWatch = function() {};
  }

  // Bluetooth
  if (navigator.bluetooth) {
    navigator.bluetooth.requestDevice = denied;
    navigator.bluetooth.getAvailability = () => Promise.resolve(false);
  }

  // USB
  if (navigator.usb) {
    navigator.usb.requestDevice = denied;
    navigator.usb.getDevices = () => Promise.resolve([]);
  }

  // Web Serial
  if (navigator.serial) {
    navigator.serial.requestPort = denied;
    navigator.serial.getPorts = () => Promise.resolve([]);
  }

  // Permissions API: report all device permissions as denied
  const _origQuery = navigator.permissions?.query?.bind(navigator.permissions);
  if (_origQuery) {
    const DEVICE_PERMISSIONS = new Set([
      'camera', 'microphone', 'geolocation', 'bluetooth', 'usb',
    ]);
    navigator.permissions.query = (desc) => {
      if (DEVICE_PERMISSIONS.has(desc && desc.name)) {
        return Promise.resolve({ state: 'denied', onchange: null });
      }
      return _origQuery(desc);
    };
  }
})();`;

function resolveBrowserExecutablePath() {
  const explicitPath =
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ||
    process.env.PUPPETEER_EXECUTABLE_PATH ||
    process.env.CHROME_BIN ||
    process.env.CHROMIUM_BIN;

  if (explicitPath && fs.existsSync(explicitPath)) return explicitPath;

  const bundledCandidates = [
    () => require('playwright-chromium').chromium.executablePath(),
  ];
  for (const resolveBundled of bundledCandidates) {
    try {
      const bundledPath = resolveBundled();
      if (bundledPath && fs.existsSync(bundledPath)) {
        if (process.platform === 'linux') {
          const wrappedPath = path.join(path.dirname(bundledPath), 'chrome-wrapper');
          if (fs.existsSync(wrappedPath)) {
            return wrappedPath;
          }
        }
        return bundledPath;
      }
    } catch {}
  }

  const platformCandidates = process.platform === 'darwin'
    ? [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      ]
    : process.platform === 'win32'
      ? [
          'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
          'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
          'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
          'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
        ]
      : [
          '/usr/bin/google-chrome',
          '/usr/bin/google-chrome-stable',
          '/usr/bin/chromium',
          '/usr/bin/chromium-browser',
          '/snap/bin/chromium',
          '/usr/bin/microsoft-edge',
        ];

  return platformCandidates.find((candidate) => fs.existsSync(candidate)) || null;
}

async function installPlaywrightBrowserBinary(browserName, options = {}) {
  const packageRoot = path.dirname(require.resolve('playwright-chromium/package.json'));
  const cliPath = path.join(packageRoot, 'cli.js');
  await runProcess(process.execPath, [cliPath, 'install', '--no-shell', browserName], {
    signal: options.signal,
    timeoutMs: 10 * 60 * 1000,
    maxOutputBytes: 32 * 1024 * 1024,
  });
}

function createAbortError(signal, fallback = 'Browser operation aborted.') {
  if (signal?.reason instanceof Error) return signal.reason;
  const error = new Error(String(signal?.reason || fallback));
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

function throwIfAborted(signal) {
  if (signal?.aborted) throw createAbortError(signal);
}

function sleep(ms, signal = null) {
  throwIfAborted(signal);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(timer);
      reject(createAbortError(signal));
    };
    signal?.addEventListener('abort', onAbort, { once: true });
    if (signal?.aborted) onAbort();
  });
}

function isAbortError(error, signal = null) {
  return Boolean(
    signal?.aborted
    || error?.name === 'AbortError'
    || error?.code === 'ABORT_ERR',
  );
}

async function raceWithSignal(promise, signal) {
  throwIfAborted(signal);
  if (!signal) return promise;
  let onAbort;
  const aborted = new Promise((_, reject) => {
    onAbort = () => reject(createAbortError(signal));
    signal.addEventListener('abort', onAbort, { once: true });
    if (signal.aborted) onAbort();
  });
  try {
    return await Promise.race([promise, aborted]);
  } finally {
    signal.removeEventListener('abort', onAbort);
  }
}

async function waitForFile(filePath, options = {}) {
  const timeoutMs = Math.max(0, Number(options.timeoutMs || 0));
  const intervalMs = Math.max(100, Number(options.intervalMs || 500));
  if (!filePath || timeoutMs <= 0 || fs.existsSync(filePath)) {
    return fs.existsSync(filePath);
  }
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    await sleep(intervalMs, options.signal);
    if (fs.existsSync(filePath)) {
      return true;
    }
  }
  return fs.existsSync(filePath);
}

function buildIsolatedEvaluationExpression(script) {
  const source = String(script || 'undefined');
  // Evaluate each snippet inside a fresh function scope so repeated calls do not
  // leak top-level const/let bindings into later browser_evaluate steps.
  return `(() => eval(${JSON.stringify(source)}))()`;
}

function normalizeWaitUntil(waitUntil) {
  const value = String(waitUntil || '').trim().toLowerCase();
  if (value === 'networkidle0' || value === 'networkidle2') {
    return 'networkidle';
  }
  if (value === 'load' || value === 'domcontentloaded' || value === 'networkidle' || value === 'commit') {
    return value;
  }
  return 'domcontentloaded';
}

function normalizePointCoordinate(value, label) {
  if (value == null || value === '') {
    throw new Error(`${label} coordinate is required.`);
  }
  const normalized = Number(value);
  if (!Number.isFinite(normalized)) {
    throw new Error(`${label} coordinate must be a finite number.`);
  }
  return Math.round(normalized);
}

function clearChromiumSingletonLocks(profileDir) {
  const lockEntries = [
    'SingletonLock',
    'SingletonSocket',
    'SingletonCookie',
    'SingletonStartupLock',
    'DevToolsActivePort',
  ];
  for (const entry of lockEntries) {
    const targetPath = path.join(profileDir, entry);
    try {
      fs.rmSync(targetPath, { force: true, recursive: true });
    } catch {}
  }
}

function chooseVirtualDisplay() {
  for (let number = 90; number < 200; number += 1) {
    if (
      !fs.existsSync(`/tmp/.X11-unix/X${number}`)
      && !fs.existsSync(`/tmp/.X${number}-lock`)
    ) {
      return `:${number}`;
    }
  }
  throw new Error('No free X11 display is available for the browser.');
}

class BrowserController {
  constructor(options = {}) {
    this.io = options.io || null;
    this.userId = options.userId != null ? String(options.userId) : null;
    this.artifactStore = options.artifactStore || null;
    this.runtimeBackend = options.runtimeBackend || 'host';
    this.providerType = 'vm';
    this.engine = 'chromium';
    this.browser = null;
    this.context = null;
    this.page = null;
    this.displayProcess = null;
    this.displayValue = process.env.DISPLAY || null;
    this._managedDisplayValue = null;
    this.launching = false;
    this.launchPromise = null;
    this.browserBinaryInstallPromise = null;
    this._launchAbortController = null;
    this._urlValidator = options.urlValidator || validateCloudUrlWithDns;
    this._boundPages = new WeakSet();
    this._closing = false;
    this._closePromise = null;
    this._protectedCredentialFill = null;
    this.headless = false;
    this.profileDir = path.join(BROWSER_PROFILE_ROOT, this.userId || 'default');
    if (!fs.existsSync(this.profileDir)) fs.mkdirSync(this.profileDir, { recursive: true });
    this._identity = chooseBrowserIdentity(this.userId || this.profileDir);
    this._viewport = this._identity.viewport;
    this._userAgent = this._identity.userAgent;
    this._mousePosition = {
      x: Math.round(this._viewport.width / 2),
      y: Math.round(this._viewport.height / 2),
    };
  }

  async setHeadless(val) {
    void val;
    // Browser sessions inside the VM always run headed.
    this.headless = false;
  }

  async closeBrowser() {
    return this.close();
  }

  _contextIsOpen() {
    if (!this.context) return false;
    if (typeof this.context.isClosed === 'function' && this.context.isClosed()) return false;
    return !this.browser
      || typeof this.browser.isConnected !== 'function'
      || this.browser.isConnected();
  }

  _clearBrowserReferences(context, browser) {
    if (context && this.context !== context) return;
    if (!context && browser && this.browser !== browser) return;
    this.context = null;
    this.browser = null;
    this.page = null;
  }

  _bindPage(page, options = {}) {
    if (!page) return;
    if (!this._boundPages.has(page)) {
      this._boundPages.add(page);
      const clearPage = () => {
        if (this.page === page) this.page = null;
      };
      page.on?.('close', clearPage);
      page.on?.('crash', clearPage);
    }
    if (options.makeActive !== false) this.page = page;
  }

  _bindContextLifecycle(context, browser) {
    context.on?.('close', () => this._clearBrowserReferences(context, browser));
    context.on?.('page', (page) => {
      this._bindPage(page);
      this._applyStealthToPage(page).catch(() => {});
    });
    browser?.on?.('disconnected', () => this._clearBrowserReferences(context, browser));
    for (const page of context.pages?.() || []) this._bindPage(page, { makeActive: false });
  }

  async _networkUrlAllowed(url) {
    let parsed;
    try {
      parsed = new URL(String(url || ''));
    } catch {
      return false;
    }
    const protocol = parsed.protocol.toLowerCase();
    if (protocol === 'about:' && parsed.href === 'about:blank') return true;
    if (protocol === 'blob:' || protocol === 'data:') return true;
    if (protocol === 'ws:' || protocol === 'wss:') {
      parsed.protocol = protocol === 'ws:' ? 'http:' : 'https:';
    } else if (protocol !== 'http:' && protocol !== 'https:') {
      return false;
    }
    const result = await this._urlValidator(parsed.href);
    return result?.allowed === true;
  }

  async _assertNavigationAllowed(url, options = {}) {
    let result = null;
    try {
      result = await this._urlValidator(String(url || ''), { signal: options.signal });
    } catch (error) {
      if (isAbortError(error, options.signal)) throw error;
    }
    if (result?.allowed !== true) {
      const error = new Error('This URL is not permitted.');
      error.code = 'URL_BLOCKED';
      throw error;
    }
  }

  async _installNetworkGuard(context) {
    await context.route('**/*', async (route) => {
      let allowed = false;
      try {
        allowed = await this._networkUrlAllowed(route.request().url());
      } catch {}
      if (!allowed) {
        await route.abort('blockedbyclient').catch(() => {});
        return;
      }
      await route.continue().catch(() => {});
    });

    if (typeof context.routeWebSocket === 'function') {
      await context.routeWebSocket('**', async (webSocket) => {
        let allowed = false;
        try {
          allowed = await this._networkUrlAllowed(webSocket.url());
        } catch {}
        if (!allowed) {
          await webSocket.close({ code: 1008, reason: 'Blocked by network policy' }).catch(() => {});
          return;
        }
        webSocket.connectToServer();
      });
    }
  }

  async _withPageCancellation(page, signal, operation) {
    throwIfAborted(signal);
    if (!signal) return operation();
    const closeOnAbort = () => {
      if (!page?.isClosed?.()) {
        page.close({ runBeforeUnload: false, reason: 'Browser operation cancelled' }).catch(() => {});
      }
    };
    signal.addEventListener('abort', closeOnAbort, { once: true });
    try {
      return await raceWithSignal(Promise.resolve().then(operation), signal);
    } finally {
      signal.removeEventListener('abort', closeOnAbort);
    }
  }

  async _applyStealthToPage(page) {
    const ua = this._userAgent;
    const vp = this._viewport;
    const identity = this._identity || chooseBrowserIdentity(this.userId || this.profileDir);

    if (typeof page.setUserAgent === 'function') {
      await page.setUserAgent(ua);
    }
    if (typeof page.setViewport === 'function') {
      await page.setViewport(vp);
    }
    if (typeof page.setExtraHTTPHeaders === 'function') {
      await page.setExtraHTTPHeaders({
        'Accept-Language': 'en-US,en;q=0.9',
      });
    }

    // Inject fingerprint overrides before any page script runs
    const script = `
      (() => {
        // Remove webdriver flag
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });

        // Realistic language/platform
        Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
        Object.defineProperty(navigator, 'platform', { get: () => ${JSON.stringify(identity.platform)} });
        Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => ${Number(identity.hardwareConcurrency) || 8} });
        Object.defineProperty(navigator, 'deviceMemory', { get: () => ${Number(identity.deviceMemory) || 8} });

        // Make it look like a real Chrome install
        window.chrome = {
          app: { isInstalled: false, InstallState: {}, RunningState: {} },
          runtime: {},
          loadTimes: function() {},
          csi: function() {},
        };

        // Permissions API — bots often show "denied" for notifications
        const origQuery = window.navigator.permissions?.query?.bind(navigator.permissions);
        if (origQuery) {
          navigator.permissions.query = (parameters) =>
            parameters.name === 'notifications'
              ? Promise.resolve({ state: Notification.permission })
              : origQuery(parameters);
        }

        // Hide automation plugins gap
        Object.defineProperty(navigator, 'plugins', {
          get: () => {
            const arr = [
              { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
              { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai', description: '' },
              { name: 'Native Client', filename: 'internal-nacl-plugin', description: '' },
            ];
            arr.item = i => arr[i];
            arr.namedItem = n => arr.find(p => p.name === n) || null;
            arr.refresh = () => {};
            return arr;
          }
        });

        // WebGL Spoofing
        const getParameterProxyHandler = {
          apply: function(target, ctx, args) {
            const param = args[0];
            // UNMASKED_VENDOR_WEBGL
            if (param === 37445) return ${JSON.stringify(identity.webglVendor)};
            // UNMASKED_RENDERER_WEBGL
            if (param === 37446) return ${JSON.stringify(identity.webglRenderer)};
            return Reflect.apply(target, ctx, args);
          }
        };
        const getParam = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = new Proxy(getParam, getParameterProxyHandler);
        if (typeof WebGL2RenderingContext !== 'undefined') {
          const getParam2 = WebGL2RenderingContext.prototype.getParameter;
          WebGL2RenderingContext.prototype.getParameter = new Proxy(getParam2, getParameterProxyHandler);
        }

        // Canvas Spoofing (slight noise)
        const originalFillText = CanvasRenderingContext2D.prototype.fillText;
        CanvasRenderingContext2D.prototype.fillText = function(...args) {
            if (!this._spoofing_applied) {
                this._spoofing_applied = true;
                const r = Math.random() * 0.0001;
                const g = Math.random() * 0.0001;
                const b = Math.random() * 0.0001;
                this.fillStyle = \`rgba(\${Math.floor(r * 255)}, \${Math.floor(g * 255)}, \${Math.floor(b * 255)}, 0.01)\`;
                originalFillText.call(this, "spoof", 0, 0);
            }
            return originalFillText.apply(this, args);
        };

      })();
    `;
    if (typeof page.evaluateOnNewDocument === 'function') {
      await page.evaluateOnNewDocument(script);
    } else if (typeof page.addInitScript === 'function') {
      await page.addInitScript(script);
    }
  }

  async ensureBrowser(options = {}) {
    let signal = options.signal;
    throwIfAborted(signal);
    if (this._closePromise) await raceWithSignal(this._closePromise, signal);
    if (this._contextIsOpen()) return;
    if (this.launchPromise) {
      await raceWithSignal(this.launchPromise, signal);
      return;
    }

    const staleContext = this.context;
    const staleBrowser = this.browser;
    this._clearBrowserReferences(staleContext, staleBrowser);
    if (staleContext) await staleContext.close().catch(() => {});
    else if (staleBrowser) await staleBrowser.close().catch(() => {});

    const launchAbortController = new AbortController();
    this._launchAbortController = launchAbortController;
    const externalSignal = signal;
    const forwardAbort = () => launchAbortController.abort(externalSignal.reason);
    externalSignal?.addEventListener('abort', forwardAbort, { once: true });
    if (externalSignal?.aborted) forwardAbort();
    signal = launchAbortController.signal;

    this.launching = true;
    this.launchPromise = (async () => {
      const runtimeReady = await waitForFile(BROWSER_READY_MARKER, {
        timeoutMs: 10 * 60 * 1000,
        intervalMs: 1000,
        signal,
      });
      if (!runtimeReady) {
        throw new Error('Browser runtime provisioning is still in progress inside the VM. Retry shortly.');
      }
      await this.ensureVirtualDisplay({ signal });
      throwIfAborted(signal);

      this._identity = chooseBrowserIdentity(this.userId || this.profileDir);
      this._userAgent = this._identity.userAgent;
      this._viewport = this._identity.viewport;
      this._mousePosition = {
        x: Math.round(this._viewport.width / 2),
        y: Math.round(this._viewport.height / 2),
      };

      let executablePath = resolveBrowserExecutablePath();
      if (!executablePath) {
        if (!this.browserBinaryInstallPromise) {
          this.browserBinaryInstallPromise = installPlaywrightBrowserBinary(this.engine, { signal });
        }
        try {
          await raceWithSignal(this.browserBinaryInstallPromise, signal);
        } finally {
          this.browserBinaryInstallPromise = null;
        }
        executablePath = resolveBrowserExecutablePath();
      }

      if (!executablePath) {
        throw new Error(`No ${this.engine} executable found for the VM browser runtime.`);
      }

      const launchEnv = {
        ...process.env,
        ...(this.displayValue ? { DISPLAY: this.displayValue } : {}),
      };

      const launchArgs = [
        '--start-maximized',
        '--remote-allow-origins=*',
        '--disable-dev-shm-usage',
        '--no-service-autorun',
        '--disable-crash-reporter',
        '--disable-breakpad',
        '--disable-background-networking',
        '--disable-component-update',
        '--disable-blink-features=AutomationControlled',
        '--disable-infobars',
        '--disable-session-crashed-bubble',
        '--disable-search-engine-choice-screen',
        '--no-first-run',
        '--no-default-browser-check',
        '--homepage=about:blank',
        '--no-pings',
        '--password-store=basic',
        '--disable-gpu',
        '--lang=en-US,en',
        `--user-agent=${this._userAgent}`,
        `--window-size=${this._viewport.width},${this._viewport.height}`,
        // Cloud security: disable hardware device APIs at the Chromium level
        '--disable-features=WebBluetooth,WebUSB,WebSerial,WebOTP,DirectSockets',
        '--disable-usb-keyboard-detect',
      ];

      const playwright = require('playwright-chromium');
      clearChromiumSingletonLocks(this.profileDir);
      const launchPromise = playwright.chromium.launchPersistentContext(this.profileDir, {
        headless: false,
        chromiumSandbox: true,
        executablePath,
        env: launchEnv,
        args: launchArgs,
        viewport: this._viewport,
        userAgent: this._userAgent,
        locale: 'en-US',
        ignoreHTTPSErrors: false,
        serviceWorkers: 'block',
        timeout: 120000,
      });
      let context;
      try {
        context = await raceWithSignal(launchPromise, signal);
      } catch (error) {
        launchPromise.then((lateContext) => lateContext.close().catch(() => {})).catch(() => {});
        throw error;
      }
      const browser = typeof context.browser === 'function' ? context.browser() : null;
      this.context = context;
      this.browser = browser;
      this._bindContextLifecycle(context, browser);

      // Cloud security: deny access to local devices on every page in this context.
      await context.addInitScript(DEVICE_DENY_SCRIPT);
      await this._installNetworkGuard(context);

      this.page = context.pages()[0] || await context.newPage();
      this._bindPage(this.page);
      await this._applyStealthToPage(this.page);
    })();

    try {
      await raceWithSignal(this.launchPromise, signal);
    } catch (error) {
      const failedContext = this.context;
      const failedBrowser = this.browser;
      this._clearBrowserReferences(failedContext, failedBrowser);
      if (failedContext) await failedContext.close().catch(() => {});
      else if (failedBrowser) await failedBrowser.close().catch(() => {});
      await this._stopVirtualDisplay();
      throw error;
    } finally {
      externalSignal?.removeEventListener('abort', forwardAbort);
      if (this._launchAbortController === launchAbortController) {
        this._launchAbortController = null;
      }
      this.launchPromise = null;
      this.launching = false;
    }
  }

  async ensurePage(options = {}) {
    const signal = options.signal;
    await this.ensureBrowser(options);
    throwIfAborted(signal);
    if (!this.page || this.page.isClosed()) {
      let pagePromise;
      if (this.context && typeof this.context.newPage === 'function') {
        pagePromise = this.context.newPage();
      } else {
        pagePromise = this.browser.newPage();
      }
      try {
        this.page = await raceWithSignal(pagePromise, signal);
      } catch (error) {
        pagePromise.then((latePage) => latePage.close().catch(() => {})).catch(() => {});
        throw error;
      }
      this._bindPage(this.page);
      await this._applyStealthToPage(this.page);
    }
    return this.page;
  }

  async takeScreenshot(options = {}) {
    const page = await this.ensurePage(options);
    return this._withPageCancellation(page, options.signal, async () => {
      let artifactRecord = null;
      let filename = `screenshot_${Date.now()}.png`;
      let filepath = path.join(SCREENSHOTS_DIR, filename);
      if (this.artifactStore && this.userId != null) {
        artifactRecord = this.artifactStore.allocateFile(this.userId, {
          kind: 'browser-screenshot',
          backend: this.runtimeBackend,
          extension: 'png',
          contentType: 'image/png',
          filenameBase: 'browser-screenshot',
          metadata: {
            selector: options.selector || null,
            fullPage: options.fullPage === true,
          },
        });
        filepath = artifactRecord.storagePath;
        filename = path.basename(filepath);
      }

      const screenshotOptions = { path: filepath, type: 'png' };
      if (options.fullPage) screenshotOptions.fullPage = true;
      if (options.selector) {
        const element = await page.$(options.selector);
        if (element) {
          await element.screenshot(screenshotOptions);
        } else {
          await page.screenshot(screenshotOptions);
        }
      } else {
        await page.screenshot(screenshotOptions);
      }

      if (artifactRecord) {
        this.artifactStore.finalizeFile(artifactRecord.artifactId, filepath);
      }

      return {
        screenshotPath: artifactRecord ? artifactRecord.url : `/screenshots/${filename}`,
        artifactId: artifactRecord?.artifactId || null,
        filename,
        fullPath: filepath,
      };
    });
  }

  async screenshotJpeg(quality = 80, options = {}) {
    const page = await this.ensurePage(options);
    return this._withPageCancellation(page, options.signal, async () => {
      const screenshotOptions = {
        type: 'jpeg',
        quality: Math.min(95, Math.max(30, Math.floor(Number(quality) || 80))),
        fullPage: options.fullPage === true,
      };
      if (options.selector) {
        const element = await page.$(options.selector);
        if (element) {
          return element.screenshot(screenshotOptions);
        }
      }
      return page.screenshot(screenshotOptions);
    });
  }

  async _navigatePage(page, url, options = {}) {
    const referrerMode = normalizeReferrerMode(options.referrerMode);
    const waitUntil = normalizeWaitUntil(options.waitUntil);
    if (referrerMode === 'current' && page.url() && page.url() !== 'about:blank') {
      const previousUrl = page.url();
      const urlChanged = typeof page.waitForURL === 'function'
        ? page.waitForURL(
            (nextUrl) => String(nextUrl) !== previousUrl,
            { waitUntil, timeout: 30000 },
          )
        : page.waitForFunction(
            (oldUrl) => window.location.href !== oldUrl,
            previousUrl,
            { timeout: 30000 },
          );
      await Promise.all([
        urlChanged,
        page.evaluate((nextUrl) => { window.location.href = nextUrl; }, url),
      ]);
      await page.waitForLoadState(waitUntil, { timeout: 30000 });
      return null;
    }

    const gotoOptions = {
      waitUntil,
      timeout: 30000,
    };
    if (referrerMode === 'google') {
      gotoOptions.referer = 'https://www.google.com/';
    } else if (referrerMode === 'current' && page.url() && page.url() !== 'about:blank') {
      gotoOptions.referer = page.url();
    }
    return page.goto(url, gotoOptions);
  }

  async _getBotDetection(page, rawHtml, pageContent) {
    const title = await page.title().catch(() => '');
    return detectBotChallenge({
      title,
      url: page.url(),
      html: rawHtml,
      pageContent,
    });
  }

  async navigate(url, options = {}) {
    let page = null;
    try {
      await this._assertNavigationAllowed(url, options);
      page = await this.ensurePage(options);
      return await this._withPageCancellation(page, options.signal, async () => {
        const requestedReferrerMode = normalizeReferrerMode(options.referrerMode);
        let activeReferrerMode = requestedReferrerMode;
        let response = await this._navigatePage(page, url, {
          ...options,
          referrerMode: activeReferrerMode,
        });

        if (options.waitFor) {
          await page.waitForSelector(options.waitFor, { timeout: 10000 });
        }

        // Simulate human reading delay.
        await sleep(rand(700, 1800), options.signal);

        let rawHtml = await page.content();
        const { extractForLLM } = require('./contentExtractor');
        let extraction = extractForLLM(rawHtml, { url: page.url() });
        let botDetection = await this._getBotDetection(page, rawHtml, extraction.markdown);
        let challengeRetried = false;

        if (
          botDetection.detected
          && normalizeChallengeRetry(options.challengeRetry)
          && requestedReferrerMode === 'direct'
        ) {
          challengeRetried = true;
          activeReferrerMode = 'google';
          await sleep(rand(1200, 2600), options.signal);
          response = await this._navigatePage(page, url, {
            ...options,
            referrerMode: activeReferrerMode,
          });
          if (options.waitFor) {
            await page.waitForSelector(options.waitFor, { timeout: 10000 });
          }
          await sleep(rand(900, 2200), options.signal);
          rawHtml = await page.content();
          extraction = extractForLLM(rawHtml, { url: page.url() });
          botDetection = await this._getBotDetection(page, rawHtml, extraction.markdown);
        }

        const title = await page.title();
        const currentUrl = page.url();

        let screenshot = null;
        if (options.screenshot !== false) {
          screenshot = await this.takeScreenshot({
            fullPage: options.fullPage,
            signal: options.signal,
          });
        }

        return {
          title,
          url: currentUrl,
          status: response?.status() || 0,
          pageContent: extraction.markdown,
          botDetection,
          referrerMode: activeReferrerMode,
          challengeRetried,
          screenshotPath: screenshot?.screenshotPath || null,
          artifactId: screenshot?.artifactId || null,
          fullPath: screenshot?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      let screenshot = null;
      if (page && !page.isClosed()) {
        try { screenshot = await this.takeScreenshot(); } catch {}
      }
      return {
        error: err.message,
        url,
        botDetection: { detected: false, provider: null },
        screenshotPath: screenshot?.screenshotPath || null,
        artifactId: screenshot?.artifactId || null,
        fullPath: screenshot?.fullPath || null,
      };
    }
  }

  async _moveMouseTo(page, x, y, options = {}) {
    const target = {
      x: Math.max(0, Math.min(this._viewport.width, Math.round(Number(x) || 0))),
      y: Math.max(0, Math.min(this._viewport.height, Math.round(Number(y) || 0))),
    };
    const path = generateHumanMousePath(this._mousePosition, target, this._viewport);
    for (const point of path) {
      await page.mouse.move(point.x, point.y);
      if (!options.fast) {
        await sleep(rand(2, 10), options.signal);
      }
    }
    this._mousePosition = target;
    return target;
  }

  async _pointForElement(element) {
    await element.scrollIntoViewIfNeeded?.().catch(() => {});
    const box = await element.boundingBox();
    if (!box || box.width <= 0 || box.height <= 0) {
      return null;
    }
    const xRatio = rand(25, 75) / 100;
    const yRatio = rand(30, 70) / 100;
    return {
      x: box.x + box.width * xRatio,
      y: box.y + box.height * yRatio,
    };
  }

  async click(selector, text, screenshot = true, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        let target = null;

        if (text && !selector) {
          const elements = await page.$$('a, button, [role="button"], input[type="submit"], [onclick]');
          for (const el of elements) {
            const elText = await page.evaluate(e => e.innerText || e.value || e.getAttribute('aria-label') || '', el);
            if (elText.toLowerCase().includes(String(text).toLowerCase())) {
              target = el;
              break;
            }
          }
          if (!target) return { error: `No clickable element found with text: ${text}` };
        } else if (selector) {
          target = await page.$(selector);
          if (!target) return { error: `Element not found: ${selector}` };
        } else {
          return { error: 'Either selector or text required' };
        }

        const point = await this._pointForElement(target);
        if (!point) return { error: 'Element has no visible clickable area' };

        await this._moveMouseTo(page, point.x, point.y, { signal: options.signal });
        await sleep(rand(170, 320), options.signal);
        await page.mouse.down();
        await sleep(rand(80, 260), options.signal);
        await page.mouse.up();

        await sleep(rand(800, 1800), options.signal);

        let screenshotResult = null;
        if (screenshot) screenshotResult = await this.takeScreenshot({ signal: options.signal });

        return {
          success: true,
          url: page.url(),
          title: await page.title(),
          screenshotPath: screenshotResult?.screenshotPath || null,
          artifactId: screenshotResult?.artifactId || null,
          fullPath: screenshotResult?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async clickPoint(x, y, screenshot = true, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const px = Math.max(0, normalizePointCoordinate(x, 'x'));
        const py = Math.max(0, normalizePointCoordinate(y, 'y'));
        await this._moveMouseTo(page, px, py, { signal: options.signal });
        await sleep(rand(90, 220), options.signal);
        await page.mouse.down();
        await sleep(rand(70, 240), options.signal);
        await page.mouse.up();
        await sleep(rand(500, 1200), options.signal);

        let screenshotResult = null;
        if (screenshot) screenshotResult = await this.takeScreenshot({ signal: options.signal });

        return {
          success: true,
          x: px,
          y: py,
          url: page.url(),
          title: await page.title(),
          screenshotPath: screenshotResult?.screenshotPath || null,
          artifactId: screenshotResult?.artifactId || null,
          fullPath: screenshotResult?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async hoverPoint(x, y, options = {}) {
    const page = await this.ensurePage(options);
    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const px = Math.max(0, normalizePointCoordinate(x, 'x'));
        const py = Math.max(0, normalizePointCoordinate(y, 'y'));
        await this._moveMouseTo(page, px, py, {
          fast: Number(options.steps) <= 1,
          signal: options.signal,
        });
        return {
          success: true,
          x: px,
          y: py,
          url: page.url(),
          title: await page.title(),
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async scroll(deltaX = 0, deltaY = 0, screenshot = true, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const x = Math.max(10, Math.min(this._viewport.width - 10, this._mousePosition.x + rand(-80, 80)));
        const y = Math.max(10, Math.min(this._viewport.height - 10, this._mousePosition.y + rand(-80, 80)));
        await this._moveMouseTo(page, x, y, { signal: options.signal });
        const totalX = Math.round(Number(deltaX) || 0);
        const totalY = Math.round(Number(deltaY) || 0);
        const chunks = Math.max(1, Math.min(6, Math.ceil(Math.max(Math.abs(totalX), Math.abs(totalY)) / 450)));
        for (let i = 0; i < chunks; i += 1) {
          await page.mouse.wheel({
            deltaX: Math.round(totalX / chunks),
            deltaY: Math.round(totalY / chunks),
          });
          await sleep(rand(120, 360), options.signal);
        }

        let screenshotResult = null;
        if (screenshot) screenshotResult = await this.takeScreenshot({ signal: options.signal });

        return {
          success: true,
          url: page.url(),
          title: await page.title(),
          screenshotPath: screenshotResult?.screenshotPath || null,
          artifactId: screenshotResult?.artifactId || null,
          fullPath: screenshotResult?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async type(selector, text, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const value = String(text ?? '');
        const element = await page.$(selector);
        if (!element) return { error: `Element not found: ${selector}` };
        const point = await this._pointForElement(element);
        if (point) {
          await this._moveMouseTo(page, point.x, point.y, { signal: options.signal });
          await sleep(rand(120, 260), options.signal);
        }

        const locator = typeof page.locator === 'function' ? page.locator(selector) : null;
        if (options.clear !== false) {
          if (locator && typeof locator.fill === 'function') {
            await locator.fill('');
          } else {
            await page.click(selector, { clickCount: 3, delay: rand(40, 120) });
            await page.keyboard.press('Backspace');
          }
        }

        if (locator && typeof locator.pressSequentially === 'function') {
          await locator.pressSequentially(value, { delay: rand(45, 140) });
        } else {
          await page.type(selector, value, { delay: rand(45, 140) });
        }

        if (options.pressEnter) {
          if (locator && typeof locator.press === 'function') await locator.press('Enter');
          else await page.keyboard.press('Enter');
          await sleep(1000, options.signal);
        }

        let screenshotResult = null;
        if (options.screenshot !== false) {
          screenshotResult = await this.takeScreenshot({ signal: options.signal });
        }

        return {
          success: true,
          typed: value,
          screenshotPath: screenshotResult?.screenshotPath || null,
          artifactId: screenshotResult?.artifactId || null,
          fullPath: screenshotResult?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async typeText(text, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const value = String(text ?? '');
        await page.keyboard.type(value, { delay: rand(45, 140) });

        if (options.pressEnter) {
          await page.keyboard.press('Enter');
          await sleep(800, options.signal);
        }

        let screenshotResult = null;
        if (options.screenshot !== false) {
          screenshotResult = await this.takeScreenshot({ signal: options.signal });
        }

        return {
          success: true,
          typed: value,
          screenshotPath: screenshotResult?.screenshotPath || null,
          artifactId: screenshotResult?.artifactId || null,
          fullPath: screenshotResult?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async pressKey(key, screenshot = true, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const normalized = String(key || '').trim();
        if (!normalized) {
          return { error: 'key required' };
        }
        await page.keyboard.press(normalized);
        await sleep(rand(250, 700), options.signal);

        let screenshotResult = null;
        if (screenshot) screenshotResult = await this.takeScreenshot({ signal: options.signal });

        return {
          success: true,
          key: normalized,
          screenshotPath: screenshotResult?.screenshotPath || null,
          artifactId: screenshotResult?.artifactId || null,
          fullPath: screenshotResult?.fullPath || null,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async extract(selector, attribute, all = false, options = {}) {
    const page = await this.ensurePage(options);

    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const rawHtml = await page.content().catch(() => '');
        const botDetection = await this._getBotDetection(page, rawHtml, '')
          .catch(() => ({ detected: false, provider: null }));
        if (all) {
          const results = await page.$$eval(selector || 'body', (elements, attr) => {
            return elements.slice(0, 100).map(el => {
              let value = '';
              if (attr === 'innerHTML') value = el.innerHTML;
              else if (attr === 'outerHTML') value = el.outerHTML;
              else if (attr) value = el.getAttribute(attr) || '';
              else value = el.innerText || '';
              return String(value).slice(0, 50000);
            });
          }, attribute);
          return { results, botDetection };
        }

        const result = await page.$eval(selector || 'body', (el, attr) => {
          if (attr === 'innerHTML') return el.innerHTML;
          if (attr === 'outerHTML') return el.outerHTML;
          if (attr) return el.getAttribute(attr) || '';
          return el.innerText || '';
        }, attribute);

        return { result: typeof result === 'string' ? result.slice(0, 50000) : result, botDetection };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async evaluate(script, options = {}) {
    const source = String(script || '');
    if (!source) return { error: 'script required' };
    if (source.length > 10000) return { error: 'script exceeds maximum length (10000)' };
    const page = await this.ensurePage(options);
    try {
      return await this._withPageCancellation(page, options.signal, async () => {
        const result = await page.evaluate(buildIsolatedEvaluationExpression(source));
        const serialized = typeof result === 'object' && result !== null
          ? JSON.stringify(result)
          : String(result);
        const output = serialized ?? 'undefined';
        const maxChars = 1024 * 1024;
        return {
          result: output.slice(0, maxChars),
          truncated: output.length > maxChars,
        };
      });
    } catch (err) {
      if (isAbortError(err, options.signal)) throw err;
      return { error: err.message };
    }
  }

  async screenshot(options = {}) {
    return this.takeScreenshot(options);
  }

  async launch(options = {}) {
    await this.ensureBrowser(options);
    return { success: true };
  }

  isLaunched() {
    return this._contextIsOpen();
  }

  getPageCount() {
    if (this.context && typeof this.context.pages === 'function') {
      try { return this.context.pages().length; } catch { return 0; }
    }
    if (!this.browser) return 0;
    try { return this.browser.pages ? 1 : 0; } catch { return 0; }
  }

  async fill(selector, value, options = {}) {
    return this.type(selector, String(value), options);
  }

  async extractContent(options = {}) {
    return this.extract(options.selector, options.attribute, options.all, options);
  }

  async executeJS(code, options = {}) {
    return this.evaluate(code, options);
  }

  async getPageInfo(options = {}) {
    throwIfAborted(options.signal);
    if (!this.page || this.page.isClosed()) return { url: null, title: null };
    return {
      url: this.page.url(),
      title: await raceWithSignal(this.page.title(), options.signal),
      protectedCredentialFill: Boolean(this._protectedCredentialFill),
    };
  }

  hasProtectedCredentialFill() {
    const fill = this._protectedCredentialFill;
    if (fill && fill.expiresAt <= Date.now() && !fill.clearing) {
      fill.clearing = true;
      Promise.allSettled([
        fill.usernameSelector ? fill.page?.locator(fill.usernameSelector).fill('') : null,
        fill.passwordSelector ? fill.page?.locator(fill.passwordSelector).fill('') : null,
      ]).finally(() => {
        if (this._protectedCredentialFill === fill) {
          this._protectedCredentialFill = null;
        }
      });
    }
    return Boolean(this._protectedCredentialFill);
  }

  async fillCredential(input = {}, options = {}) {
    if (this.hasProtectedCredentialFill()) {
      throw new Error('A protected credential fill is already active.');
    }
    const page = await this.ensurePage(options);
    const allowedOrigin = new URL(String(input.allowedOrigin || '')).origin;
    if (new URL(page.url()).origin !== allowedOrigin) {
      throw new Error('The browser origin changed before credential fill.');
    }
    await page.reload({ waitUntil: 'domcontentloaded', timeout: 30_000 });
    if (new URL(page.url()).origin !== allowedOrigin) {
      throw new Error('The browser origin changed while preparing credential fill.');
    }
    const usernameSelector = String(input.usernameSelector || '').trim();
    const passwordSelector = String(input.passwordSelector || '').trim();
    if (!usernameSelector && !passwordSelector) throw new Error('At least one credential field selector is required.');
    const username = String(input.username || '');
    if (usernameSelector) {
      await page.waitForSelector(usernameSelector, { state: 'visible', timeout: 10_000 });
      await page.locator(usernameSelector).fill(username);
    }
    if (passwordSelector) {
      await page.waitForSelector(passwordSelector, { state: 'visible', timeout: 10_000 });
      await page.locator(passwordSelector).fill(String(input.password || ''));
    }
    const protectedFillId = crypto.randomUUID();
    this._protectedCredentialFill = {
      id: protectedFillId,
      page,
      allowedOrigin,
      usernameSelector,
      passwordSelector,
      submitSelector: passwordSelector || usernameSelector,
      expiresAt: Date.now() + 5 * 60 * 1000,
    };
    return { success: true, protectedFillId, origin: allowedOrigin };
  }

  async submitProtectedCredential(protectedFillId, options = {}) {
    const fill = this._protectedCredentialFill;
    if (!this.hasProtectedCredentialFill() || fill?.id !== String(protectedFillId || '')) {
      throw new Error('Protected credential fill is missing or expired.');
    }
    const page = fill.page;
    if (!page || page.isClosed() || new URL(page.url()).origin !== fill.allowedOrigin) {
      this._protectedCredentialFill = null;
      throw new Error('The protected credential page changed before submission.');
    }
    try {
      await page.locator(fill.submitSelector).evaluate((input) => {
        const form = input.form;
        if (form && typeof form.requestSubmit === 'function') form.requestSubmit();
        else input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
      });
      await page.waitForLoadState('domcontentloaded', { timeout: 10_000 }).catch(() => {});
      return {
        success: true,
        url: page.url(),
        title: await page.title().catch(() => ''),
        protected: false,
      };
    } finally {
      if (fill.usernameSelector) {
        await page.locator(fill.usernameSelector).fill('').catch(() => {});
      }
      if (fill.passwordSelector) {
        await page.locator(fill.passwordSelector).fill('').catch(() => {});
      }
      this._protectedCredentialFill = null;
    }
  }

  async cancelProtectedCredential(protectedFillId) {
    const fill = this._protectedCredentialFill;
    if (!fill || fill.id !== String(protectedFillId || '')) {
      throw new Error('Protected credential fill is missing or expired.');
    }
    if (fill.usernameSelector) {
      await fill.page?.locator(fill.usernameSelector).fill('').catch(() => {});
    }
    if (fill.passwordSelector) {
      await fill.page?.locator(fill.passwordSelector).fill('').catch(() => {});
    }
    this._protectedCredentialFill = null;
    return { success: true, protected: false };
  }

  async getCookies(options = {}) {
    await this.ensureBrowser(options);
    if (!this.context || typeof this.context.cookies !== 'function') {
      return { cookies: [] };
    }
    const cookies = await raceWithSignal(this.context.cookies(), options.signal);
    return {
      cookies: Array.isArray(cookies) ? cookies : [],
    };
  }

  async close() {
    if (this._closePromise) return this._closePromise;
    this._closing = true;
    this._launchAbortController?.abort(new Error('Browser controller is closing.'));
    this._closePromise = (async () => {
      const launchPromise = this.launchPromise;
      if (launchPromise) await launchPromise.catch(() => {});

      const page = this.page;
      const context = this.context;
      const browser = this.browser;
      this.page = null;
      this.context = null;
      this.browser = null;
      this._protectedCredentialFill = null;

      if (context) {
        await context.close({ reason: 'Browser controller closed' }).catch(() => {});
      } else if (browser) {
        await browser.close().catch(() => {});
      } else if (page && !page.isClosed()) {
        await page.close({ runBeforeUnload: false, reason: 'Browser controller closed' }).catch(() => {});
      }
      await this._stopVirtualDisplay();
    })();
    try {
      await this._closePromise;
    } finally {
      this._closePromise = null;
      this._closing = false;
    }
  }

  async ensureVirtualDisplay(options = {}) {
    if (process.platform !== 'linux') {
      return;
    }
    if (this.displayProcess && this.displayProcess.exitCode == null) {
      return;
    }
    if (this.displayValue && String(this.displayValue).trim()) {
      return;
    }

    const display = chooseVirtualDisplay();
    const child = spawn('Xvfb', [display, '-screen', '0', '1440x900x24', '-ac', '-nolisten', 'tcp'], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    this.displayProcess = child;

    let launchError = '';
    child.stderr.on('data', (chunk) => {
      if (launchError.length < 64 * 1024) launchError += chunk.toString();
    });
    child.once('close', () => {
      if (this.displayProcess === child) {
        this.displayProcess = null;
        if (this.displayValue === display) this.displayValue = process.env.DISPLAY || null;
        if (this._managedDisplayValue === display) this._managedDisplayValue = null;
      }
    });

    try {
      await Promise.race([
        sleep(1000, options.signal),
        new Promise((_, reject) => child.once('error', reject)),
      ]);
      if (child.exitCode != null) {
        throw new Error(`Failed to start Xvfb: ${String(launchError || `exit code ${child.exitCode}`).trim()}`);
      }
    } catch (error) {
      await this._stopVirtualDisplay();
      throw error;
    }

    this.displayValue = display;
    this._managedDisplayValue = display;
  }

  async _stopVirtualDisplay() {
    const child = this.displayProcess;
    const managedDisplay = this._managedDisplayValue;
    this.displayProcess = null;
    this._managedDisplayValue = null;
    if (managedDisplay && this.displayValue === managedDisplay) {
      this.displayValue = process.env.DISPLAY || null;
    }
    if (!child || child.exitCode != null) return;

    const exited = new Promise((resolve) => child.once('close', resolve));
    try { child.kill('SIGTERM'); } catch {}
    await Promise.race([exited, sleep(1000)]);
    if (child.exitCode == null) {
      try { child.kill('SIGKILL'); } catch {}
      await Promise.race([exited, sleep(1000)]);
    }
  }
}

module.exports = {
  BrowserController,
  buildIsolatedEvaluationExpression,
  normalizeWaitUntil,
  resolveBrowserExecutablePath,
};
