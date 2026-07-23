export const EXTENSION_PROTOCOL_VERSION = 1;

export const MESSAGE_TYPES = Object.freeze({
  COMMAND: 'command',
  RESULT: 'result',
  URL_VALIDATION_REQUEST: 'urlValidationRequest',
  URL_VALIDATION_RESULT: 'urlValidationResult',
});

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
  GET_COOKIES: 'getCookies',
  FILL_CREDENTIAL: 'fillCredential',
  SUBMIT_CREDENTIAL: 'submitCredential',
  CANCEL_CREDENTIAL: 'cancelCredential',
  CANCEL_COMMAND: 'cancelCommand',
});

function abortError(signal) {
  if (signal?.reason instanceof Error) return signal.reason;
  const error = new Error(String(signal?.reason || 'Browser extension command aborted.'));
  error.name = 'AbortError';
  error.code = 'ABORT_ERR';
  return error;
}

function throwIfAborted(signal) {
  if (signal?.aborted) throw abortError(signal);
}

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

function waitForAbortable(promise, signal = null) {
  throwIfAborted(signal);
  if (!signal) return promise;
  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      signal.removeEventListener('abort', onAbort);
      callback(value);
    };
    const onAbort = () => finish(reject, abortError(signal));
    signal.addEventListener('abort', onAbort, { once: true });
    if (signal.aborted) onAbort();
    Promise.resolve(promise).then(
      (value) => finish(resolve, value),
      (error) => finish(reject, error),
    );
  });
}

async function optionalResult(promise, fallback, signal = null) {
  try {
    return await promise;
  } catch {
    throwIfAborted(signal);
    return fallback;
  }
}

function delay(ms, signal = null) {
  throwIfAborted(signal);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(timer);
      reject(abortError(signal));
    };
    signal?.addEventListener('abort', onAbort, { once: true });
    if (signal?.aborted) onAbort();
  });
}

function jsString(value) {
  return JSON.stringify(String(value ?? ''));
}

function buildIsolatedEvaluationExpression(script) {
  const source = String(script ?? 'undefined');
  // Keep each snippet inside its own function scope so repeated browser_evaluate
  // calls cannot collide on const/let declarations.
  return `(() => {\nreturn (${source});\n})()`;
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

function ipv4Octets(hostname) {
  if (!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(hostname)) return null;
  const parts = hostname.split('.').map(Number);
  return parts.every((part) => part >= 0 && part <= 255) ? parts : null;
}

export function isPrivateNetworkHostname(hostname) {
  const normalized = String(hostname || '')
    .toLowerCase()
    .replace(/^\[|\]$/g, '')
    .replace(/\.$/, '');
  if (!normalized) return true;
  if (
    normalized === 'localhost'
    || normalized === 'localhost.localdomain'
    || normalized.endsWith('.localhost')
    || normalized.endsWith('.local')
    || normalized.endsWith('.internal')
  ) {
    return true;
  }

  const octets = ipv4Octets(normalized);
  if (octets) {
    const [a, b, c] = octets;
    return a === 0
      || a === 10
      || a === 127
      || a >= 224
      || (a === 100 && b >= 64 && b <= 127)
      || (a === 169 && b === 254)
      || (a === 172 && b >= 16 && b <= 31)
      || (a === 192 && b === 168)
      || (a === 192 && b === 0 && c === 0)
      || (a === 192 && b === 0 && c === 2)
      || (a === 198 && (b === 18 || b === 19))
      || (a === 198 && b === 51 && c === 100)
      || (a === 203 && b === 0 && c === 113);
  }

  if (normalized.includes(':')) {
    if (normalized === '::' || normalized === '::1') return true;
    if (normalized.startsWith('::ffff:')) return true;
    const first = Number.parseInt(normalized.split(':').find(Boolean) || '0', 16);
    if (!Number.isFinite(first)) return true;
    if ((first & 0xfe00) === 0xfc00) return true;
    if ((first & 0xffc0) === 0xfe80) return true;
    if ((first & 0xffc0) === 0xfec0) return true;
    if ((first & 0xff00) === 0xff00) return true;
    if (normalized.startsWith('2001:db8:')) return true;
  }

  return false;
}

export function normalizeNetworkValidationUrl(value) {
  const raw = String(value || '');
  if (!raw || raw.length > 8192) return null;
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    return null;
  }
  if (!['http:', 'https:', 'ws:', 'wss:'].includes(parsed.protocol)) return null;
  if (parsed.username || parsed.password || isPrivateNetworkHostname(parsed.hostname)) return null;
  const protocol = parsed.protocol === 'ws:'
    ? 'http:'
    : (parsed.protocol === 'wss:' ? 'https:' : parsed.protocol);
  return `${protocol}//${parsed.host}/`;
}

