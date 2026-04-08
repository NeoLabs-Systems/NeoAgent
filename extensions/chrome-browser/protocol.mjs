export const COMMANDS = Object.freeze({
  LAUNCH: 'launch',
  NAVIGATE: 'navigate',
  CLICK: 'click',
  CLICK_POINT: 'clickPoint',
  TYPE: 'type',
  TYPE_TEXT: 'typeText',
  PRESS_KEY: 'pressKey',
  SCROLL: 'scroll',
  EXTRACT: 'extract',
  EVALUATE: 'evaluate',
  SCREENSHOT: 'screenshot',
  CLOSE: 'close',
  GET_PAGE_INFO: 'getPageInfo',
});

function chromeCall(chromeApi, namespace, method, ...args) {
  return new Promise((resolve, reject) => {
    chromeApi[namespace][method](...args, (result) => {
      const error = chromeApi.runtime?.lastError;
      if (error) {
        reject(new Error(error.message || String(error)));
        return;
      }
      resolve(result);
    });
  });
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function jsString(value) {
  return JSON.stringify(String(value ?? ''));
}

function keyCodeFor(key) {
  const normalized = String(key || '').trim();
  const map = {
    Enter: 13,
    Escape: 27,
    Backspace: 8,
    Tab: 9,
    ArrowUp: 38,
    ArrowDown: 40,
    ArrowLeft: 37,
    ArrowRight: 39,
  };
  return map[normalized] || (normalized.length === 1 ? normalized.toUpperCase().charCodeAt(0) : 0);
}

export function createBrowserProtocol(chromeApi) {
  let attachedTabId = null;
  let activeTabId = null;

  const debuggee = () => ({ tabId: activeTabId });

  async function ensureTab() {
    if (activeTabId != null) {
      try {
        await chromeCall(chromeApi, 'tabs', 'get', activeTabId);
        return activeTabId;
      } catch {
        activeTabId = null;
      }
    }

    const tabs = await chromeCall(chromeApi, 'tabs', 'query', { active: true, currentWindow: true });
    if (tabs && tabs[0]?.id != null) {
      activeTabId = tabs[0].id;
      return activeTabId;
    }
    const tab = await chromeCall(chromeApi, 'tabs', 'create', { url: 'about:blank', active: true });
    activeTabId = tab.id;
    return activeTabId;
  }

  async function attach() {
    await ensureTab();
    if (attachedTabId === activeTabId) return;
    if (attachedTabId != null) {
      await chromeCall(chromeApi, 'debugger', 'detach', { tabId: attachedTabId }).catch(() => {});
    }
    try {
      await chromeCall(chromeApi, 'debugger', 'attach', debuggee(), '1.3');
    } catch (error) {
      if (!/another debugger|already attached|debugger is already attached/i.test(error.message)) {
        throw error;
      }
    }
    attachedTabId = activeTabId;
    await send('Page.enable').catch(() => {});
    await send('Runtime.enable').catch(() => {});
    await send('DOM.enable').catch(() => {});
  }

  async function send(method, params = {}) {
    return chromeCall(chromeApi, 'debugger', 'sendCommand', debuggee(), method, params);
  }

  async function evalJs(expression, options = {}) {
    await attach();
    const response = await send('Runtime.evaluate', {
      expression,
      awaitPromise: options.awaitPromise !== false,
      returnByValue: true,
    });
    if (response?.exceptionDetails) {
      throw new Error(response.exceptionDetails.text || 'JavaScript evaluation failed.');
    }
    return response?.result?.value;
  }

  async function waitForLoad(timeoutMs = 30000) {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      const ready = await evalJs('document.readyState === "complete" || document.readyState === "interactive"', { awaitPromise: false })
        .catch(() => false);
      if (ready) return;
      await delay(250);
    }
  }

  async function waitForSelector(selector, timeoutMs = 10000) {
    if (!selector) return;
    const expression = `Boolean(document.querySelector(${jsString(selector)}))`;
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      if (await evalJs(expression, { awaitPromise: false }).catch(() => false)) return;
      await delay(200);
    }
  }

  async function currentTab() {
    await ensureTab();
    return chromeCall(chromeApi, 'tabs', 'get', activeTabId);
  }

  async function screenshotDataUrl(options = {}) {
    await attach();
    const capture = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: options.fullPage === true,
      fromSurface: true,
    });
    return `data:image/png;base64,${capture?.data || ''}`;
  }

  async function pageSnapshot(options = {}) {
    const tab = await currentTab();
    const title = await evalJs('document.title || ""', { awaitPromise: false }).catch(() => tab.title || '');
    const bodyText = await evalJs(`(() => {
      const body = document.body;
      if (!body) return '';
      const clone = body.cloneNode(true);
      clone.querySelectorAll('script, style, noscript').forEach((node) => node.remove());
      return String(clone.innerText || '').slice(0, 10000);
    })()`).catch(() => '');
    const result = {
      title: title || tab.title || '',
      url: tab.url || '',
      status: 0,
      bodyText,
    };
    if (options.screenshot !== false) {
      result.screenshotDataUrl = await screenshotDataUrl(options);
    }
    return result;
  }

  async function locateTarget(payload = {}) {
    const selector = String(payload.selector || '').trim();
    const text = String(payload.text || '').trim().toLowerCase();
    const expression = selector
      ? `(() => {
          const el = document.querySelector(${jsString(selector)});
          if (!el) return null;
          const rect = el.getBoundingClientRect();
          return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
        })()`
      : `(() => {
          const candidates = Array.from(document.querySelectorAll('a, button, [role="button"], input[type="submit"], [onclick]'));
          const target = candidates.find((el) => String(el.innerText || el.value || el.getAttribute('aria-label') || '').toLowerCase().includes(${jsString(text)}));
          if (!target) return null;
          const rect = target.getBoundingClientRect();
          return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
        })()`;
    const point = await evalJs(expression);
    if (!point || !Number.isFinite(Number(point.x)) || !Number.isFinite(Number(point.y))) {
      throw new Error(selector ? `Element not found: ${selector}` : `No clickable element found with text: ${payload.text}`);
    }
    return { x: Math.round(point.x), y: Math.round(point.y) };
  }

  async function clickPoint(x, y) {
    await attach();
    const px = Math.max(0, Math.round(Number(x) || 0));
    const py = Math.max(0, Math.round(Number(y) || 0));
    await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: px, y: py });
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: px, y: py, button: 'left', clickCount: 1 });
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: px, y: py, button: 'left', clickCount: 1 });
    await delay(500);
    return { x: px, y: py };
  }

  async function typeKey(key) {
    await attach();
    const normalized = String(key || '').trim();
    const code = keyCodeFor(normalized);
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: normalized, windowsVirtualKeyCode: code });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: normalized, windowsVirtualKeyCode: code });
  }

  async function run(command, payload = {}) {
    switch (command) {
      case COMMANDS.LAUNCH:
        await attach();
        return pageSnapshot({ screenshot: false });
      case COMMANDS.NAVIGATE:
        await attach();
        if (!payload.url) throw new Error('url required');
        await send('Page.navigate', { url: String(payload.url) });
        await waitForLoad();
        await waitForSelector(payload.waitFor);
        return pageSnapshot(payload);
      case COMMANDS.CLICK: {
        const point = await locateTarget(payload);
        await clickPoint(point.x, point.y);
        return pageSnapshot({ screenshot: payload.screenshot !== false });
      }
      case COMMANDS.CLICK_POINT:
        await clickPoint(payload.x, payload.y);
        return pageSnapshot({ screenshot: payload.screenshot !== false });
      case COMMANDS.TYPE:
        if (!payload.selector) throw new Error('selector required');
        if (payload.clear !== false) {
          await evalJs(`(() => {
            const el = document.querySelector(${jsString(payload.selector)});
            if (!el) throw new Error('Element not found: ${String(payload.selector).replace(/'/g, "\\'")}');
            el.focus();
            if ('value' in el) el.value = '';
          })()`);
        } else {
          await evalJs(`document.querySelector(${jsString(payload.selector)})?.focus()`);
        }
        await send('Input.insertText', { text: String(payload.text || '') });
        if (payload.pressEnter) await typeKey('Enter');
        return pageSnapshot({ screenshot: payload.screenshot !== false });
      case COMMANDS.TYPE_TEXT:
        await attach();
        await send('Input.insertText', { text: String(payload.text || '') });
        if (payload.pressEnter) await typeKey('Enter');
        return pageSnapshot({ screenshot: payload.screenshot !== false });
      case COMMANDS.PRESS_KEY:
        await typeKey(payload.key);
        return pageSnapshot({ screenshot: payload.screenshot !== false });
      case COMMANDS.SCROLL:
        await evalJs(`window.scrollBy(${Math.round(Number(payload.deltaX) || 0)}, ${Math.round(Number(payload.deltaY) || 0)})`);
        await delay(250);
        return pageSnapshot({ screenshot: payload.screenshot !== false });
      case COMMANDS.EXTRACT: {
        const selector = payload.selector || 'body';
        const attribute = payload.attribute || '';
        const expression = `(() => {
          const read = (el) => {
            const attr = ${jsString(attribute)};
            if (attr === 'innerHTML') return el.innerHTML;
            if (attr === 'outerHTML') return el.outerHTML;
            if (attr) return el.getAttribute(attr) || '';
            return el.innerText || '';
          };
          const els = Array.from(document.querySelectorAll(${jsString(selector)}));
          if (${payload.all === true}) return { results: els.slice(0, 100).map(read) };
          return { result: els[0] ? String(read(els[0])).slice(0, 50000) : '' };
        })()`;
        return evalJs(expression);
      }
      case COMMANDS.EVALUATE: {
        const value = await evalJs(String(payload.script || 'undefined'));
        return { result: typeof value === 'object' ? JSON.stringify(value) : String(value) };
      }
      case COMMANDS.SCREENSHOT:
        return { screenshotDataUrl: await screenshotDataUrl(payload), fullPage: payload.fullPage === true };
      case COMMANDS.GET_PAGE_INFO: {
        const tab = await currentTab();
        return { url: tab.url || null, title: tab.title || null };
      }
      case COMMANDS.CLOSE:
        if (attachedTabId != null) {
          await chromeCall(chromeApi, 'debugger', 'detach', { tabId: attachedTabId }).catch(() => {});
        }
        attachedTabId = null;
        return { success: true };
      default:
        throw new Error(`Unsupported command: ${command}`);
    }
  }

  return {
    run,
    _test: {
      ensureTab,
      attach,
      send,
      evalJs,
    },
  };
}
