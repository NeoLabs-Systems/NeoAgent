'use strict';

const { isAbortError } = require('../../../../utils/abort');
const { fetchResponseText } = require('../../../network/http');
const { executeHttpRequest } = require('../../integrated_tools/http_request');
const { forRole: forNeoRouterRole } = require('../../neorouter/connection');
const neorouter = require('../../neorouter/client');

const handlers = {
  async web_search(args, ctx) {
    const { agentId, signal, userId } = ctx;
    const router = forNeoRouterRole(userId, agentId, 'search');
    if (router) {
    try {
      const limit = Math.max(1, Math.min(Number(args.count) || 5, 10));
      const results = await neorouter.searchWeb(router, { query: args.query, count: limit, freshness: args.freshness, signal });
      return { query: args.query, count: results.length, results };
    } catch (err) {
      if (isAbortError(err, signal)) throw err;
      return { error: err.message };
    }
    }
    const apiKey = process.env.BRAVE_SEARCH_API_KEY;
    if (!apiKey) return { error: 'BRAVE_SEARCH_API_KEY is not configured' };

    const timeoutMs = 20000;

    try {
    const limit = Math.max(1, Math.min(Number(args.count) || 5, 10));
    const params = new URLSearchParams({
      q: args.query,
      count: String(limit),
      text_decorations: 'false',
      result_filter: 'web'
    });

    if (args.country) params.set('country', String(args.country).toUpperCase());
    if (args.search_lang) params.set('search_lang', String(args.search_lang).toLowerCase());
    if (args.freshness) params.set('freshness', args.freshness);

    const { response, text } = await fetchResponseText(
     `https://api.search.brave.com/res/v1/web/search?${params.toString()}`,
     {
      headers: {
        Accept: 'application/json',
        'X-Subscription-Token': apiKey
      },
      maxResponseBytes: 2 * 1024 * 1024,
      serviceName: 'Brave Search',
      signal,
      timeoutMs,
     },
    );

    let data = null;
    try {
      data = JSON.parse(text);
    } catch {
      data = null;
    }

    if (!response.ok) {
      return {
        error: `Brave Search API request failed with status ${response.status}`,
        details: data || text.slice(0, 1000)
      };
    }

    const rawResults = Array.isArray(data?.web?.results) ? data.web.results : [];
    const results = rawResults.slice(0, limit).map((item, index) => ({
      rank: index + 1,
      title: item.title || '',
      url: item.url || '',
      description: item.description || '',
      age: item.age || null,
      language: item.language || null,
      profile: item.profile?.long_name || item.profile?.name || null
    }));

    return {
      query: args.query,
      count: results.length,
      results
    };
    } catch (err) {
    if (isAbortError(err, signal)) throw err;
    if (err.code === 'HTTP_TIMEOUT') {
      return { error: `Brave Search API request timed out after ${timeoutMs}ms` };
    }
    return { error: err.message };
    }
  },

  async http_request(args, ctx) {
    const { signal } = ctx;
    try {
    return await executeHttpRequest(args, {
      allowPrivate: process.env.NEOAGENT_HTTP_ALLOW_PRIVATE === 'true',
      signal,
    });
    } catch (err) {
    if (isAbortError(err, signal)) throw err;
    return { error: err.message };
    }
  },
};

module.exports = { handlers };
