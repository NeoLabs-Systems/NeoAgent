'use strict';

const db = require('../../db/database');
const { BasePlatform } = require('./base');
const { contextFromMessage } = require('./access_policy');
const { githubApiRequest } = require('../integrations/github/common');
const { createServiceLogger } = require('../../utils/logger');

const log = createServiceLogger('GitHubMessaging');

// GitHub as a chat surface: approved people @mention the agent's account on an
// issue or pull request and it answers in that thread. Nothing is registered on
// GitHub; each agent polls its watched repositories with its own Mentions
// connection and keeps its own cursors, so two agents never share state.

const POLL_INTERVAL_MS = 30000;
const MAX_PAGES_PER_POLL = 3;
const MAX_SEEN_COMMENTS = 2000;
const CURSOR_SETTING_KEY = 'github_mentions_cursors';
const MENTIONS_APP_KEY = 'mentions';
const THREAD_ID_PATTERN = /^([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)#(\d+)(?::(\d+))?$/;
const COMMENT_SOURCES = Object.freeze([
  { kind: 'issue_comment', path: 'issues/comments', numberFrom: 'issue_url' },
  { kind: 'review_comment', path: 'pulls/comments', numberFrom: 'pull_request_url' },
]);
const REPO_ROLES = Object.freeze(['OWNER', 'MEMBER', 'COLLABORATOR']);
// The client loads every platform's access catalog on each messaging refresh.
const ACCESS_TARGETS_TTL_MS = 5 * 60 * 1000;

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function numberFromUrl(url) {
  const match = /\/(\d+)$/.exec(String(url || ''));
  return match ? Number(match[1]) : null;
}

function parseThreadId(chatId) {
  const match = THREAD_ID_PATTERN.exec(String(chatId || '').trim());
  if (!match) return null;
  return {
    repo: match[1],
    number: Number(match[2]),
    reviewCommentId: match[3] ? Number(match[3]) : null,
  };
}

class GithubPlatform extends BasePlatform {
  constructor(config = {}) {
    super('github', config);
    this.supportsGroups = true;
    this.userId = config.userId;
    this.agentId = config.agentId;
    this.integrationManager = config.integrationManager || null;
    this.account = null;
    this.mentionPattern = null;
    this.pollTimer = null;
    this.polling = null;
    this.cursors = {};
    this.seenCommentIds = new Set();
    this.ownCommentIds = new Set();
    this.accessTargetsCache = null;
  }

  _connection() {
    return this.integrationManager
      ?.listConnections(this.userId, 'github', this.agentId)
      .find((row) => row.status === 'connected' && row.app_key === MENTIONS_APP_KEY) || null;
  }

  // Read per request so a reconnect or disconnect under Integrations takes
  // effect without restarting the platform.
  _auth() {
    const connection = this._connection();
    const token = connection
      ? String(this.integrationManager.parseCredentials(connection.credentials_json).access_token || '')
      : '';
    return token ? { token } : null;
  }

  _loadCursors() {
    const row = db.prepare(
      'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?',
    ).get(this.userId, this.agentId, CURSOR_SETTING_KEY);
    try {
      const parsed = row ? JSON.parse(row.value) : {};
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch {
      return {};
    }
  }

  _saveCursors() {
    db.prepare(
      `INSERT INTO agent_settings (user_id, agent_id, key, value)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
    ).run(this.userId, this.agentId, CURSOR_SETTING_KEY, JSON.stringify(this.cursors));
  }

  // The access policy is also the watch list: a repository is polled when a
  // rule names it, either on its own or as the place an approved person may ask.
  watchedRepos() {
    const policy = this.getAccessPolicy();
    if (policy.sharedPolicy === 'disabled') return [];
    const repos = new Map();
    for (const rule of policy.sharedSpaceRules) {
      if (rule.scope === 'group') repos.set(rule.value.toLowerCase(), rule.value);
    }
    for (const rule of policy.sharedMemberRules) {
      if (rule.spaceScope === 'group') repos.set(rule.spaceValue.toLowerCase(), rule.spaceValue);
    }
    return [...repos.values()];
  }

  async connect() {
    const auth = this._auth();
    if (!auth) {
      throw new Error('Connect a GitHub account under Integrations → GitHub → Mentions first.');
    }
    const user = await githubApiRequest(auth, { path: '/user' });
    this.account = { id: Number(user.id), login: String(user.login) };
    this.mentionPattern = new RegExp(`(^|[^A-Za-z0-9_-])@${escapeRegExp(this.account.login)}(?![A-Za-z0-9_-])`, 'i');
    this.cursors = this._loadCursors();
    this.status = 'connected';
    this.emit('connected');
    this._schedulePoll(0);
    return { status: 'connected' };
  }

  async disconnect() {
    clearTimeout(this.pollTimer);
    this.pollTimer = null;
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }

  getAuthInfo() {
    return this.account ? { username: this.account.login } : null;
  }

  _schedulePoll(delayMs) {
    clearTimeout(this.pollTimer);
    this.pollTimer = setTimeout(() => {
      this.pollTimer = null;
      void this.poll().finally(() => {
        if (this.status === 'connected') this._schedulePoll(POLL_INTERVAL_MS);
      });
    }, delayMs);
    this.pollTimer.unref?.();
  }

  poll() {
    if (!this.polling) {
      this.polling = this._pollOnce().finally(() => { this.polling = null; });
    }
    return this.polling;
  }

  async _pollOnce() {
    if (this.status !== 'connected') return;
    const auth = this._auth();
    if (!auth) {
      this.status = 'disconnected';
      this.emit('disconnected', { requiresUserAction: true, reason: 'authentication_required' });
      return;
    }
    const startedAt = new Date().toISOString();
    for (const repo of this.watchedRepos()) {
      const key = repo.toLowerCase();
      // A newly watched repository starts now; its history is not replayed.
      const since = this.cursors[key] || startedAt;
      let newest = since;
      try {
        for (const source of COMMENT_SOURCES) {
          newest = await this._pollSource(auth, repo, source, since, newest);
        }
        this.cursors[key] = newest;
      } catch (error) {
        if (error.status === 401) {
          this.status = 'disconnected';
          this.emit('disconnected', { requiresUserAction: true, reason: 'authentication_required' });
          return;
        }
        log.warn(`Polling ${repo} failed: ${error.message}`);
      }
    }
    this._saveCursors();
  }

  async _pollSource(auth, repo, source, since, newest) {
    for (let page = 1; page <= MAX_PAGES_PER_POLL; page += 1) {
      const comments = await githubApiRequest(auth, {
        path: `/repos/${repo}/${source.path}`,
        query: { since, sort: 'created', direction: 'asc', per_page: 100, page },
      });
      const list = Array.isArray(comments) ? comments : [];
      for (const comment of list) {
        const createdAt = String(comment.created_at || '');
        // `since` matches on update time; older comments that were edited are
        // not new requests.
        if (createdAt < since) continue;
        if (createdAt > newest) newest = createdAt;
        await this._handleComment(auth, repo, source, comment);
      }
      if (list.length < 100) break;
    }
    return newest;
  }

  _markSeen(id) {
    this.seenCommentIds.add(id);
    if (this.seenCommentIds.size > MAX_SEEN_COMMENTS) {
      this.seenCommentIds.delete(this.seenCommentIds.values().next().value);
    }
  }

  async _isOwnReviewComment(auth, repo, commentId) {
    if (!commentId) return false;
    if (this.ownCommentIds.has(commentId)) return true;
    try {
      const parent = await githubApiRequest(auth, { path: `/repos/${repo}/pulls/comments/${commentId}` });
      return Number(parent?.user?.id) === this.account.id;
    } catch {
      return false;
    }
  }

  async _handleComment(auth, repo, source, comment) {
    const seenKey = `${source.kind}:${comment.id}`;
    if (this.seenCommentIds.has(seenKey)) return;
    this._markSeen(seenKey);

    const author = comment.user || {};
    if (Number(author.id) === this.account.id) {
      if (source.kind === 'review_comment') this.ownCommentIds.add(Number(comment.id));
      return;
    }
    if (author.type === 'Bot') return;

    const body = String(comment.body || '');
    const wasMentioned = this.mentionPattern.test(body);
    const repliedToAgent = !wasMentioned && source.kind === 'review_comment'
      && await this._isOwnReviewComment(auth, repo, Number(comment.in_reply_to_id));
    // Chatter that does not address the agent is none of its business and
    // should not show up as a blocked sender either.
    if (!wasMentioned && !repliedToAgent) return;

    const number = numberFromUrl(comment[source.numberFrom]);
    if (!number) return;
    const isPullRequest = source.kind === 'review_comment' || /\/pull\/\d+/.test(String(comment.html_url || ''));
    const reviewThreadId = source.kind === 'review_comment'
      ? Number(comment.in_reply_to_id || comment.id)
      : null;
    const login = String(author.login || author.id);
    const channelContext = source.kind === 'review_comment' && comment.diff_hunk
      ? [{
          author: 'review context',
          content: `${comment.path}${comment.line ? `:${comment.line}` : ''}\n${String(comment.diff_hunk).slice(-1500)}`,
        }]
      : null;

    const msg = {
      platform: 'github',
      chatId: reviewThreadId ? `${repo}#${number}:${reviewThreadId}` : `${repo}#${number}`,
      messageId: seenKey,
      sender: String(author.id),
      senderName: `@${login}`,
      senderUsername: login,
      senderTag: `@${login}`,
      content: body,
      isGroup: true,
      wasMentioned,
      repliedToAgent,
      groupId: repo,
      groupName: repo,
      channelName: `${isPullRequest ? 'pull request' : 'issue'} #${number}`,
      roleIds: [String(comment.author_association || 'NONE').toUpperCase()],
      channelContext,
      timestamp: comment.created_at,
      metadata: {
        threadNumber: number,
        threadKind: isPullRequest ? 'pull_request' : 'issue',
        commentUrl: comment.html_url || null,
      },
    };
    const access = this._checkInboundAccess(contextFromMessage(msg), {
      senderName: msg.senderName,
      groupLabel: repo,
      meta: `${repo} ${msg.channelName}`,
    });
    if (!access.allowed) return;
    this.emit('message', msg);
  }

  async sendMessage(to, content) {
    const thread = parseThreadId(to);
    if (!thread) throw new Error(`Not a GitHub thread: ${to}. Use owner/repo#number.`);
    const auth = this._auth();
    if (!auth) throw new Error('The GitHub Mentions account for this agent is not connected.');
    const comment = thread.reviewCommentId
      ? await githubApiRequest(auth, {
          method: 'POST',
          path: `/repos/${thread.repo}/pulls/${thread.number}/comments/${thread.reviewCommentId}/replies`,
          body: { body: content },
        })
      : await githubApiRequest(auth, {
          method: 'POST',
          path: `/repos/${thread.repo}/issues/${thread.number}/comments`,
          body: { body: content },
        });
    if (thread.reviewCommentId && comment?.id) this.ownCommentIds.add(Number(comment.id));
    return { success: true, messageId: comment?.id ? String(comment.id) : null };
  }

  async listAccessTargets() {
    const auth = this._auth();
    if (!auth || this.status !== 'connected') return [];
    const watchKey = this.watchedRepos().join('\n');
    const cached = this.accessTargetsCache;
    if (cached && cached.watchKey === watchKey && Date.now() - cached.at < ACCESS_TARGETS_TTL_MS) {
      return cached.targets;
    }
    const targets = REPO_ROLES.map((role) => ({
      source: 'live',
      bucket: 'sharedActorRules',
      scope: 'role',
      value: role,
      label: `Every ${role.toLowerCase()}`,
      subtitle: 'GitHub repository role',
    }));
    const repos = await githubApiRequest(auth, {
      path: '/user/repos',
      query: { per_page: 100, sort: 'pushed' },
    }).catch(() => []);
    for (const repo of Array.isArray(repos) ? repos : []) {
      targets.push({
        source: 'live',
        bucket: 'sharedSpaceRules',
        scope: 'group',
        value: repo.full_name,
        label: repo.full_name,
        subtitle: repo.private ? 'Private repository' : 'Public repository',
      });
    }
    for (const repo of this.watchedRepos()) {
      const people = await githubApiRequest(auth, {
        path: `/repos/${repo}/collaborators`,
        query: { per_page: 100 },
      }).catch(() => []);
      for (const person of Array.isArray(people) ? people : []) {
        if (Number(person.id) === this.account?.id) continue;
        targets.push({
          source: 'live',
          bucket: 'sharedMemberRules',
          scope: 'user',
          value: String(person.id),
          label: `@${person.login}`,
          subtitle: `Collaborator on ${repo}`,
          spaceScope: 'group',
          spaceValue: repo,
          spaceLabel: repo,
        });
      }
    }
    this.accessTargetsCache = { watchKey, at: Date.now(), targets };
    return targets;
  }
}

module.exports = { GithubPlatform, parseThreadId };
