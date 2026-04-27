'use strict';

const {
  githubApiRequest,
  buildPaginationParams,
  parseOwnerRepo,
} = require('./common');

const ISSUE_STATES = ['open', 'closed', 'all'];
const PR_STATES = ['open', 'closed', 'all'];
const SORT_OPTIONS = ['created', 'updated', 'comments'];
const DIRECTION_OPTIONS = ['asc', 'desc'];
const DEFAULT_GITHUB_API_HOST = 'api.github.com';

function parsePositiveInt(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function getAllowedGithubApiHosts() {
  const envHosts = String(process.env.GITHUB_ALLOWED_API_HOSTS || '')
    .split(',')
    .map((host) => host.trim().toLowerCase())
    .filter(Boolean);
  return new Set([DEFAULT_GITHUB_API_HOST, ...envHosts]);
}

function isAllowedGithubApiHost(hostname) {
  const host = String(hostname || '').trim().toLowerCase();
  if (!host) return false;
  return getAllowedGithubApiHosts().has(host);
}

const githubToolDefinitions = [
  {
    name: 'github_search_repos',
    access: 'read',
    description: 'Search GitHub repositories by keyword.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search query (e.g. "language:javascript stars:>100").',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 10, max 100).',
        },
      },
      required: ['query'],
    },
  },
  {
    name: 'github_get_repo',
    access: 'read',
    description: 'Get details about a specific GitHub repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_list_issues',
    access: 'read',
    description: 'List issues in a GitHub repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        state: {
          type: 'string',
          enum: ISSUE_STATES,
          description: 'Issue state filter (default open).',
        },
        labels: {
          type: 'string',
          description: 'Comma-separated label names to filter by.',
        },
        assignee: {
          type: 'string',
          description: 'Filter by assignee username (use @me for self).',
        },
        sort: {
          type: 'string',
          enum: SORT_OPTIONS,
          description: 'Sort field (default created).',
        },
        direction: {
          type: 'string',
          enum: DIRECTION_OPTIONS,
          description: 'Sort direction (default desc).',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_get_issue',
    access: 'read',
    description: 'Get details about a specific GitHub issue.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        issue_number: {
          type: 'number',
          description: 'Issue number.',
        },
      },
      required: ['owner_repo', 'issue_number'],
    },
  },
  {
    name: 'github_create_issue',
    access: 'write',
    description: 'Create a new GitHub issue.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        title: {
          type: 'string',
          description: 'Issue title.',
        },
        body: {
          type: 'string',
          description: 'Issue body/description.',
        },
        labels: {
          type: 'string',
          description: 'Comma-separated label names.',
        },
        assignees: {
          type: 'string',
          description: 'Comma-separated usernames to assign.',
        },
      },
      required: ['owner_repo', 'title'],
    },
  },
  {
    name: 'github_update_issue',
    access: 'write',
    description: 'Update an existing GitHub issue.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        issue_number: {
          type: 'number',
          description: 'Issue number.',
        },
        title: {
          type: 'string',
          description: 'New issue title.',
        },
        body: {
          type: 'string',
          description: 'New issue body.',
        },
        state: {
          type: 'string',
          enum: ['open', 'closed'],
          description: 'New issue state.',
        },
        labels: {
          type: 'string',
          description: 'Comma-separated label names (replaces existing).',
        },
        assignees: {
          type: 'string',
          description: 'Comma-separated usernames (replaces existing).',
        },
      },
      required: ['owner_repo', 'issue_number'],
    },
  },
  {
    name: 'github_add_issue_labels',
    access: 'write',
    description: 'Add labels to a GitHub issue.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        issue_number: {
          type: 'number',
          description: 'Issue number.',
        },
        labels: {
          type: 'string',
          description: 'Comma-separated label names to add.',
        },
      },
      required: ['owner_repo', 'issue_number', 'labels'],
    },
  },
  {
    name: 'github_add_issue_assignees',
    access: 'write',
    description: 'Add assignees to a GitHub issue.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        issue_number: {
          type: 'number',
          description: 'Issue number.',
        },
        assignees: {
          type: 'string',
          description: 'Comma-separated usernames to add.',
        },
      },
      required: ['owner_repo', 'issue_number', 'assignees'],
    },
  },
  {
    name: 'github_list_prs',
    access: 'read',
    description: 'List pull requests in a GitHub repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        state: {
          type: 'string',
          enum: PR_STATES,
          description: 'PR state filter (default open).',
        },
        sort: {
          type: 'string',
          enum: SORT_OPTIONS,
          description: 'Sort field (default created).',
        },
        direction: {
          type: 'string',
          enum: DIRECTION_OPTIONS,
          description: 'Sort direction (default desc).',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_get_pr',
    access: 'read',
    description: 'Get details about a specific pull request.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        pr_number: {
          type: 'number',
          description: 'Pull request number.',
        },
      },
      required: ['owner_repo', 'pr_number'],
    },
  },
  {
    name: 'github_create_pr',
    access: 'write',
    description: 'Create a new pull request.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        title: {
          type: 'string',
          description: 'PR title.',
        },
        body: {
          type: 'string',
          description: 'PR body/description.',
        },
        head: {
          type: 'string',
          description: 'Branch name containing the changes.',
        },
        base: {
          type: 'string',
          description: 'Base branch to merge into (default main).',
        },
        draft: {
          type: 'boolean',
          description: 'Create as draft PR.',
        },
        maintainer_can_modify: {
          type: 'boolean',
          description: 'Allow maintainers to push to your branch.',
        },
      },
      required: ['owner_repo', 'title', 'head'],
    },
  },
  {
    name: 'github_update_pr',
    access: 'write',
    description: 'Update an existing pull request.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        pr_number: {
          type: 'number',
          description: 'Pull request number.',
        },
        title: {
          type: 'string',
          description: 'New PR title.',
        },
        body: {
          type: 'string',
          description: 'New PR body.',
        },
        state: {
          type: 'string',
          enum: ['open', 'closed'],
          description: 'New PR state.',
        },
      },
      required: ['owner_repo', 'pr_number'],
    },
  },
  {
    name: 'github_merge_pr',
    access: 'write',
    description: 'Merge a pull request.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        pr_number: {
          type: 'number',
          description: 'Pull request number.',
        },
        merge_method: {
          type: 'string',
          enum: ['squash', 'merge', 'rebase'],
          description: 'Merge method (default squash).',
        },
        commit_title: {
          type: 'string',
          description: 'Custom commit title.',
        },
        commit_message: {
          type: 'string',
          description: 'Custom commit message.',
        },
      },
      required: ['owner_repo', 'pr_number'],
    },
  },
  {
    name: 'github_list_commits',
    access: 'read',
    description: 'List commits in a repository or for a PR.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        sha: {
          type: 'string',
          description: 'SHA or branch to list commits from (default HEAD).',
        },
        path: {
          type: 'string',
          description: 'Filter commits affecting a specific path.',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_list_branches',
    access: 'read',
    description: 'List branches in a GitHub repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_get_branch',
    access: 'read',
    description: 'Get details about a specific branch.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        branch: {
          type: 'string',
          description: 'Branch name.',
        },
      },
      required: ['owner_repo', 'branch'],
    },
  },
  {
    name: 'github_list_collaborators',
    access: 'read',
    description: 'List repository collaborators.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        affiliation: {
          type: 'string',
          enum: ['all', 'outside', 'direct'],
          description: 'Filter by affiliation (default all).',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_get_content',
    access: 'read',
    description: 'Get file or directory contents from a repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        path: {
          type: 'string',
          description: 'File or directory path.',
        },
        ref: {
          type: 'string',
          description: 'Git ref (branch, tag, or SHA).',
        },
      },
      required: ['owner_repo', 'path'],
    },
  },
  {
    name: 'github_create_or_update_file',
    access: 'write',
    description: 'Create or update a single file in a repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        path: {
          type: 'string',
          description: 'File path in the repository.',
        },
        message: {
          type: 'string',
          description: 'Commit message.',
        },
        content: {
          type: 'string',
          description: 'Base64-encoded file content.',
        },
        sha: {
          type: 'string',
          description: 'SHA of file being replaced (required for updates).',
        },
        branch: {
          type: 'string',
          description: 'Branch to commit to (default main).',
        },
      },
      required: ['owner_repo', 'path', 'message', 'content'],
    },
  },
  {
    name: 'github_delete_file',
    access: 'write',
    description: 'Delete a file from a repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        path: {
          type: 'string',
          description: 'File path to delete.',
        },
        message: {
          type: 'string',
          description: 'Commit message.',
        },
        sha: {
          type: 'string',
          description: 'SHA of file to delete.',
        },
        branch: {
          type: 'string',
          description: 'Branch to delete from (default main).',
        },
      },
      required: ['owner_repo', 'path', 'message', 'sha'],
    },
  },
  {
    name: 'github_list_workflow_runs',
    access: 'read',
    description: 'List GitHub Actions workflow runs.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        workflow_id: {
          type: 'string',
          description: 'Workflow ID or filename (omit for all workflows).',
        },
        branch: {
          type: 'string',
          description: 'Filter by branch.',
        },
        status: {
          type: 'string',
          enum: ['queued', 'in_progress', 'completed', 'success', 'failure', 'cancelled', 'neutral', 'skipped', 'timed_out', 'action_required', 'all'],
          description: 'Filter by status.',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_get_workflow_run',
    access: 'read',
    description: 'Get details about a specific workflow run.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        run_id: {
          type: 'number',
          description: 'Run ID.',
        },
      },
      required: ['owner_repo', 'run_id'],
    },
  },
  {
    name: 'github_trigger_workflow',
    access: 'write',
    description: 'Trigger a GitHub Actions workflow.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
        workflow_id: {
          type: 'string',
          description: 'Workflow ID or filename.',
        },
        ref: {
          type: 'string',
          description: 'Git ref to trigger (branch, tag, or SHA).',
        },
        inputs: {
          type: 'string',
          description: 'JSON string of workflow inputs.',
        },
      },
      required: ['owner_repo', 'workflow_id'],
    },
  },
  {
    name: 'github_list_workflows',
    access: 'read',
    description: 'List GitHub Actions workflows in a repository.',
    parameters: {
      type: 'object',
      properties: {
        owner_repo: {
          type: 'string',
          description: 'Repository in format "owner/repo".',
        },
      },
      required: ['owner_repo'],
    },
  },
  {
    name: 'github_get_auth_user',
    access: 'read',
    description: 'Get the authenticated GitHub user information.',
    parameters: {
      type: 'object',
      properties: {},
    },
  },
  {
    name: 'github_list_user_repos',
    access: 'read',
    description: 'List repositories for the authenticated user or a specific user.',
    parameters: {
      type: 'object',
      properties: {
        username: {
          type: 'string',
          description: 'Username to list repos for (omit for authenticated user).',
        },
        visibility: {
          type: 'string',
          enum: ['all', 'public', 'private'],
          description: 'Filter by visibility.',
        },
        sort: {
          type: 'string',
          enum: ['created', 'updated', 'pushed', 'full_name'],
          description: 'Sort field (default full_name).',
        },
        direction: {
          type: 'string',
          enum: DIRECTION_OPTIONS,
          description: 'Sort direction (default asc).',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of results (default 30).',
        },
      },
    },
  },
  {
    name: 'github_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated GitHub API request for advanced operations not covered by dedicated tools.',
    parameters: {
      type: 'object',
      properties: {
        method: {
          type: 'string',
          enum: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
          description: 'HTTP method.',
        },
        path: {
          type: 'string',
          description: 'API path or full URL.',
        },
        query: {
          type: 'object',
          description: 'Optional query parameters.',
        },
        body: {
          type: 'object',
          description: 'Optional JSON request body.',
        },
      },
      required: ['method', 'path'],
    },
  },
];