const PAGE_ACCESS_COMMANDS = new Set([
  COMMANDS.LAUNCH,
  COMMANDS.CLICK,
  COMMANDS.CLICK_POINT,
  COMMANDS.TYPE,
  COMMANDS.TYPE_TEXT,
  COMMANDS.PRESS_KEY,
  COMMANDS.SCROLL,
  COMMANDS.EXTRACT,
  COMMANDS.EVALUATE,
  COMMANDS.SCREENSHOT,
  COMMANDS.GET_PAGE_INFO,
  COMMANDS.FILL_CREDENTIAL,
  COMMANDS.SUBMIT_CREDENTIAL,
  COMMANDS.CANCEL_CREDENTIAL,
]);

export function createBrowserProtocol(chromeApi, options = {}) {
  let attachedTabId = null;
  let activeTabId = null;
  let protectedCredentialFill = null;
  const pausedRequests = new Map();
  const maxPausedRequests = Math.max(1, Math.min(Number(options.maxPausedRequests) || 256, 1024));
  const validateUrl = typeof options.validateUrl === 'function'
    ? options.validateUrl
    : async () => false;

  const debuggee = () => ({ tabId: activeTabId });

  const call = (signal, namespace, method, ...args) => waitForAbortable(
    chromeCall(chromeApi, namespace, method, ...args),
    signal,
  );

  function abortPausedRequests(tabId, reason) {
    for (const entry of pausedRequests.values()) {
      if (entry.tabId === tabId && !entry.controller.signal.aborted) {
        entry.controller.abort(reason);
      }
    }
  }

  async function sendToTab(tabId, method, params = {}, signal = null) {
    try {
      return await call(signal, 'debugger', 'sendCommand', { tabId }, method, params);
    } catch (error) {
      if (
        tabId === attachedTabId
        && /not attached|no tab with given id|target closed/i.test(String(error?.message || ''))
      ) {
        attachedTabId = null;
      }
      throw error;
    }
  }

  async function isNetworkUrlAllowed(url, signal = null) {
    throwIfAborted(signal);
    const normalized = normalizeNetworkValidationUrl(url);
    if (!normalized) return false;
    const result = await validateUrl(normalized, { signal });
    throwIfAborted(signal);
    return result === true || result?.allowed === true;
  }

  async function handlePausedRequest(source, params) {
    const tabId = source?.tabId;
    const requestId = String(params?.requestId || '');
    if (tabId == null || tabId !== attachedTabId || !requestId) return;
    if (pausedRequests.size >= maxPausedRequests) {
      await sendToTab(tabId, 'Fetch.failRequest', {
        requestId,
        errorReason: 'BlockedByClient',
      }).catch(() => {});
      return;
    }

    const key = `${tabId}:${requestId}`;
    const previous = pausedRequests.get(key);
    previous?.controller.abort(new Error('Browser request interception was superseded.'));
    const controller = new AbortController();
    pausedRequests.set(key, { tabId, controller });
    let allowed = false;
    try {
      allowed = await isNetworkUrlAllowed(params?.request?.url, controller.signal);
    } catch {
      allowed = false;
    }
    try {
      await sendToTab(
        tabId,
        allowed ? 'Fetch.continueRequest' : 'Fetch.failRequest',
        allowed
          ? { requestId }
          : { requestId, errorReason: 'BlockedByClient' },
      );
    } catch {
      // Detach and tab-close races make the paused request disappear on their own.
    } finally {
      if (pausedRequests.get(key)?.controller === controller) pausedRequests.delete(key);
    }
  }

  chromeApi.debugger?.onEvent?.addListener?.((source, method, params) => {
    if (method !== 'Fetch.requestPaused') return;
    handlePausedRequest(source, params).catch(() => {});
  });
  chromeApi.debugger?.onDetach?.addListener?.((source) => {
    if (source?.tabId === attachedTabId) {
      abortPausedRequests(source.tabId, new Error('Browser debugger detached.'));
      attachedTabId = null;
    }
  });
  chromeApi.tabs?.onRemoved?.addListener?.((tabId) => {
    if (tabId === activeTabId) activeTabId = null;
    if (tabId === attachedTabId) {
      abortPausedRequests(tabId, new Error('Browser tab closed.'));
      attachedTabId = null;
    }
  });

  async function ensureTab(signal = null) {
    throwIfAborted(signal);
    if (activeTabId != null) {
      try {
        await call(signal, 'tabs', 'get', activeTabId);
        return activeTabId;
      } catch {
        throwIfAborted(signal);
        activeTabId = null;
      }
    }

    const tabs = await call(signal, 'tabs', 'query', { active: true, currentWindow: true });
    if (tabs && tabs[0]?.id != null) {
      activeTabId = tabs[0].id;
      return activeTabId;
    }
    const tab = await call(signal, 'tabs', 'create', { url: 'about:blank', active: true });
    activeTabId = tab.id;
    return activeTabId;
  }

  async function attach(signal = null) {
    await ensureTab(signal);
    if (attachedTabId === activeTabId) return;
    if (attachedTabId != null) {
      abortPausedRequests(attachedTabId, new Error('Browser control moved to another tab.'));
      await optionalResult(
        call(signal, 'debugger', 'detach', { tabId: attachedTabId }),
        undefined,
        signal,
      );
    }
    try {
      await call(signal, 'debugger', 'attach', debuggee(), '1.3');
    } catch (error) {
      throwIfAborted(signal);
      if (!/another debugger|already attached|debugger is already attached/i.test(error.message)) {
        throw error;
      }
    }
    attachedTabId = activeTabId;
    try {
      await sendToTab(attachedTabId, 'Fetch.enable', {
        patterns: [
          { urlPattern: 'http://*/*', requestStage: 'Request' },
          { urlPattern: 'https://*/*', requestStage: 'Request' },
          { urlPattern: 'ws://*/*', requestStage: 'Request' },
          { urlPattern: 'wss://*/*', requestStage: 'Request' },
        ],
      }, signal);
      await optionalResult(send('Page.enable', {}, signal), undefined, signal);
      await optionalResult(send('Runtime.enable', {}, signal), undefined, signal);
      await optionalResult(send('DOM.enable', {}, signal), undefined, signal);
    } catch (error) {
      const failedTabId = attachedTabId;
      abortPausedRequests(failedTabId, error);
      attachedTabId = null;
      if (failedTabId != null) {
        await chromeCall(chromeApi, 'debugger', 'detach', { tabId: failedTabId }).catch(() => {});
      }
      throw error;
    }
  }

  async function send(method, params = {}, signal = null) {
    const tabId = attachedTabId ?? activeTabId;
    if (tabId == null) throw new Error('No browser tab is available.');
    return sendToTab(tabId, method, params, signal);
  }

  async function evalJs(expression, options = {}, signal = null) {
    await attach(signal);
    const response = await send('Runtime.evaluate', {
      expression,
      awaitPromise: options.awaitPromise !== false,
      returnByValue: true,
    }, signal);
    if (response?.exceptionDetails) {
      throw new Error(response.exceptionDetails.text || 'JavaScript evaluation failed.');
    }
    return response?.result?.value;
  }

  async function waitForLoad(timeoutMs = 30000, signal = null) {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      throwIfAborted(signal);
      const ready = await optionalResult(
        evalJs(
          'document.readyState === "complete" || document.readyState === "interactive"',
          { awaitPromise: false },
          signal,
        ),
        false,
        signal,
      );
      if (ready) return;
      await delay(250, signal);
    }
    throw new Error(`Page did not finish loading within ${timeoutMs}ms.`);
  }

  async function markCurrentDocument(signal = null) {
    const key = `__neoagent_document_${crypto.randomUUID().replace(/-/g, '')}`;
    const token = crypto.randomUUID();
    const marked = await optionalResult(
      evalJs(
        `globalThis[${jsString(key)}] = ${jsString(token)}; true`,
        { awaitPromise: false },
        signal,
      ),
      false,
      signal,
    );
    return marked ? { key, token } : null;
  }

  async function waitForDocumentReplacement(marker, timeoutMs = 30000, signal = null) {
    if (!marker) {
      await delay(250, signal);
      return;
    }
    const started = Date.now();
    const expression = `globalThis[${jsString(marker.key)}] !== ${jsString(marker.token)}`;
    while (Date.now() - started < timeoutMs) {
      throwIfAborted(signal);
      const replaced = await optionalResult(
        evalJs(expression, { awaitPromise: false }, signal),
        false,
        signal,
      );
      if (replaced) return;
      await delay(100, signal);
    }
    throw new Error(`Page navigation did not commit within ${timeoutMs}ms.`);
  }

  async function assertNavigationSucceeded(signal = null) {
    const frameTree = await send('Page.getFrameTree', {}, signal);
    const unreachableUrl = String(frameTree?.frameTree?.frame?.unreachableUrl || '');
    if (unreachableUrl) {
      throw new Error('Browser navigation failed before the destination loaded.');
    }
    await assertCurrentPageAllowed(signal);
  }

  async function waitForSelector(selector, timeoutMs = 10000, signal = null) {
    if (!selector) return;
    const expression = `Boolean(document.querySelector(${jsString(selector)}))`;
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      throwIfAborted(signal);
      if (await optionalResult(evalJs(expression, { awaitPromise: false }, signal), false, signal)) return;
      await delay(200, signal);
    }
    throw new Error(`Element not found within ${timeoutMs}ms: ${selector}`);
  }

  async function currentTab(signal = null) {
    await ensureTab(signal);
    return call(signal, 'tabs', 'get', activeTabId);
  }

  async function assertCurrentPageAllowed(signal = null) {
    const tab = await currentTab(signal);
    const url = String(tab?.url || '');
    if (url === 'about:blank') return tab;
    if (!await isNetworkUrlAllowed(url, signal)) {
      throw new Error('The current browser page is not permitted.');
    }
    return tab;
  }

  async function screenshotDataUrl(options = {}, signal = null) {
    throwIfAborted(signal);
    await attach(signal);
    const capture = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: options.fullPage === true,
      fromSurface: true,
    }, signal);
    const encoded = String(capture?.data || '');
    if (encoded.length > 24 * 1024 * 1024) {
      throw new Error('Browser screenshot is too large to transfer. Try a viewport screenshot instead.');
    }
    return `data:image/png;base64,${encoded}`;
  }

  async function pageSnapshot(options = {}, signal = null) {
    throwIfAborted(signal);
    const tab = await currentTab(signal);
    const title = await optionalResult(
      evalJs('document.title || ""', { awaitPromise: false }, signal),
      tab.title || '',
      signal,
    );
    const bodyText = await optionalResult(evalJs(`(() => {
      const body = document.body;
      if (!body) return '';
      const clone = body.cloneNode(true);
      clone.querySelectorAll('script, style, noscript').forEach((node) => node.remove());
      return String(clone.innerText || '').slice(0, 10000);
    })()`, {}, signal), '', signal);
    const result = {
      title: title || tab.title || '',
      url: tab.url || '',
      status: 0,
      bodyText,
    };
    if (options.screenshot !== false) {
      result.screenshotDataUrl = await screenshotDataUrl(options, signal);
    }
    return result;
  }

  async function locateTarget(payload = {}, signal = null) {
    throwIfAborted(signal);
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
    const point = await evalJs(expression, {}, signal);
    if (!point || !Number.isFinite(Number(point.x)) || !Number.isFinite(Number(point.y))) {
      throw new Error(selector ? `Element not found: ${selector}` : `No clickable element found with text: ${payload.text}`);
    }
    return { x: Math.round(point.x), y: Math.round(point.y) };
  }

  async function clickPoint(x, y, signal = null) {
    throwIfAborted(signal);
    await attach(signal);
    const px = Math.max(0, normalizePointCoordinate(x, 'x'));
    const py = Math.max(0, normalizePointCoordinate(y, 'y'));
    await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: px, y: py }, signal);
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: px, y: py, button: 'left', clickCount: 1 }, signal);
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: px, y: py, button: 'left', clickCount: 1 }, signal);
    await delay(500, signal);
    return { x: px, y: py };
  }

  async function typeKey(key, signal = null) {
    await attach(signal);
    const normalized = String(key || '').trim();
    const code = keyCodeFor(normalized);
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: normalized, windowsVirtualKeyCode: code }, signal);
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: normalized, windowsVirtualKeyCode: code }, signal);
  }

  async function run(command, payload = {}, options = {}) {
    const signal = options.signal || null;
    throwIfAborted(signal);
    if (protectedCredentialFill?.expiresAt <= Date.now()) {
      const expired = protectedCredentialFill;
      await evalJs(`(() => {
        for (const selector of [${jsString(expired.usernameSelector)}, ${jsString(expired.passwordSelector)}].filter(Boolean)) {
          const el = document.querySelector(selector);
          if (el && 'value' in el) el.value = '';
        }
      })()`, {}, signal).catch(() => {});
      protectedCredentialFill = null;
    }
    if (
      protectedCredentialFill
      && ![
        COMMANDS.GET_PAGE_INFO,
        COMMANDS.SUBMIT_CREDENTIAL,
        COMMANDS.CANCEL_CREDENTIAL,
        COMMANDS.CLOSE,
      ].includes(command)
    ) {
      throw new Error('Browser control is paused while a protected credential fill is active. Submit or cancel it first.');
    }
    if (PAGE_ACCESS_COMMANDS.has(command)) {
      await assertCurrentPageAllowed(signal);
    }
    switch (command) {
      case COMMANDS.GET_COOKIES: {
        const domains = Array.isArray(payload.domains)
          ? payload.domains.map((item) => String(item || '').replace(/^\./, '').toLowerCase()).filter(Boolean)
          : [];
        if (domains.length === 0) throw new Error('At least one cookie domain is required.');
        if (domains.length > 50) throw new Error('At most 50 cookie domains may be requested.');
        const all = [];
        for (const domain of domains) {
          throwIfAborted(signal);
          const cookies = await call(signal, 'cookies', 'getAll', { domain });
          all.push(...(Array.isArray(cookies) ? cookies : []));
        }
        const seen = new Set();
        const filtered = all.filter((cookie) => {
          const cookieDomain = String(cookie?.domain || '').replace(/^\./, '').toLowerCase();
          const allowed = domains.some((domain) => cookieDomain === domain || cookieDomain.endsWith(`.${domain}`));
          if (!allowed) return false;
          const key = `${cookie.name}\n${cookie.domain}\n${cookie.path}`;
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });
        return {
          platform: String(payload.platform || ''),
          domains,
          cookies: filtered.map((cookie) => ({
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path,
            secure: cookie.secure === true,
            httpOnly: cookie.httpOnly === true,
            sameSite: cookie.sameSite || null,
            expirationDate: cookie.expirationDate || null,
          })),
        };
      }
      case COMMANDS.LAUNCH:
        await attach(signal);
        return pageSnapshot({ screenshot: false }, signal);
      case COMMANDS.NAVIGATE:
        if (!payload.url) throw new Error('url required');
        if (!await isNetworkUrlAllowed(payload.url, signal)) {
          throw new Error('This browser URL is not permitted.');
        }
        await attach(signal);
        {
          const marker = await markCurrentDocument(signal);
          let completed = false;
          try {
            const navigation = await send('Page.navigate', { url: String(payload.url) }, signal);
            if (navigation?.errorText) {
              throw new Error(`Browser navigation failed: ${navigation.errorText}`);
            }
            if (navigation?.isDownload === true) {
              throw new Error('Browser navigation started a download instead of loading a page.');
            }
            if (navigation?.loaderId) {
              await waitForDocumentReplacement(marker, 30000, signal);
            } else {
              await delay(100, signal);
            }
            await waitForLoad(30000, signal);
            await assertNavigationSucceeded(signal);
            await waitForSelector(payload.waitFor, 10000, signal);
            throwIfAborted(signal);
            completed = true;
            return pageSnapshot(payload, signal);
          } finally {
            if (!completed) await send('Page.stopLoading').catch(() => {});
          }
        }
      case COMMANDS.CLICK: {
        const point = await locateTarget(payload, signal);
        await clickPoint(point.x, point.y, signal);
        throwIfAborted(signal);
        return pageSnapshot({ screenshot: payload.screenshot !== false }, signal);
      }
      case COMMANDS.CLICK_POINT:
        await clickPoint(payload.x, payload.y, signal);
        throwIfAborted(signal);
        return pageSnapshot({ screenshot: payload.screenshot !== false }, signal);
      case COMMANDS.TYPE:
        if (!payload.selector) throw new Error('selector required');
        if (payload.clear !== false) {
          await evalJs(`(() => {
            const el = document.querySelector(${jsString(payload.selector)});
            if (!el) throw new Error(${jsString(`Element not found: ${payload.selector}`)});
            el.focus();
            if ('value' in el) el.value = '';
          })()`, {}, signal);
        } else {
          await evalJs(`document.querySelector(${jsString(payload.selector)})?.focus()`, {}, signal);
        }
        await send('Input.insertText', { text: String(payload.text || '') }, signal);
        throwIfAborted(signal);
        if (payload.pressEnter) await typeKey('Enter', signal);
        return pageSnapshot({ screenshot: payload.screenshot !== false }, signal);
      case COMMANDS.TYPE_TEXT:
        await attach(signal);
        await send('Input.insertText', { text: String(payload.text || '') }, signal);
        throwIfAborted(signal);
        if (payload.pressEnter) await typeKey('Enter', signal);
        return pageSnapshot({ screenshot: payload.screenshot !== false }, signal);
      case COMMANDS.FILL_CREDENTIAL: {
        if (protectedCredentialFill) throw new Error('A protected credential fill is already active.');
        const allowedOrigin = new URL(String(payload.allowedOrigin || '')).origin;
        const tab = await currentTab(signal);
        if (new URL(String(tab.url || '')).origin !== allowedOrigin) {
          throw new Error('The browser origin changed before credential fill.');
        }
        const usernameSelector = String(payload.usernameSelector || '').trim();
        const passwordSelector = String(payload.passwordSelector || '').trim();
        if (!usernameSelector && !passwordSelector) throw new Error('At least one credential field selector is required.');
        await attach(signal);
        const marker = await markCurrentDocument(signal);
        await send('Page.reload', {}, signal);
        await waitForDocumentReplacement(marker, 30000, signal);
        await waitForLoad(30000, signal);
        const reloaded = await currentTab(signal);
        if (new URL(String(reloaded.url || '')).origin !== allowedOrigin) {
          throw new Error('The browser origin changed while preparing credential fill.');
        }
        if (usernameSelector) {
          await waitForSelector(usernameSelector, 10000, signal);
          await evalJs(`(() => {
            const el = document.querySelector(${jsString(usernameSelector)});
            if (!el) throw new Error('Username field not found.');
            el.value = ${jsString(String(payload.username || ''))};
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          })()`, {}, signal);
        }
        if (passwordSelector) {
          await waitForSelector(passwordSelector, 10000, signal);
          await evalJs(`(() => {
            const el = document.querySelector(${jsString(passwordSelector)});
            if (!el) throw new Error('Password field not found.');
            el.value = ${jsString(String(payload.password || ''))};
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          })()`, {}, signal);
        }
        const protectedFillId = globalThis.crypto.randomUUID();
        protectedCredentialFill = {
          id: protectedFillId,
          allowedOrigin,
          usernameSelector,
          passwordSelector,
          submitSelector: passwordSelector || usernameSelector,
          expiresAt: Date.now() + 5 * 60 * 1000,
        };
        return { success: true, protectedFillId, origin: allowedOrigin };
      }
      case COMMANDS.SUBMIT_CREDENTIAL: {
        const fill = protectedCredentialFill;
        if (!fill || fill.id !== String(payload.protectedFillId || '')) {
          throw new Error('Protected credential fill is missing or expired.');
        }
        const tab = await currentTab(signal);
        if (new URL(String(tab.url || '')).origin !== fill.allowedOrigin) {
          protectedCredentialFill = null;
          throw new Error('The protected credential page changed before submission.');
        }
        try {
          await evalJs(`(() => {
            const el = document.querySelector(${jsString(fill.submitSelector)});
            if (!el) throw new Error('Credential field not found.');
            const form = el.form;
            if (form && typeof form.requestSubmit === 'function') form.requestSubmit();
            else el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
          })()`, {}, signal);
          await delay(500, signal);
          await waitForLoad(10000, signal).catch(() => {});
          const resultTab = await currentTab(signal);
          return {
            success: true,
            url: resultTab.url || null,
            title: resultTab.title || null,
            protected: false,
          };
        } finally {
          await evalJs(`(() => {
            for (const selector of [${jsString(fill.usernameSelector)}, ${jsString(fill.passwordSelector)}].filter(Boolean)) {
              const el = document.querySelector(selector);
              if (el && 'value' in el) el.value = '';
            }
          })()`, {}, signal).catch(() => {});
          protectedCredentialFill = null;
        }
      }
      case COMMANDS.CANCEL_CREDENTIAL: {
        const fill = protectedCredentialFill;
        if (!fill || fill.id !== String(payload.protectedFillId || '')) {
          throw new Error('Protected credential fill is missing or expired.');
        }
        await evalJs(`(() => {
          for (const selector of [${jsString(fill.usernameSelector)}, ${jsString(fill.passwordSelector)}].filter(Boolean)) {
            const el = document.querySelector(selector);
            if (el && 'value' in el) el.value = '';
          }
        })()`, {}, signal).catch(() => {});
        protectedCredentialFill = null;
        return { success: true, protected: false };
      }
      case COMMANDS.PRESS_KEY:
        await typeKey(payload.key, signal);
        throwIfAborted(signal);
        return pageSnapshot({ screenshot: payload.screenshot !== false }, signal);
      case COMMANDS.SCROLL:
        await evalJs(
          `window.scrollBy(${Math.round(Number(payload.deltaX) || 0)}, ${Math.round(Number(payload.deltaY) || 0)})`,
          {},
          signal,
        );
        await delay(250, signal);
        return pageSnapshot({ screenshot: payload.screenshot !== false }, signal);
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
          if (${payload.all === true}) {
            return { results: els.slice(0, 100).map((el) => String(read(el)).slice(0, 50000)) };
          }
          return { result: els[0] ? String(read(els[0])).slice(0, 50000) : '' };
        })()`;
        return evalJs(expression, {}, signal);
      }
      case COMMANDS.EVALUATE: {
        if (String(payload.script || '').length > 10000) {
          throw new Error('script exceeds maximum length (10000)');
        }
        const value = await evalJs(buildIsolatedEvaluationExpression(payload.script), {}, signal);
        throwIfAborted(signal);
        const serialized = typeof value === 'object' ? JSON.stringify(value) : String(value);
        const maxChars = 1024 * 1024;
        return {
          result: String(serialized ?? '').slice(0, maxChars),
          truncated: String(serialized ?? '').length > maxChars,
        };
      }
      case COMMANDS.SCREENSHOT:
        return { screenshotDataUrl: await screenshotDataUrl(payload, signal), fullPage: payload.fullPage === true };
      case COMMANDS.GET_PAGE_INFO: {
        const tab = await currentTab(signal);
        return {
          url: tab.url || null,
          title: tab.title || null,
          protectedCredentialFill: Boolean(protectedCredentialFill),
        };
      }
      case COMMANDS.CLOSE:
        if (protectedCredentialFill) {
          await evalJs(`(() => {
            for (const selector of [${jsString(protectedCredentialFill.usernameSelector)}, ${jsString(protectedCredentialFill.passwordSelector)}].filter(Boolean)) {
              const el = document.querySelector(selector);
              if (el && 'value' in el) el.value = '';
            }
          })()`, {}, signal).catch(() => {});
        }
        if (attachedTabId != null) {
          abortPausedRequests(attachedTabId, new Error('Browser control closed.'));
          await optionalResult(
            call(signal, 'debugger', 'detach', { tabId: attachedTabId }),
            undefined,
            signal,
          );
        }
        attachedTabId = null;
        protectedCredentialFill = null;
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
      handlePausedRequest,
      isNetworkUrlAllowed,
    },
  };
}
