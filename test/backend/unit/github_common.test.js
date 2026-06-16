'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  base64UrlSha256,
  buildPaginationParams,
  githubApiRequest,
  parseOwnerRepo,
} = require('../../../server/services/integrations/github/common');
const { executeGithubTool } = require('../../../server/services/integrations/github/repos');

const originalFetch = global.fetch;
const originalAllowedHosts = process.env.GITHUB_ALLOWED_API_HOSTS;

function createResponse({ ok = true, status = 200, body = '', statusText = 'OK' } = {}) {
  return {
    ok,
    status,
    statusText,
    async text() {
      return body;
    },
  };
}

function stubFetch(implementation) {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return implementation(url, options);
  };
  return calls;
}

afterEach(() => {
  global.fetch = originalFetch;
  if (originalAllowedHosts === undefined) {
    delete process.env.GITHUB_ALLOWED_API_HOSTS;
  } else {
    process.env.GITHUB_ALLOWED_API_HOSTS = originalAllowedHosts;
  }
});

test('githubApiRequest sends auth headers, query params, and JSON body', async () => {
  const calls = stubFetch(async () =>
    createResponse({
      body: JSON.stringify({ ok: true, id: 7 }),
    }),
  );

  const result = await githubApiRequest(
    { token: 'token-123' },
    {
      method: 'POST',
      path: '/repos/neo/agent/issues',
      query: { page: 2, labels: 'bug' },
      body: { title: 'Synthetic issue' },
    },
  );

  assert.deepEqual(result, { ok: true, id: 7 });
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    'https://api.github.com/repos/neo/agent/issues?page=2&labels=bug',
  );
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.headers.Accept, 'application/vnd.github.v3+json');
  assert.equal(calls[0].options.headers.Authorization, 'Bearer token-123');
  assert.equal(calls[0].options.headers['X-GitHub-Api-Version'], '2022-11-28');
  assert.equal(calls[0].options.headers['Content-Type'], 'application/json');
  assert.equal(calls[0].options.body, JSON.stringify({ title: 'Synthetic issue' }));
});

test('githubApiRequest returns null for empty 204 and 205 responses', async () => {
  for (const status of [204, 205]) {
    const calls = stubFetch(async () => createResponse({ status, body: 'ignored' }));
    const result = await githubApiRequest(
      { token: 'token-123' },
      { path: '/user' },
    );

    assert.equal(result, null);
    assert.equal(calls.length, 1);
  }
});

test('githubApiRequest throws with the API message for JSON error responses', async () => {
  stubFetch(async () =>
    createResponse({
      ok: false,
      status: 403,
      statusText: 'Forbidden',
      body: JSON.stringify({ message: 'rate limit exceeded' }),
    }),
  );

  await assert.rejects(
    githubApiRequest({ token: 'token-123' }, { path: '/user' }),
    (error) => {
      assert.equal(error.message, 'rate limit exceeded');
      assert.equal(error.status, 403);
      assert.deepEqual(error.data, { message: 'rate limit exceeded' });
      return true;
    },
  );
});

test('githubApiRequest throws with raw text for non-JSON failure responses', async () => {
  stubFetch(async () =>
    createResponse({
      ok: false,
      status: 502,
      statusText: 'Bad Gateway',
      body: 'upstream unavailable',
    }),
  );

  await assert.rejects(
    githubApiRequest({ token: 'token-123' }, { path: '/user' }),
    (error) => {
      assert.equal(error.message, 'GitHub API error 502: upstream unavailable');
      assert.equal(error.status, 502);
      assert.equal(error.data, 'upstream unavailable');
      return true;
    },
  );
});

test('githubApiRequest rejects requests without an authentication token', async () => {
  let fetchCalled = false;
  global.fetch = async () => {
    fetchCalled = true;
    return createResponse();
  };

  await assert.rejects(
    githubApiRequest({}, { path: '/user' }),
    /GitHub authentication token is required/,
  );
  assert.equal(fetchCalled, false);
});