function parseCommaSeparatedList(value) {
  if (!value) return [];
  return String(value).split(',').map((s) => s.trim()).filter(Boolean);
}

async function executeGithubTool(toolName, args, auth) {
  switch (toolName) {
    case 'github_get_auth_user': {
      return await githubApiRequest(auth, {
        path: '/user',
      });
    }

    case 'github_search_repos': {
      return await githubApiRequest(auth, {
        path: '/search/repositories',
        query: {
          q: String(args.query || ''),
          per_page: Math.min(Number(args.max_results) || 10, 100),
        },
      });
    }

    case 'github_get_repo': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}`,
      });
    }

    case 'github_list_issues': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const query = { per_page: Math.min(Number(args.max_results) || 30, 100) };
      if (args.state) query.state = args.state;
      if (args.labels) query.labels = args.labels;
      if (args.assignee) query.assignee = args.assignee;
      if (args.sort) query.sort = args.sort;
      if (args.direction) query.direction = args.direction;
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/issues`,
        query,
      });
    }

    case 'github_get_issue': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/issues/${Number(args.issue_number)}`,
      });
    }

    case 'github_create_issue': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'POST',
        path: `/repos/${owner}/${repo}/issues`,
        body: {
          title: String(args.title || ''),
          body: args.body ? String(args.body) : undefined,
          labels: parseCommaSeparatedList(args.labels),
          assignees: parseCommaSeparatedList(args.assignees),
        },
      });
    }

    case 'github_update_issue': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const body = {};
      if (args.title) body.title = String(args.title);
      if (args.body !== undefined) body.body = String(args.body);
      if (args.state) body.state = args.state;
      if (args.labels) body.labels = parseCommaSeparatedList(args.labels);
      if (args.assignees) body.assignees = parseCommaSeparatedList(args.assignees);
      return await githubApiRequest(auth, {
        method: 'PATCH',
        path: `/repos/${owner}/${repo}/issues/${Number(args.issue_number)}`,
        body,
      });
    }

    case 'github_add_issue_labels': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'POST',
        path: `/repos/${owner}/${repo}/issues/${Number(args.issue_number)}/labels`,
        body: {
          labels: parseCommaSeparatedList(args.labels),
        },
      });
    }

    case 'github_add_issue_assignees': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'POST',
        path: `/repos/${owner}/${repo}/issues/${Number(args.issue_number)}/assignees`,
        body: {
          assignees: parseCommaSeparatedList(args.assignees),
        },
      });
    }

    case 'github_list_prs': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const query = { per_page: Math.min(Number(args.max_results) || 30, 100) };
      if (args.state) query.state = args.state;
      if (args.sort) query.sort = args.sort;
      if (args.direction) query.direction = args.direction;
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/pulls`,
        query,
      });
    }

    case 'github_get_pr': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/pulls/${Number(args.pr_number)}`,
      });
    }

    case 'github_create_pr': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'POST',
        path: `/repos/${owner}/${repo}/pulls`,
        body: {
          title: String(args.title || ''),
          body: args.body ? String(args.body) : undefined,
          head: String(args.head || ''),
          base: args.base ? String(args.base) : 'main',
          draft: args.draft === true,
          maintainer_can_modify: args.maintainer_can_modify === true,
        },
      });
    }

    case 'github_update_pr': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const body = {};
      if (args.title) body.title = String(args.title);
      if (args.body !== undefined) body.body = String(args.body);
      if (args.state) body.state = args.state;
      return await githubApiRequest(auth, {
        method: 'PATCH',
        path: `/repos/${owner}/${repo}/pulls/${Number(args.pr_number)}`,
        body,
      });
    }

    case 'github_merge_pr': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'PUT',
        path: `/repos/${owner}/${repo}/pulls/${Number(args.pr_number)}/merge`,
        body: {
          merge_method: args.merge_method || 'squash',
          commit_title: args.commit_title ? String(args.commit_title) : undefined,
          commit_message: args.commit_message ? String(args.commit_message) : undefined,
        },
      });
    }

    case 'github_list_commits': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const query = { per_page: Math.min(Number(args.max_results) || 30, 100) };
      if (args.sha) query.sha = String(args.sha);
      if (args.path) query.path = String(args.path);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/commits`,
        query,
      });
    }

    case 'github_list_branches': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/branches`,
        query: buildPaginationParams({ per_page: args.max_results }),
      });
    }

    case 'github_get_branch': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const branch = encodeURIComponent(String(args.branch || ''));
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/branches/${branch}`,
      });
    }

    case 'github_list_collaborators': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const maxResults = parsePositiveInt(args.max_results, 30);
      const perPage = Math.min(100, maxResults);
      const query = {
        per_page: perPage,
      };
      if (args.affiliation) query.affiliation = args.affiliation;

      const items = [];
      for (let page = 1; items.length < maxResults; page += 1) {
        const pageItems = await githubApiRequest(auth, {
          path: `/repos/${owner}/${repo}/collaborators`,
          query: { ...query, page },
        });
        const list = Array.isArray(pageItems) ? pageItems : [];
        if (list.length === 0) break;
        items.push(...list);
        if (list.length < perPage) break;
      }
      return items.slice(0, maxResults);
    }

    case 'github_get_content': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      const query = {};
      if (args.ref) query.ref = String(args.ref);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/contents/${String(args.path || '')}`,
        query,
      });
    }

    case 'github_create_or_update_file': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'PUT',
        path: `/repos/${owner}/${repo}/contents/${String(args.path || '')}`,
        body: {
          message: String(args.message || ''),
          content: String(args.content || ''),
          sha: args.sha ? String(args.sha) : undefined,
          branch: args.branch ? String(args.branch) : undefined,
        },
      });
    }

    case 'github_delete_file': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        method: 'DELETE',
        path: `/repos/${owner}/${repo}/contents/${String(args.path || '')}`,
        body: {
          message: String(args.message || ''),
          sha: String(args.sha || ''),
          branch: args.branch ? String(args.branch) : undefined,
        },
      });
    }

    case 'github_list_workflow_runs': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      let path = `/repos/${owner}/${repo}/actions/runs`;
      if (args.workflow_id) {
        path = `/repos/${owner}/${repo}/actions/workflows/${String(args.workflow_id)}/runs`;
      }
      const maxResults = parsePositiveInt(args.max_results, 100);
      const perPage = Math.min(100, maxResults);
      const query = { per_page: perPage };
      if (args.branch) query.branch = String(args.branch);
      if (args.status) query.status = args.status;

      const runs = [];
      for (let page = 1; runs.length < maxResults; page += 1) {
        const response = await githubApiRequest(auth, {
          path,
          query: { ...query, page },
        });
        const pageRuns = Array.isArray(response?.workflow_runs)
          ? response.workflow_runs
          : [];
        if (pageRuns.length === 0) break;
        runs.push(...pageRuns);
        if (pageRuns.length < perPage) break;
      }

      return runs.slice(0, maxResults);
    }

    case 'github_get_workflow_run': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/actions/runs/${Number(args.run_id)}`,
      });
    }

    case 'github_trigger_workflow': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      let inputs = {};
      if (args.inputs) {
        try {
          inputs = JSON.parse(String(args.inputs));
        } catch (error) {
          throw new Error(`Invalid workflow inputs JSON: ${error?.message || error}`);
        }
      }
      return await githubApiRequest(auth, {
        method: 'POST',
        path: `/repos/${owner}/${repo}/actions/workflows/${String(args.workflow_id)}/dispatches`,
        body: {
          ref: args.ref ? String(args.ref) : 'main',
          inputs,
        },
      });
    }

    case 'github_list_workflows': {
      const { owner, repo } = parseOwnerRepo(args.owner_repo);
      return await githubApiRequest(auth, {
        path: `/repos/${owner}/${repo}/actions/workflows`,
      });
    }

    case 'github_list_user_repos': {
      const path = args.username
        ? `/users/${String(args.username)}/repos`
        : '/user/repos';
      const maxResults = parsePositiveInt(args.max_results, 100);
      const perPage = Math.min(maxResults, 100);
      const query = { per_page: perPage };
      if (args.visibility) query.visibility = args.visibility;
      if (args.sort) query.sort = args.sort;
      if (args.direction) query.direction = args.direction;

      const repos = [];
      for (let page = 1; repos.length < maxResults; page += 1) {
        const pageRepos = await githubApiRequest(auth, {
          path,
          query: { ...query, page },
        });
        const list = Array.isArray(pageRepos) ? pageRepos : [];
        if (list.length === 0) break;
        repos.push(...list);
        if (list.length < perPage) break;
      }

      return repos.slice(0, maxResults);
    }

    case 'github_api_request': {
      let baseUrl = 'https://api.github.com';
      let path = String(args.path || '');
      let query = args.query || null;
      if (path.startsWith('http')) {
        const url = new URL(path);
        const isHttps = url.protocol === 'https:';
        if (!isHttps) {
          throw new Error('Only https:// GitHub API URLs are allowed.');
        }
        if (!isAllowedGithubApiHost(url.hostname)) {
          throw new Error(`Host is not allowed for GitHub API requests: ${url.hostname}`);
        }
        baseUrl = `${url.protocol}//${url.host}`;
        path = url.pathname;
        const parsedQuery = Object.fromEntries(url.searchParams.entries());
        query = {
          ...parsedQuery,
          ...(args.query && typeof args.query === 'object' ? args.query : {}),
        };
      }
      return await githubApiRequest(auth, {
        method: args.method || 'GET',
        path,
        query,
        body: args.body || null,
        baseUrl,
      });
    }

    default:
      return null;
  }
}

module.exports = {
  executeGithubTool,
  githubToolDefinitions,
};