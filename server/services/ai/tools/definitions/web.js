'use strict';

// Web search and HTTP tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'web_search',
    selection: 'default',
    egress: true,
    group: 'web', access: 'read', latencyClass: 'remote', repeatable: true,
    capabilities: ['search', 'web', 'internet', 'news', 'research'],
    policy: { safe: true },
    whenToUse: ['current or external facts you do not already have'],
    whenNotToUse: ['the answer is already in the conversation', 'the user gave the exact URL (open it instead)'],
    description: 'Search the public web without opening the browser. Uses Brave Search API for fast result retrieval.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search query to run' },
        count: { type: 'number', description: 'Maximum number of results to return (default 5, max 10)' },
        country: { type: 'string', description: 'Optional country code bias, e.g. "US", "DE", "GB"' },
        search_lang: { type: 'string', description: 'Optional search language code, e.g. "en", "de"' },
        freshness: { type: 'string', enum: ['pd', 'pw', 'pm', 'py'], description: 'Optional recency filter: past day, week, month, or year' }
      },
      required: ['query']
    }
  },
  {
    name: 'http_request',
    selection: 'default',
    egress: true,
    resultShape: 'http',
    group: 'web', access: 'dynamic_http_method', sideEffect: 'external', stateScope: 'external', latencyClass: 'remote', repeatable: true,
    capabilities: ['http', 'api', 'fetch', 'url', 'download'],
    policy: { category: 'network_write' },
    whenToUse: ['fetch a known URL or call an API'],
    whenNotToUse: ['the page needs JavaScript, a login, or clicks (browser tools)'],
    description: 'Make an HTTP request to any URL',
    parameters: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'Request URL' },
        method: { type: 'string', enum: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'], description: 'HTTP method' },
        headers: { type: 'object', description: 'Request headers' },
        body: { type: 'string', description: 'Request body (JSON string)' },
        timeout_ms: { type: 'number', description: 'Request timeout in milliseconds (default 30000)' }
      },
      required: ['url']
    }
  },
];
