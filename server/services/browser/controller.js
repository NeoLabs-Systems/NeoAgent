const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');

const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
const BROWSER_PROFILE_ROOT = path.join(DATA_DIR, 'browser-profiles');
if (!fs.existsSync(BROWSER_PROFILE_ROOT)) fs.mkdirSync(BROWSER_PROFILE_ROOT, { recursive: true });
const BROWSER_READY_MARKER = '/var/lib/neoagent/browser-runtime-ready';

const USER_AGENTS = [
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
];

const VIEWPORTS = [
  { width: 1280, height: 800 },
  { width: 1366, height: 768 },
  { width: 1440, height: 900 },
  { width: 1920, height: 1080 },
];

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

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
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
    this._viewport = VIEWPORTS[0];
    this._userAgent = USER_AGENTS[0];
    this.profileDir = path.join(BROWSER_PROFILE_ROOT, this.userId || 'default');
    if (!fs.existsSync(this.profileDir)) fs.mkdirSync(this.profileDir, { recursive: true });
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
        Object.defineProperty(navigator, 'platform', { get: () => 'MacIntel' });
        Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => ${rand(4, 16)} });
        Object.defineProperty(navigator, 'deviceMemory', { get: () => ${[4, 8, 16][rand(0, 2)]} });

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
            if (param === 37445) return 'Google Inc. (Apple)';
            // UNMASKED_RENDERER_WEBGL
            if (param === 37446) return 'ANGLE (Apple, Apple M2, OpenGL 4.1)';
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

      this._userAgent = USER_AGENTS[rand(0, USER_AGENTS.length - 1)];
      this._viewport = VIEWPORTS[rand(0, VIEWPORTS.length - 1)];

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
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-crash-reporter',
        '--disable-background-networking',
        '--disable-component-update',
        '--disable-blink-features=AutomationControlled',
        '--disable-infobars',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-gpu',
        '--lang=en-US,en',
        `--window-size=${this._viewport.width},${this._viewport.height}`,
      ];

      const playwright = require('playwright-chromium');
      clearChromiumSingletonLocks(this.profileDir);
      this.context = await playwright.chromium.launchPersistentContext(this.profileDir, {
        headless: false,
        executablePath,
        env: launchEnv,
        args: launchArgs,
        viewport: this._viewport,
        ignoreHTTPSErrors: false,
        timeout: 120000,
      });
      this.browser = typeof this.context.browser === 'function' ? this.context.browser() : null;
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

  async navigate(url, options = {}) {
    const page = await this.ensurePage();

    try {
      const response = await page.goto(url, {
        waitUntil: normalizeWaitUntil(options.waitUntil),
        timeout: 30000
      });

      if (options.waitFor) {
        await page.waitForSelector(options.waitFor, { timeout: 10000 }).catch(() => { });
      }

      // Simulate human reading delay
      await sleep(rand(500, 1500));

      const title = await page.title();
      const currentUrl = page.url();

      let screenshot = null;
      if (options.screenshot !== false) {
        screenshot = await this.takeScreenshot({ fullPage: options.fullPage });
      }

      const bodyText = await page.evaluate(() => {
        const body = document.body;
        if (!body) return '';
        const clone = body.cloneNode(true);
        clone.querySelectorAll('script, style, noscript').forEach(s => s.remove());
        return clone.innerText.slice(0, 10000);
      });

      return {
        title,
        url: currentUrl,
        status: response?.status() || 0,
        bodyText,
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
        screenshotPath: screenshot?.screenshotPath || null,
        artifactId: screenshot?.artifactId || null,
        fullPath: screenshot?.fullPath || null
      };
    }
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

      // Human-like: hover first, then click with a hold delay
      await target.hover();
      await sleep(rand(80, 250));
      await target.click({ delay: rand(50, 150) });

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
      await page.mouse.move(px, py, { steps: rand(4, 10) });
      await sleep(rand(40, 140));
      await page.mouse.down();
      await sleep(rand(30, 110));
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

  async scroll(deltaX = 0, deltaY = 0, screenshot = true) {
    const page = await this.ensurePage();

    try {
      await page.mouse.wheel({
        deltaX: Math.round(Number(deltaX) || 0),
        deltaY: Math.round(Number(deltaY) || 0),
      });
      await sleep(rand(300, 900));

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
        await page.click(selector, { clickCount: 3 });
        await page.keyboard.press('Backspace');
      }

      for (const char of text) {
        await page.type(selector, char, { delay: rand(30, 150) });
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
        await page.keyboard.type(char, { delay: rand(25, 110) });
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
      if (all) {
        const results = await page.$$eval(selector || 'body', (elements, attr) => {
          return elements.map(el => {
            if (attr === 'innerHTML') return el.innerHTML;
            if (attr === 'outerHTML') return el.outerHTML;
            if (attr) return el.getAttribute(attr) || '';
            return el.innerText || '';
          });
        }, attribute);
        return { results: results.slice(0, 100) };
      }

      const result = await page.$eval(selector || 'body', (el, attr) => {
        if (attr === 'innerHTML') return el.innerHTML;
        if (attr === 'outerHTML') return el.outerHTML;
        if (attr) return el.getAttribute(attr) || '';
        return el.innerText || '';
      }, attribute);

      return { result: typeof result === 'string' ? result.slice(0, 50000) : result };
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
