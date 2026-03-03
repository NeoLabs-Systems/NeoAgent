const path = require('path');
const fs = require('fs');

const SCREENSHOTS_DIR = path.join(__dirname, '..', '..', '..', 'data', 'screenshots');
if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

class BrowserController {
  constructor(io) {
    this.io = io;
    this.browser = null;
    this.page = null;
    this.launching = false;
    this.headless = true; // can be toggled via setHeadless()
  }

  async setHeadless(val) {
    const wasHeadless = this.headless;
    this.headless = val !== false && val !== 'false';
    // Close browser so it relaunches with new setting next time
    if (wasHeadless !== this.headless) {
      await this.close().catch(() => {});
    }
  }

  // Alias used by graceful shutdown in server.js
  async closeBrowser() {
    return this.close();
  }

  async ensureBrowser() {
    if (this.browser && this.browser.isConnected()) return;
    if (this.launching) {
      await new Promise(resolve => setTimeout(resolve, 2000));
      return;
    }

    this.launching = true;
    try {
      const puppeteer = require('puppeteer');
      this.browser = await puppeteer.launch({
        headless: this.headless ? 'new' : false,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-gpu',
          '--window-size=1280,800'
        ],
        defaultViewport: { width: 1280, height: 800 }
      });
      this.page = await this.browser.newPage();
      await this.page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
    } finally {
      this.launching = false;
    }
  }

  async ensurePage() {
    await this.ensureBrowser();
    if (!this.page || this.page.isClosed()) {
      this.page = await this.browser.newPage();
      await this.page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
    }
    return this.page;
  }

  async takeScreenshot(options = {}) {
    const page = await this.ensurePage();
    const filename = `screenshot_${Date.now()}.png`;
    const filepath = path.join(SCREENSHOTS_DIR, filename);

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

    return { screenshotPath: `/screenshots/${filename}`, filename, fullPath: filepath };
  }

  async navigate(url, options = {}) {
    const page = await this.ensurePage();

    try {
      const response = await page.goto(url, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      if (options.waitFor) {
        await page.waitForSelector(options.waitFor, { timeout: 10000 }).catch(() => {});
      }

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
        const scripts = clone.querySelectorAll('script, style, noscript');
        scripts.forEach(s => s.remove());
        return clone.innerText.slice(0, 10000);
      });

      return {
        title,
        url: currentUrl,
        status: response?.status() || 0,
        bodyText,
        screenshotPath: screenshot?.screenshotPath || null
      };
    } catch (err) {
      let screenshot = null;
      try { screenshot = await this.takeScreenshot(); } catch {}
      return {
        error: err.message,
        url,
        screenshotPath: screenshot?.screenshotPath || null
      };
    }
  }

  async click(selector, text, screenshot = true) {
    const page = await this.ensurePage();

    try {
      if (text && !selector) {
        const elements = await page.$$('a, button, [role="button"], input[type="submit"], [onclick]');
        let found = false;
        for (const el of elements) {
          const elText = await page.evaluate(e => e.innerText || e.value || e.getAttribute('aria-label') || '', el);
          if (elText.toLowerCase().includes(text.toLowerCase())) {
            await el.click();
            found = true;
            break;
          }
        }
        if (!found) {
          return { error: `No clickable element found with text: ${text}` };
        }
      } else if (selector) {
        await page.click(selector);
      } else {
        return { error: 'Either selector or text required' };
      }

      await new Promise(r => setTimeout(r, 1000));

      let screenshotResult = null;
      if (screenshot) {
        screenshotResult = await this.takeScreenshot();
      }

      const currentUrl = page.url();
      const title = await page.title();

      return {
        success: true,
        url: currentUrl,
        title,
        screenshotPath: screenshotResult?.screenshotPath || null
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

      await page.type(selector, text, { delay: 30 });

      if (options.pressEnter) {
        await page.keyboard.press('Enter');
        await new Promise(r => setTimeout(r, 1000));
      }

      let screenshotResult = null;
      if (options.screenshot !== false) {
        screenshotResult = await this.takeScreenshot();
      }

      return {
        success: true,
        typed: text,
        screenshotPath: screenshotResult?.screenshotPath || null
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
      const result = await page.evaluate(script);
      return { result: typeof result === 'object' ? JSON.stringify(result) : String(result) };
    } catch (err) {
      return { error: err.message };
    }
  }

  async screenshot(options = {}) {
    return await this.takeScreenshot(options);
  }

  async launch(options = {}) {
    await this.ensureBrowser();
    return { success: true };
  }

  isLaunched() {
    return !!(this.browser && this.browser.isConnected());
  }

  getPageCount() {
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

  async close() {
    if (this.page && !this.page.isClosed()) {
      await this.page.close().catch(() => {});
    }
    if (this.browser) {
      await this.browser.close().catch(() => {});
      this.browser = null;
      this.page = null;
    }
  }
}

module.exports = { BrowserController };
