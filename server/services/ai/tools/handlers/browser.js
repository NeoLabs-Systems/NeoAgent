'use strict';

const { validateCloudUrlWithDns } = require('../../../../utils/cloud-security');
const { runBrowserAct } = require('../../integrated_tools/browser_act');
const { isSystemOneReady } = require('../../system_one');

const handlers = {
  async browser_navigate(args, ctx) {
    const { bc, signal } = ctx;
    const urlCheck = await validateCloudUrlWithDns(args.url, { signal });
    if (!urlCheck.allowed) return { error: urlCheck.reason, url: args.url };
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    return { ...await provider.navigate(args.url, {
    screenshot: args.screenshot !== false,
    waitFor: args.waitFor,
    fullPage: args.fullPage,
    referrerMode: args.referrerMode,
    challengeRetry: args.challengeRetry,
    signal,
    }), backend };
  },

  async browser_click(args, ctx) {
    const { bc, signal } = ctx;
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    return { ...await provider.click(args.selector, args.text, args.screenshot !== false, { signal }), backend };
  },

  async browser_type(args, ctx) {
    const { bc, signal } = ctx;
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    return { ...await provider.type(args.selector, args.text, {
    clear: args.clear !== false,
    pressEnter: args.pressEnter,
    signal,
    }), backend };
  },

  async browser_act(args, ctx) {
    const { agentId, bc, engine, runId, signal, stepId, userId } = ctx;
    const goal = typeof args.goal === 'string' ? args.goal.trim() : '';
    if (!goal) return { error: 'browser_act requires a "goal" argument' };
    if (!(await isSystemOneReady(userId, agentId, signal))) {
    return { error: 'browser_act needs a SystemOne model, and none is available for this agent. Use browser_click and browser_type instead.' };
    }
    if (args.url) {
    const urlCheck = await validateCloudUrlWithDns(args.url, { signal });
    if (!urlCheck.allowed) return { error: urlCheck.reason, url: args.url };
    }
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    if (backend === 'local-computer') {
    return { error: 'browser_act needs the cloud computer browser. Use browser_navigate and the desktop tools on this computer.', backend };
    }
    return {
    ...await runBrowserAct({
      provider,
      engine,
      goal,
      url: args.url || null,
      userId,
      agentId,
      runId,
      stepId,
      signal,
    }),
    backend,
    };
  },

  async browser_extract(args, ctx) {
    const { bc, signal } = ctx;
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    return { ...await provider.extract(args.selector, args.attribute, args.all, { signal }), backend };
  },

  async browser_screenshot(args, ctx) {
    const { bc, signal } = ctx;
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    return { ...await provider.screenshot({ fullPage: args.fullPage, selector: args.selector, signal }), backend };
  },

  async browser_evaluate(args, ctx) {
    const { bc, signal } = ctx;
    const { provider, backend } = await bc();
    if (!provider) return { error: 'Browser controller not available' };
    const script = args.script ?? args.javascript;
    if (!script) return { error: 'browser_evaluate requires a "script" argument' };
    return { ...await provider.evaluate(script, { signal }), backend };
  },

  async credential_fill_browser(args, ctx) {
    const { agentId, credentials, runId, signal, userId } = ctx;
    const broker = credentials();
    if (!broker) return { error: 'Credential broker is unavailable.' };
    return broker.fillBrowser(userId, agentId, args, { runId, signal });
  },

  async credential_submit_browser(args, ctx) {
    const { agentId, credentials, runId, signal, userId } = ctx;
    const broker = credentials();
    if (!broker) return { error: 'Credential broker is unavailable.' };
    return broker.submitProtected(userId, agentId, args.protected_fill_id, { runId, signal });
  },

  async credential_cancel_browser(args, ctx) {
    const { agentId, credentials, runId, signal, userId } = ctx;
    const broker = credentials();
    if (!broker) return { error: 'Credential broker is unavailable.' };
    return broker.cancelProtected(userId, agentId, args.protected_fill_id, { runId, signal });
  },

  async credential_http_request(args, ctx) {
    const { agentId, credentials, runId, signal, userId } = ctx;
    const broker = credentials();
    if (!broker) return { error: 'Credential broker is unavailable.' };
    return broker.httpRequest(userId, agentId, args, { runId, signal });
  },
};

module.exports = { handlers };
