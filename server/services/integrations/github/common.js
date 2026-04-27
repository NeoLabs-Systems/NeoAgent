'use strict';

const crypto = require('crypto');

function base64UrlSha256(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || ''))
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

async function githubApiRequest(auth, options = {}) {
  const {
    method = 'GET',
    path,
    query = null,
    body = null,
    baseUrl = 'https://api.github.com',
    token: overrideToken = '',
  } = options;

  const token = String(overrideToken || auth?.token || '').trim();
  if (!token) {
    throw new Error('GitHub authentication token is required for GitHub API requests.');
  }

  const url = new URL(path, baseUrl);
  if (query && typeof query === 'object') {
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== null) {
        url.searchParams.set(key, String(value));
      }
    }
  }

  const headers = {
    'Accept': 'application/vnd.github.v3+json',
    'Authorization': `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
  };

  if (body && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
    headers['Content-Type'] = 'application/json';
  }

  const response = await fetch(url.toString(), {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  let data = null;
  if (response.status !== 204 && response.status !== 205) {
    const rawBody = await response.text();
    if (rawBody.trim()) {
      try {
        data = JSON.parse(rawBody);
      } catch {
        if (!response.ok) {
          const error = new Error(`GitHub API error ${response.status}: ${rawBody}`);
          error.status = response.status;
          error.data = rawBody;
          throw error;
        }
        data = rawBody;
      }
    }
  }

  if (!response.ok) {
    const errorMessage =
      (data && typeof data === 'object' ? data.message : null) ||
      `GitHub API error: ${response.status}`;
    const error = new Error(errorMessage);
    error.status = response.status;
    error.data = data;
    throw error;
  }

  return data;
}

function buildPaginationParams(options = {}) {
  const params = {};
  if (options.page) params.page = Number(options.page);
  if (options.per_page) params.per_page = Math.min(Number(options.per_page) || 30, 100);
  return params;
}

function parseOwnerRepo(ownerRepo) {
  const parts = String(ownerRepo || '').split('/');
  if (parts.length !== 2) {
    throw new Error('owner_repo must be in format "owner/repo"');
  }
  return { owner: parts[0], repo: parts[1] };
}

module.exports = {
  base64UrlSha256,
  buildPaginationParams,
  githubApiRequest,
  parseOwnerRepo,
};