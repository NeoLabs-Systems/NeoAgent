'use strict';

const { URL } = require('node:url');

class NeoAgentHttpClient {
  constructor(baseUrl) {
    this.baseUrl = String(baseUrl || '').replace(/\/+$/, '');
    this.cookies = new Map();
  }

  #applyCookies(response) {
    const headers = response.headers;
    const setCookie = typeof headers.getSetCookie === 'function'
      ? headers.getSetCookie()
      : (headers.get('set-cookie') ? [headers.get('set-cookie')] : []);
    for (const rawCookie of setCookie) {
      const [pair] = String(rawCookie || '').split(';');
      const [name, value] = pair.split('=');
      if (!name || value == null) continue;
      this.cookies.set(name.trim(), value.trim());
    }
  }

  #cookieHeader() {
    return [...this.cookies.entries()]
      .map(([name, value]) => `${name}=${value}`)
      .join('; ');
  }

  async request(method, pathname, options = {}) {
    const url = new URL(pathname, `${this.baseUrl}/`);
    if (options.query && typeof options.query === 'object') {
      for (const [key, value] of Object.entries(options.query)) {
        if (value == null || value === '') continue;
        url.searchParams.set(key, String(value));
      }
    }

    const headers = {
      Accept: 'application/json',
      ...(options.json !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(options.headers || {}),
    };
    const cookie = this.#cookieHeader();
    if (cookie) headers.Cookie = cookie;

    const response = await fetch(url, {
      method,
      headers,
      body: options.json !== undefined ? JSON.stringify(options.json) : undefined,
    });
    this.#applyCookies(response);

    const contentType = String(response.headers.get('content-type') || '');
    const body = contentType.includes('application/json')
      ? await response.json().catch(() => ({}))
      : await response.text();
    if (!response.ok) {
      const message = typeof body === 'string'
        ? body
        : body?.error || body?.message || `${method} ${pathname} failed`;
      const error = new Error(message);
      error.statusCode = response.status;
      error.body = body;
      throw error;
    }
    return body;
  }

  async ensureAuthenticated(auth) {
    try {
      await this.login(auth);
      return { mode: 'login' };
    } catch (error) {
      if (![401, 404].includes(Number(error.statusCode || 0))) throw error;
    }
    await this.register(auth);
    return { mode: 'register' };
  }

  async register(auth) {
    return this.request('POST', '/api/auth/register', {
      json: {
        username: auth.username,
        password: auth.password,
        email: auth.email,
      },
    });
  }

  async login(auth) {
    return this.request('POST', '/api/auth/login', {
      json: {
        username: auth.username,
        password: auth.password,
      },
    });
  }

  async getSupportedModels() {
    const response = await this.request('GET', '/api/settings/meta/models');
    return Array.isArray(response?.models) ? response.models : [];
  }

  async putSettings(values) {
    return this.request('PUT', '/api/settings', { json: values });
  }

  async runAgentTask(task, options = {}) {
    return this.request('POST', '/api/agents', {
      json: {
        task,
        options,
      },
    });
  }

  async recallMemories(query, limit) {
    return this.request('POST', '/api/memory/memories/recall', {
      json: { query, limit },
    });
  }

  async ingestDocuments(documents, options = {}) {
    return this.request('POST', '/api/memory/ingestion/documents', {
      json: {
        documents,
        sourceType: options.sourceType,
        metadata: options.metadata,
      },
    });
  }

  async getIngestionStatus() {
    return this.request('GET', '/api/memory/ingestion/status');
  }
}

module.exports = {
  NeoAgentHttpClient,
};