test('buildPaginationParams normalizes page values and caps per_page at 100', () => {
  assert.deepEqual(buildPaginationParams({ page: '2', per_page: '150' }), {
    page: 2,
    per_page: 100,
  });
  assert.deepEqual(buildPaginationParams({ page: 0, per_page: 0 }), {});
  assert.deepEqual(buildPaginationParams({ per_page: '25' }), { per_page: 25 });
});

test('parseOwnerRepo accepts owner/repo and rejects invalid formats', () => {
  assert.deepEqual(parseOwnerRepo('NeoLabs-Systems/NeoAgent'), {
    owner: 'NeoLabs-Systems',
    repo: 'NeoAgent',
  });
  assert.throws(() => parseOwnerRepo('NeoLabs-Systems'), /owner_repo must be in format/);
  assert.throws(() => parseOwnerRepo('NeoLabs-Systems/NeoAgent/extra'), /owner_repo must be in format/);
});

test('base64UrlSha256 returns a stable PKCE-safe digest', () => {
  const digest = base64UrlSha256('code-verifier');
  assert.equal(digest, 'qdgLLRr1saFHT6DWfWU28VNPIi7e9ynEBnBG3Oadw9g');
  assert.doesNotMatch(digest, /[+/=]/);
});

test('github_api_request accepts a full GitHub API URL and merges query params', async () => {
  const calls = stubFetch(async () =>
    createResponse({
      body: JSON.stringify([{ id: 1 }]),
    }),
  );

  const result = await executeGithubTool(
    'github_api_request',
    {
      method: 'GET',
      path: 'https://api.github.com/user/repos?per_page=2&page=1',
      query: { page: 4, visibility: 'private' },
    },
    { token: 'token-123' },
  );

  assert.deepEqual(result, [{ id: 1 }]);
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    'https://api.github.com/user/repos?per_page=2&page=4&visibility=private',
  );
});

test('github_api_request accepts endpoint alias without falling back to API root', async () => {
  const calls = stubFetch(async () =>
    createResponse({
      body: JSON.stringify([{ number: 91 }]),
    }),
  );

  const result = await executeGithubTool(
    'github_api_request',
    {
      method: 'GET',
      endpoint: '/repos/NeoLabs-Systems/NeoAgent/issues?state=open&per_page=30',
    },
    { token: 'token-123' },
  );

  assert.deepEqual(result, [{ number: 91 }]);
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    'https://api.github.com/repos/NeoLabs-Systems/NeoAgent/issues?state=open&per_page=30',
  );
});

test('github_api_request rejects missing path aliases before making a request', async () => {
  let fetchCalled = false;
  global.fetch = async () => {
    fetchCalled = true;
    return createResponse();
  };

  await assert.rejects(
    executeGithubTool(
      'github_api_request',
      {
        method: 'GET',
      },
      { token: 'token-123' },
    ),
    /requires path, endpoint, or url/,
  );
  assert.equal(fetchCalled, false);
});

test('github_api_request rejects non-HTTPS URLs before making a request', async () => {
  let fetchCalled = false;
  global.fetch = async () => {
    fetchCalled = true;
    return createResponse();
  };

  await assert.rejects(
    executeGithubTool(
      'github_api_request',
      {
        method: 'GET',
        path: 'http://api.github.com/user',
      },
      { token: 'token-123' },
    ),
    /Only https:\/\/ GitHub API URLs are allowed/,
  );
  assert.equal(fetchCalled, false);
});

test('github_api_request rejects non-GitHub hosts before making a request', async () => {
  let fetchCalled = false;
  global.fetch = async () => {
    fetchCalled = true;
    return createResponse();
  };

  await assert.rejects(
    executeGithubTool(
      'github_api_request',
      {
        method: 'GET',
        path: 'https://example.com/user',
      },
      { token: 'token-123' },
    ),
    /Host is not allowed for GitHub API requests: example\.com/,
  );
  assert.equal(fetchCalled, false);
});
