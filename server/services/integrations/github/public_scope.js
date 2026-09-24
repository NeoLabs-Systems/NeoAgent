'use strict';

const { githubApiRequest } = require('./common');

// Rules for a run that answers a public GitHub thread. It may read the thread's
// repository, commit only to branches it owns (neoagent/*) or to the head
// branch of the pull request it was asked about, and open pull requests from
// its own branches. Argument checks catch the obvious cases; the request guard
// re-checks the final URL of every API call, so a crafted path argument still
// cannot reach another repository or a settings endpoint.

const API_ORIGIN = 'https://api.github.com';
const AGENT_BRANCH_PREFIX = 'neoagent/';
const READABLE_SECTIONS = new Set([
  'branches',
  'check-runs',
  'check-suites',
  'commits',
  'compare',
  'contents',
  'git',
  'issues',
  'labels',
  'languages',
  'milestones',
  'pulls',
  'readme',
  'releases',
  'statuses',
  'tags',
]);
const READABLE_ACTIONS_SECTIONS = new Set(['jobs', 'runs', 'workflows']);

function refuse(message) {
  const error = new Error(message);
  error.code = 'PUBLIC_SCOPE_REFUSED';
  return error;
}

function hasDotSegment(value) {
  return String(value || '').split('/').some((segment) => {
    let decoded = segment;
    try { decoded = decodeURIComponent(segment); } catch { return true; }
    return decoded === '..' || decoded === '.';
  });
}

function isAgentBranch(branch) {
  const name = String(branch || '').trim();
  return name.startsWith(AGENT_BRANCH_PREFIX)
    && name.length > AGENT_BRANCH_PREFIX.length
    && !name.includes(':')
    && !hasDotSegment(name);
}

function requestedRepo(args) {
  if (typeof args.owner_repo === 'string' && args.owner_repo.trim()) return args.owner_repo.trim();
  const owner = String(args.owner || '').trim();
  const repo = String(args.repo || '').trim();
  return owner && repo ? `${owner}/${repo}` : '';
}

function isReadablePath(rest) {
  const [section, subsection] = rest.split('/');
  if (section === 'actions') return READABLE_ACTIONS_SECTIONS.has(subsection);
  return READABLE_SECTIONS.has(section);
}

function buildRequestGuard(repo, allowedWrite) {
  const repoPath = `/repos/${repo}`.toLowerCase();
  return (method, url) => {
    const path = url.pathname.toLowerCase();
    if (url.origin !== API_ORIGIN || (path !== repoPath && !path.startsWith(`${repoPath}/`))) {
      throw refuse(`Only ${repo} can be reached from this thread.`);
    }
    if (method === 'GET') {
      if (path === repoPath || isReadablePath(path.slice(repoPath.length + 1))) return;
      throw refuse(`That part of ${repo} cannot be read from a public thread.`);
    }
    const allowed = allowedWrite
      && allowedWrite.method === method
      && (allowedWrite.prefix
        ? path.startsWith(allowedWrite.path.toLowerCase())
        : path === allowedWrite.path.toLowerCase());
    if (!allowed) {
      throw refuse(`This change to ${repo} is not allowed from a public thread.`);
    }
  };
}

// The thread's own pull request may be edited on its head branch when that
// branch lives in the same repository and is not the default branch.
async function assertWritableBranch(auth, scope, branch) {
  const name = String(branch || '').trim();
  if (!name) {
    throw refuse(`Name the branch to commit to: a new ${AGENT_BRANCH_PREFIX}* branch or this pull request's branch.`);
  }
  if (isAgentBranch(name)) return;
  if (scope.threadNumber) {
    let pr = null;
    try {
      pr = await githubApiRequest(auth, { path: `/repos/${scope.spaceId}/pulls/${scope.threadNumber}` });
    } catch (error) {
      if (error.status !== 404) throw error;
    }
    const headRepo = String(pr?.head?.repo?.full_name || '').toLowerCase();
    if (
      pr
      && headRepo === scope.spaceId.toLowerCase()
      && pr.head.ref === name
      && name !== pr.base?.repo?.default_branch
    ) {
      return;
    }
  }
  throw refuse(`From a public thread you can only commit to ${AGENT_BRANCH_PREFIX}* branches or to this pull request's own branch.`);
}

// Returns the arguments to run with and the guard every request must pass, or
// throws a refusal the model sees as the tool error.
async function preparePublicGithubCall(toolName, args, scope, auth) {
  const repo = scope.spaceId;
  const requested = requestedRepo(args);
  if (requested && requested.toLowerCase() !== repo.toLowerCase()) {
    throw refuse(`This thread belongs to ${repo}; other repositories are out of reach.`);
  }
  const next = { ...args, owner_repo: repo };
  delete next.owner;
  delete next.repo;
  delete next.connection_id;
  delete next.account_email;

  let allowedWrite = null;
  switch (toolName) {
    case 'github_get_content':
      if (hasDotSegment(next.path)) throw refuse('File paths cannot contain . or .. segments.');
      break;
    case 'github_create_or_update_file':
      if (hasDotSegment(next.path)) throw refuse('File paths cannot contain . or .. segments.');
      await assertWritableBranch(auth, scope, next.branch);
      allowedWrite = { method: 'PUT', path: `/repos/${repo}/contents/`, prefix: true };
      break;
    case 'github_create_pr':
      if (!isAgentBranch(next.head)) {
        throw refuse(`Pull requests from a public thread must come from a ${AGENT_BRANCH_PREFIX}* branch in ${repo}.`);
      }
      allowedWrite = { method: 'POST', path: `/repos/${repo}/pulls`, prefix: false };
      break;
    case 'github_api_request': {
      delete next.url;
      delete next.endpoint;
      const method = String(next.method || 'GET').toUpperCase();
      next.method = method;
      if (method !== 'GET') {
        const ref = String((next.body || next.payload || {}).ref || '');
        if (method !== 'POST' || !ref.startsWith('refs/heads/') || !isAgentBranch(ref.slice('refs/heads/'.length))) {
          throw refuse(`github_api_request can only read from a public thread, or create a ${AGENT_BRANCH_PREFIX}* branch via POST git/refs.`);
        }
        allowedWrite = { method: 'POST', path: `/repos/${repo}/git/refs`, prefix: false };
      }
      break;
    }
    default:
      break;
  }
  return { args: next, requestGuard: buildRequestGuard(repo, allowedWrite) };
}

module.exports = {
  preparePublicGithubCall,
};
