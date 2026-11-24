'use strict';

// Browser and credential broker tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'browser_navigate',
    egress: true,
    group: 'browser', access: 'read', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'slow', repeatable: true,
    capabilities: ['browser', 'web', 'page', 'open'],
    prerequisites: ['computer'],
    policy: { safe: true },
    whenToUse: ['the page needs a real browser: JavaScript, a login, or interaction'],
    whenNotToUse: ['a plain fetch of a known URL is enough (http_request)'],
    family: 'browser_page',
    description: 'Open a URL in the computer Chromium and return page content or a screenshot.',
    parameters: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'Full URL to navigate to, including the scheme (https://...)' },
        screenshot: { type: 'boolean', description: 'Take a screenshot (default true)' },
        waitFor: { type: 'string', description: 'CSS selector to wait for' },
        fullPage: { type: 'boolean', description: 'Full page screenshot (default false)' },
        referrerMode: { type: 'string', enum: ['direct', 'google', 'current'], description: 'Navigation referrer strategy for the VM browser (default direct). google sends a Google referrer; current navigates from the current page when possible.' },
        challengeRetry: { type: 'boolean', description: 'Retry once with a Google referrer if a known bot challenge is detected (default true).' }
      },
      required: ['url']
    }
  },
  {
    name: 'browser_click',
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'slow', repeatable: true,
    capabilities: ['browser', 'click', 'page'],
    prerequisites: ['computer'],
    family: 'browser_page',
    description: 'Click an element on the current page by CSS selector or visible text.',
    parameters: {
      type: 'object',
      properties: {
        selector: { type: 'string', description: 'CSS selector of element to click' },
        text: { type: 'string', description: 'Click element containing this text' },
        screenshot: { type: 'boolean', description: 'Screenshot after click (default true)' }
      }
    }
  },
  {
    name: 'browser_type',
    egress: true,
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'slow', repeatable: true,
    capabilities: ['browser', 'form', 'input', 'page'],
    prerequisites: ['computer'],
    family: 'browser_page',
    description: 'Type text into an input field on the current page.',
    parameters: {
      type: 'object',
      properties: {
        selector: { type: 'string', description: 'CSS selector of input' },
        text: { type: 'string', description: 'Text to type' },
        clear: { type: 'boolean', description: 'Clear field before typing (default true)' },
        pressEnter: { type: 'boolean', description: 'Press Enter after typing' }
      },
      required: ['selector', 'text']
    }
  },
  {
    name: 'browser_act',
    egress: true,
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'slow', repeatable: true,
    capabilities: ['browser', 'form', 'click', 'automation'],
    prerequisites: ['computer'],
    family: 'browser_page',
    description: 'Fast, accurate control of the web page for multi-step interaction: search boxes, forms, filters, menus, dropdowns, and date pickers. Give the goal for the page, with every value to enter, and optionally a URL to open first. A SystemOne model picks each click, field, and option from the visible controls in a fraction of a second. Prefer it over browser_click and browser_type for interactive steps. Returns the actions taken and the final page; confirm the result there before reporting it.',
    parameters: {
      type: 'object',
      properties: {
        goal: { type: 'string', description: 'What to accomplish on the page, including every value to enter, e.g. "Search one-way flights from Zurich to London on 20 September for 1 adult"' },
        url: { type: 'string', description: 'URL to open before starting (optional; defaults to the current page)' }
      },
      required: ['goal']
    }
  },
  {
    name: 'browser_extract',
    resultShape: 'page_extract',
    group: 'browser', access: 'read', stateScope: 'browser', latencyClass: 'local', repeatable: true,
    capabilities: ['browser', 'page', 'extract', 'scrape'],
    prerequisites: ['computer'],
    family: 'browser_page',
    description: 'Extract content from the current page.',
    parameters: {
      type: 'object',
      properties: {
        selector: { type: 'string', description: 'CSS selector to extract from (default body)' },
        attribute: { type: 'string', description: 'Attribute to extract (default innerText)' },
        all: { type: 'boolean', description: 'Extract from all matching elements' }
      }
    }
  },
  {
    name: 'browser_screenshot',
    group: 'browser', access: 'read', stateScope: 'browser', latencyClass: 'local', repeatable: true,
    capabilities: ['browser', 'screenshot', 'page'],
    prerequisites: ['computer'],
    policy: { safe: true },
    description: 'Take a screenshot of the current page',
    parameters: {
      type: 'object',
      properties: {
        fullPage: { type: 'boolean', description: 'Full page screenshot' },
        selector: { type: 'string', description: 'Screenshot specific element' }
      }
    }
  },
  {
    name: 'browser_evaluate',
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'local', repeatable: true,
    capabilities: ['browser', 'javascript'],
    prerequisites: ['computer'],
    policy: { category: 'browser_privileged' },
    description: 'Execute JavaScript in the browser page context',
    parameters: {
      type: 'object',
      properties: {
        script: { type: 'string', description: 'JavaScript to execute' }
      },
      required: ['script']
    }
  },
  {
    name: 'credential_fill_browser',
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'local', repeatable: true,
    capabilities: ['browser', 'credentials', 'login'],
    prerequisites: ['computer'],
    policy: { category: 'credential_use' },
    description: 'Fill a configured credential binding into the current HTTPS login page without revealing the username or password. This enters protected mode; call credential_submit_browser or credential_cancel_browser next.',
    parameters: {
      type: 'object',
      properties: {
        binding_id: { type: 'string', description: 'Opaque browser credential binding ID from the Bitwarden integration summary.' },
        stage: { type: 'string', enum: ['both', 'username', 'password'], description: 'Use username then password in separate protected fills for multi-step sign-in pages; default both.' },
        username_selector: { type: 'string', description: 'CSS selector for the username or email input. Required for both or username stage.' },
        password_selector: { type: 'string', description: 'CSS selector for the password input. Required for both or password stage.' }
      },
      required: ['binding_id']
    }
  },
  {
    name: 'credential_submit_browser',
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'local', repeatable: true,
    capabilities: ['browser', 'credentials', 'login'],
    prerequisites: ['computer'],
    description: 'Submit an active protected credential fill. Normal browser capabilities resume after this call.',
    parameters: {
      type: 'object',
      properties: {
        protected_fill_id: { type: 'string', description: 'Opaque protected fill ID returned by credential_fill_browser.' }
      },
      required: ['protected_fill_id']
    }
  },
  {
    name: 'credential_cancel_browser',
    group: 'browser', access: 'write', sideEffect: 'navigation', stateScope: 'browser', latencyClass: 'local', repeatable: true,
    capabilities: ['browser', 'credentials'],
    prerequisites: ['computer'],
    description: 'Clear and cancel an active protected credential fill. Normal browser capabilities resume after this call.',
    parameters: {
      type: 'object',
      properties: {
        protected_fill_id: { type: 'string', description: 'Opaque protected fill ID returned by credential_fill_browser.' }
      },
      required: ['protected_fill_id']
    }
  },
  {
    name: 'credential_http_request',
    group: 'web', access: 'write', sideEffect: 'external', stateScope: 'external', latencyClass: 'remote', repeatable: true,
    capabilities: ['http', 'api', 'credentials'],
    policy: { category: 'credential_use' },
    description: 'Make an HTTPS request through a configured credential binding. Authentication is injected by the host and never exposed; only the bounded origin, path prefix, and methods are allowed.',
    parameters: {
      type: 'object',
      properties: {
        binding_id: { type: 'string', description: 'Opaque HTTP credential binding ID from the Bitwarden integration summary.' },
        method: { type: 'string', enum: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'] },
        url: { type: 'string', description: 'Full HTTPS URL allowed by the binding.' },
        headers: { type: 'object', description: 'Optional non-authentication request headers.' },
        body: { type: 'string', description: 'Optional request body.' },
        timeout_ms: { type: 'number', description: 'Optional timeout from 1000 to 120000 milliseconds.' }
      },
      required: ['binding_id', 'method', 'url']
    }
  },
];
