const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');
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

function installPlaywrightBrowserBinary(browserName) {
  const packageRoot = path.dirname(require.resolve('playwright-chromium/package.json'));
  const cliPath = path.join(packageRoot, 'cli.js');
  return new Promise((resolve, reject) => {
    const args = [cliPath, 'install', '--no-shell', browserName];
    const child = spawn(process.execPath, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });
    child.on('error', (error) => {
      const detail = String(error?.message || `playwright install ${browserName} failed`).trim();
      reject(new Error(detail));
    });
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      const detail = String(stderr || stdout || `playwright install ${browserName} exited with code ${code ?? 'unknown'}`).trim();
      reject(new Error(detail));
    });
  });
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function waitForFile(filePath, options = {}) {
  const timeoutMs = Math.max(0, Number(options.timeoutMs || 0));
  const intervalMs = Math.max(100, Number(options.intervalMs || 500));
  if (!filePath || timeoutMs <= 0 || fs.existsSync(filePath)) {
    return fs.existsSync(filePath);
  }
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    await sleep(intervalMs);
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
    this.launching = false;
    this.launchPromise = null;
    this.browserBinaryInstallPromise = null;
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
            Object.defineProperty(arr, 'length', { get: () => arr.length });
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

        // Media Devices Spoofing
        if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
            const originalEnumerateDevices = navigator.mediaDevices.enumerateDevices.bind(navigator.mediaDevices);
            navigator.mediaDevices.enumerateDevices = async () => {
                return [
                    { kind: 'audioinput', deviceId: 'default', groupId: 'a', label: 'MacBook Pro Microphone' },
                    { kind: 'audiooutput', deviceId: 'default', groupId: 'b', label: 'MacBook Pro Speakers' },
                    { kind: 'videoinput', deviceId: 'default', groupId: 'c', label: 'FaceTime HD Camera' }
                ];
            };
        }
      })();
    `;
    if (typeof page.evaluateOnNewDocument === 'function') {
      await page.evaluateOnNewDocument(script);
    } else if (typeof page.addInitScript === 'function') {
      await page.addInitScript(script);
    }
  }

  async ensureBrowser() {
    if (this.browser && this.browser.isConnected()) return;
    if (this.launchPromise) {
      await this.launchPromise;
      return;
    }

    this.launching = true;
    this.launchPromise = (async () => {
      const runtimeReady = await waitForFile(BROWSER_READY_MARKER, {
        timeoutMs: 10 * 60 * 1000,
        intervalMs: 1000,
      });
      if (!runtimeReady) {
        throw new Error('Browser runtime provisioning is still in progress inside the VM. Retry shortly.');
      }
      await this.ensureVirtualDisplay();

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
          this.browserBinaryInstallPromise = installPlaywrightBrowserBinary(this.engine);
        }
        try {
          await this.browserBinaryInstallPromise;
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
        '--no-sandbox',
        '--disable-setuid-sandbox',
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
      this.context = await playwright.chromium.launchPersistentContext(this.profileDir, {
        headless: false,
        executablePath,
        env: launchEnv,
        args: launchArgs,
        viewport: this._viewport,
        userAgent: this._userAgent,
        locale: 'en-US',
        ignoreHTTPSErrors: false,
        timeout: 120000,
      });
      this.browser = typeof this.context.browser === 'function' ? this.context.browser() : null;

      // Cloud security: deny access to local devices on every page in this context.
      await this.context.addInitScript(DEVICE_DENY_SCRIPT);

      this.page = this.context.pages()[0] || await this.context.newPage();
      await this._applyStealthToPage(this.page);
    })();

    try {
      await this.launchPromise;
    } finally {
      this.launchPromise = null;
      this.launching = false;
    }
  }

  async ensurePage() {
    await this.ensureBrowser();
    if (!this.page || this.page.isClosed()) {
      if (this.context && typeof this.context.newPage === 'function') {
        this.page = await this.context.newPage();
      } else {
        this.page = await this.browser.newPage();
      }
      await this._applyStealthToPage(this.page);
    }
    return this.page;
  }

  async takeScreenshot(options = {}) {
    const page = await this.ensurePage();
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
  }

  async screenshotJpeg(quality = 80, options = {}) {
    const page = await this.ensurePage();
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
  }

  async _navigatePage(page, url, options = {}) {
    const referrerMode = normalizeReferrerMode(options.referrerMode);
    const waitUntil = normalizeWaitUntil(options.waitUntil);
    if (referrerMode === 'current' && page.url() && page.url() !== 'about:blank') {
      const previousUrl = page.url();
      await page.evaluate((nextUrl) => { window.location.href = nextUrl; }, url);
      await page.waitForFunction((oldUrl) => window.location.href !== oldUrl, previousUrl, { timeout: 10000 }).catch(() => {});
      await page.waitForLoadState(waitUntil, { timeout: 30000 }).catch(() => {});
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
    const page = await this.ensurePage();

    try {
      const requestedReferrerMode = normalizeReferrerMode(options.referrerMode);
      let activeReferrerMode = requestedReferrerMode;
      let response = await this._navigatePage(page, url, {
        ...options,
        referrerMode: activeReferrerMode,
      });

      if (options.waitFor) {
        await page.waitForSelector(options.waitFor, { timeout: 10000 }).catch(() => { });
      }

      // Simulate human reading delay
      await sleep(rand(700, 1800));

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
        await sleep(rand(1200, 2600));
        response = await this._navigatePage(page, url, {
          ...options,
          referrerMode: activeReferrerMode,
        });
        if (options.waitFor) {
          await page.waitForSelector(options.waitFor, { timeout: 10000 }).catch(() => { });
        }
        await sleep(rand(900, 2200));
        rawHtml = await page.content();
        extraction = extractForLLM(rawHtml, { url: page.url() });
        botDetection = await this._getBotDetection(page, rawHtml, extraction.markdown);
      }

      const title = await page.title();
      const currentUrl = page.url();

      let screenshot = null;
      if (options.screenshot !== false) {
        screenshot = await this.takeScreenshot({ fullPage: options.fullPage });
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
        fullPath: screenshot?.fullPath || null
      };
    } catch (err) {
      let screenshot = null;
      try { screenshot = await this.takeScreenshot(); } catch { }
      return {
        error: err.message,
        url,
        botDetection: { detected: false, provider: null },
        screenshotPath: screenshot?.screenshotPath || null,
        artifactId: screenshot?.artifactId || null,
        fullPath: screenshot?.fullPath || null
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
        await sleep(rand(2, 10));
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

  async click(selector, text, screenshot = true) {
    const page = await this.ensurePage();

    try {
      let target = null;

      if (text && !selector) {
        const elements = await page.$$('a, button, [role="button"], input[type="submit"], [onclick]');
        for (const el of elements) {
          const elText = await page.evaluate(e => e.innerText || e.value || e.getAttribute('aria-label') || '', el);
          if (elText.toLowerCase().includes(text.toLowerCase())) {
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

      await this._moveMouseTo(page, point.x, point.y);
      await sleep(rand(170, 320));
      await page.mouse.down();
      await sleep(rand(80, 260));
      await page.mouse.up();

      await sleep(rand(800, 1800));

      let screenshotResult = null;
      if (screenshot) screenshotResult = await this.takeScreenshot();

      return {
        success: true,
        url: page.url(),
        title: await page.title(),
        screenshotPath: screenshotResult?.screenshotPath || null,
        artifactId: screenshotResult?.artifactId || null,
        fullPath: screenshotResult?.fullPath || null
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async clickPoint(x, y, screenshot = true) {
    const page = await this.ensurePage();

    try {
      const px = Math.max(0, Math.round(Number(x) || 0));
      const py = Math.max(0, Math.round(Number(y) || 0));
      await this._moveMouseTo(page, px, py);
      await sleep(rand(90, 220));
      await page.mouse.down();
      await sleep(rand(70, 240));
      await page.mouse.up();
      await sleep(rand(500, 1200));

      let screenshotResult = null;
      if (screenshot) screenshotResult = await this.takeScreenshot();

      return {
        success: true,
        x: px,
        y: py,
        url: page.url(),
        title: await page.title(),
        screenshotPath: screenshotResult?.screenshotPath || null,
        artifactId: screenshotResult?.artifactId || null,
        fullPath: screenshotResult?.fullPath || null
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async hoverPoint(x, y, options = {}) {
    const page = await this.ensurePage();
    try {
      const px = Math.max(0, Math.round(Number(x) || 0));
      const py = Math.max(0, Math.round(Number(y) || 0));
      await this._moveMouseTo(page, px, py, { fast: Number(options.steps) <= 1 });
      return {
        success: true,
        x: px,
        y: py,
        url: page.url(),
        title: await page.title()
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async scroll(deltaX = 0, deltaY = 0, screenshot = true) {
    const page = await this.ensurePage();

    try {
      const x = Math.max(10, Math.min(this._viewport.width - 10, this._mousePosition.x + rand(-80, 80)));
      const y = Math.max(10, Math.min(this._viewport.height - 10, this._mousePosition.y + rand(-80, 80)));
      await this._moveMouseTo(page, x, y);
      const totalX = Math.round(Number(deltaX) || 0);
      const totalY = Math.round(Number(deltaY) || 0);
      const chunks = Math.max(1, Math.min(6, Math.ceil(Math.max(Math.abs(totalX), Math.abs(totalY)) / 450)));
      for (let i = 0; i < chunks; i += 1) {
        await page.mouse.wheel({
          deltaX: Math.round(totalX / chunks),
          deltaY: Math.round(totalY / chunks),
        });
        await sleep(rand(120, 360));
      }

      let screenshotResult = null;
      if (screenshot) screenshotResult = await this.takeScreenshot();

      return {
        success: true,
        url: page.url(),
        title: await page.title(),
        screenshotPath: screenshotResult?.screenshotPath || null,
        artifactId: screenshotResult?.artifactId || null,
        fullPath: screenshotResult?.fullPath || null
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async type(selector, text, options = {}) {
    const page = await this.ensurePage();

    try {
      if (options.clear !== false) {
        const element = await page.$(selector);
        if (element) {
          const point = await this._pointForElement(element);
          if (point) {
            await this._moveMouseTo(page, point.x, point.y);
            await sleep(rand(120, 260));
          }
        }
        await page.click(selector, { clickCount: 3, delay: rand(40, 120) });
        await page.keyboard.press('Backspace');
      }

      for (const char of text) {
        await page.type(selector, char, { delay: rand(45, 180) });
      }

      if (options.pressEnter) {
        await page.keyboard.press('Enter');
        await sleep(1000);
      }

      let screenshotResult = null;
      if (options.screenshot !== false) screenshotResult = await this.takeScreenshot();

      return {
        success: true,
        typed: text,
        screenshotPath: screenshotResult?.screenshotPath || null,
        artifactId: screenshotResult?.artifactId || null,
        fullPath: screenshotResult?.fullPath || null
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async typeText(text, options = {}) {
    const page = await this.ensurePage();

    try {
      for (const char of String(text || '')) {
        await page.keyboard.type(char, { delay: rand(45, 160) });
      }

      if (options.pressEnter) {
        await page.keyboard.press('Enter');
        await sleep(800);
      }

      let screenshotResult = null;
      if (options.screenshot !== false) screenshotResult = await this.takeScreenshot();

      return {
        success: true,
        typed: String(text || ''),
        screenshotPath: screenshotResult?.screenshotPath || null,
        artifactId: screenshotResult?.artifactId || null,
        fullPath: screenshotResult?.fullPath || null
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async pressKey(key, screenshot = true) {
    const page = await this.ensurePage();

    try {
      const normalized = String(key || '').trim();
      if (!normalized) {
        return { error: 'key required' };
      }
      await page.keyboard.press(normalized);
      await sleep(rand(250, 700));

      let screenshotResult = null;
      if (screenshot) screenshotResult = await this.takeScreenshot();

      return {
        success: true,
        key: normalized,
        screenshotPath: screenshotResult?.screenshotPath || null,
        artifactId: screenshotResult?.artifactId || null,
        fullPath: screenshotResult?.fullPath || null
      };
    } catch (err) {
      return { error: err.message };
    }
  }

  async extract(selector, attribute, all = false) {
    const page = await this.ensurePage();

    try {
      const rawHtml = await page.content().catch(() => '');
      const botDetection = await this._getBotDetection(page, rawHtml, '').catch(() => ({ detected: false, provider: null }));
      if (all) {
        const results = await page.$$eval(selector || 'body', (elements, attr) => {
          return elements.map(el => {
            if (attr === 'innerHTML') return el.innerHTML;
            if (attr === 'outerHTML') return el.outerHTML;
            if (attr) return el.getAttribute(attr) || '';
            return el.innerText || '';
          });
        }, attribute);
        return { results: results.slice(0, 100), botDetection };
      }

      const result = await page.$eval(selector || 'body', (el, attr) => {
        if (attr === 'innerHTML') return el.innerHTML;
        if (attr === 'outerHTML') return el.outerHTML;
        if (attr) return el.getAttribute(attr) || '';
        return el.innerText || '';
      }, attribute);

      return { result: typeof result === 'string' ? result.slice(0, 50000) : result, botDetection };
    } catch (err) {
      return { error: err.message };
    }
  }

  async evaluate(script) {
    const page = await this.ensurePage();
    try {
      const result = await page.evaluate(buildIsolatedEvaluationExpression(script));
      return { result: typeof result === 'object' ? JSON.stringify(result) : String(result) };
    } catch (err) {
      return { error: err.message };
    }
  }

  async screenshot(options = {}) {
    return this.takeScreenshot(options);
  }

  async launch(options = {}) {
    void options;
    await this.ensureBrowser();
    return { success: true };
  }

  isLaunched() {
    if (this.context) return true;
    return !!(this.browser && typeof this.browser.isConnected === 'function' && this.browser.isConnected());
  }

  getPageCount() {
    if (this.context && typeof this.context.pages === 'function') {
      try { return this.context.pages().length; } catch { return 0; }
    }
    if (!this.browser) return 0;
    try { return this.browser.pages ? 1 : 0; } catch { return 0; }
  }

  async fill(selector, value) {
    return this.type(selector, String(value));
  }

  async extractContent(options = {}) {
    return this.extract(options.selector, options.attribute, options.all);
  }

  async executeJS(code) {
    return this.evaluate(code);
  }

  async getPageInfo() {
    if (!this.page || this.page.isClosed()) return { url: null, title: null };
    return {
      url: this.page.url(),
      title: await this.page.title()
    };
  }

  async getCookies() {
    await this.ensureBrowser();
    if (!this.context || typeof this.context.cookies !== 'function') {
      return { cookies: [] };
    }
    const cookies = await this.context.cookies().catch(() => []);
    return {
      cookies: Array.isArray(cookies) ? cookies : [],
    };
  }

  async close() {
    if (this.page && !this.page.isClosed()) {
      await this.page.close().catch(() => { });
    }
    if (this.context) {
      await this.context.close().catch(() => { });
      this.context = null;
      this.browser = null;
      this.page = null;
      return;
    }
    if (this.browser) {
      await this.browser.close().catch(() => { });
      this.browser = null;
      this.page = null;
    }
  }

  async ensureVirtualDisplay() {
    if (process.platform !== 'linux') {
      return;
    }
    if (this.displayProcess && !this.displayProcess.killed) {
      return;
    }
    if (this.displayValue && String(this.displayValue).trim()) {
      return;
    }

    const display = ':99';
    const child = spawn('Xvfb', [display, '-screen', '0', '1440x900x24', '-ac', '-nolisten', 'tcp'], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });

    let launchError = '';
    child.stderr.on('data', (chunk) => {
      launchError += chunk.toString();
    });

    await sleep(1000);
    if (child.exitCode != null) {
      throw new Error(`Failed to start Xvfb: ${String(launchError || `exit code ${child.exitCode}`).trim()}`);
    }

    this.displayProcess = child;
    this.displayValue = display;
  }
}

module.exports = { BrowserController, resolveBrowserExecutablePath, buildIsolatedEvaluationExpression, normalizeWaitUntil };
