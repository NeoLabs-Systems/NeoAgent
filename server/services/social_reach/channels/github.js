'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');
const { assertHttpUrl, fetchJson, normalizeLimit } = require('../utils');

function parseRepoUrl(url) {
  const parsed = assertHttpUrl(url);
  const parts = parsed.pathname.split('/').filter(Boolean);
  if (parsed.hostname.replace(/^www\./, '') !== 'github.com' || parts.length < 2) {
    const error = new Error('A GitHub repository URL is required.');
    error.status = 400;
    throw error;
  }
  return { owner: parts[0], repo: parts[1].replace(/\.git$/, '') };
}

class GithubChannel extends SocialReachChannel {
  constructor() {
    super(getPlatformDefinition('github'));
  }

  async check() {
    return {
      ...(await super.check()),
      activeBackend: 'github_rest_public',
      message: 'Public GitHub repository read/search is available through the GitHub REST API.',
    };
  }

  async read({ url }) {
    const { owner, repo } = parseRepoUrl(url);
    const data = await fetchJson(`https://api.github.com/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`);
    return {
      platform: this.id,
      owner,
      repo,
      title: data.full_name || `${owner}/${repo}`,
      description: data.description || '',
      url: data.html_url || `https://github.com/${owner}/${repo}`,
      stars: data.stargazers_count || 0,
      forks: data.forks_count || 0,
      openIssues: data.open_issues_count || 0,
      language: data.language || null,
      defaultBranch: data.default_branch || null,
      source: 'github_rest_public',
    };
  }

  async search({ query, limit }) {
    const q = String(query || '').trim();
    if (!q) {
      const error = new Error('query is required.');
      error.status = 400;
      throw error;
    }
    const data = await fetchJson(`https://api.github.com/search/repositories?q=${encodeURIComponent(q)}&per_page=${normalizeLimit(limit, 10, 30)}`);
    return {
      platform: this.id,
      query: q,
      results: (data.items || []).map((item) => ({
        name: item.full_name,
        description: item.description || '',
        url: item.html_url,
        stars: item.stargazers_count || 0,
        language: item.language || null,
      })),
      source: 'github_rest_public',
    };
  }
}

module.exports = {
  GithubChannel,
};
