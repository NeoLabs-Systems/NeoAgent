'use strict';

const crypto = require('crypto');
const net = require('net');
const tls = require('tls');
const { BasePlatform } = require('./base');

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required`);
  return text;
}

function trimTrailingSlash(value) {
  return String(value || '').replace(/\/+$/, '');
}

function constantTimeEqual(a, b) {
  const left = Buffer.from(String(a || ''));
  const right = Buffer.from(String(b || ''));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function jsonPath(input, path) {
  if (!path) return undefined;
  let current = input;
  for (const part of String(path).split('.')) {
    if (current == null) return undefined;
    current = current[part];
  }
  return current;
}

function buildUrl(template, values) {
  return String(template || '').replace(/\{([a-zA-Z0-9_]+)\}/g, (_match, key) => {
    const value = values[key] == null ? '' : String(values[key]);
    return encodeURIComponent(value);
  });
}

function parseHeaders(value) {
  if (!value) return {};
  if (typeof value === 'object' && !Array.isArray(value)) return value;
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

async function fetchJson(url, options = {}, serviceName = 'Messaging platform') {
  const response = await fetch(url, {
    ...options,
    headers: {
      ...(options.body == null ? {} : { 'content-type': 'application/json' }),
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  let body = null;
  if (text) {
    try { body = JSON.parse(text); } catch { body = text; }
  }
  if (!response.ok) {
    const detail = typeof body === 'string' ? body.slice(0, 300) : JSON.stringify(body);
    throw new Error(`${serviceName} request failed (${response.status}): ${detail || response.statusText}`);
  }
  return body;
}

function inboundAllowed(config, req) {
  const secret = String(config.inboundSecret || config.webhookSecret || '').trim();
  if (!secret) return false;
  const supplied = req.query?.token
    || req.headers?.['x-neoagent-token']
    || req.headers?.['x-webhook-token']
    || '';
  return constantTimeEqual(supplied, secret);
}

function genericMessageFromWebhook(platform, config, req) {
  const body = req.body || {};
  const content = jsonPath(body, config.contentPath || 'content')
    || jsonPath(body, 'text')
    || jsonPath(body, 'message.text')
    || jsonPath(body, 'message')
    || jsonPath(body, 'body')
    || '';
  const chatId = jsonPath(body, config.chatIdPath || 'chatId')
    || jsonPath(body, 'channel')
    || jsonPath(body, 'channel_id')
    || jsonPath(body, 'room')
    || jsonPath(body, 'room_id')
    || jsonPath(body, 'conversation.id')
    || config.defaultTo
    || 'webhook';
  const sender = jsonPath(body, config.senderPath || 'sender')
    || jsonPath(body, 'user')
    || jsonPath(body, 'user.id')
    || jsonPath(body, 'from.id')
    || jsonPath(body, 'sender_id')
    || chatId;
  const senderName = jsonPath(body, config.senderNamePath || 'senderName')
    || jsonPath(body, 'user.name')
    || jsonPath(body, 'from.name')
    || null;

  if (!String(content || '').trim()) return null;
  return {
    platform,
    chatId: String(chatId),
    sender: String(sender),
    senderName: senderName ? String(senderName) : null,
    content: String(content),
    mediaType: null,
    isGroup: Boolean(config.groupByDefault) || String(chatId) !== String(sender),
    messageId: jsonPath(body, config.messageIdPath || 'messageId') || crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    rawMessage: body,
  };
}

class ConfigurableHttpPlatform extends BasePlatform {
  constructor(name, config = {}, defaults = {}) {
    super(name, config);
    this.defaults = defaults;
    this.supportsGroups = defaults.supportsGroups !== false;
    this.supportsMedia = false;
    if (Array.isArray(config.allowedIds || config.allowedEntries)) {
      this.setAllowedEntries(config.allowedIds || config.allowedEntries);
    }
  }

  async connect() {
    const hasOutbound = this.config.webhookUrl || this.config.outboundUrl || this.defaults.webhookUrl || this.defaults.outboundUrl;
    const hasInbound = this.config.inboundSecret || this.config.webhookSecret;
    if (!hasOutbound && !hasInbound) {
      throw new Error(`${this.defaults.label || this.name} requires an outbound URL/token or an inbound secret`);
    }
    this.status = 'connected';
    this.emit('connected');
    return { status: 'connected' };
  }

  async disconnect() {
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }

  getAuthInfo() {
    return {
      label: this.config.displayName || this.defaults.label || this.name,
    };
  }

  async sendMessage(to, content) {
    const urlTemplate = this.config.outboundUrl || this.config.webhookUrl || this.defaults.outboundUrl || this.defaults.webhookUrl;
    if (!urlTemplate) throw new Error(`${this.defaults.label || this.name} outbound URL is not configured`);

    const token = this.config.token || this.config.accessToken || this.config.botToken || '';
    const url = buildUrl(urlTemplate, {
      to,
      content,
      token,
      baseUrl: trimTrailingSlash(this.config.baseUrl || ''),
    });
    const headers = {
      ...parseHeaders(this.defaults.headers),
      ...parseHeaders(this.config.headers),
    };
    if (token && this.config.authHeader !== 'none' && !headers.authorization && !headers.Authorization) {
      headers.Authorization = `${this.config.authScheme || this.defaults.authScheme || 'Bearer'} ${token}`;
    }

    const bodyTemplate = this.config.bodyTemplate || this.defaults.bodyTemplate;
    let body;
    if (bodyTemplate) {
      body = JSON.parse(buildUrl(bodyTemplate, { to, content, token }));
    } else {
      body = {
        [this.config.contentField || this.defaults.contentField || 'text']: content,
        ...(this.config.recipientField || this.defaults.recipientField
          ? { [this.config.recipientField || this.defaults.recipientField]: to }
          : {}),
      };
    }

    await fetchJson(url, {
      method: this.config.method || this.defaults.method || 'POST',
      headers,
      body: JSON.stringify(body),
    }, this.defaults.label || this.name);
    return { success: true };
  }

  async handleWebhook(req) {
    if (!inboundAllowed(this.config, req)) return { handled: false, status: 403, body: 'Forbidden' };
    const msg = genericMessageFromWebhook(this.name, this.config, req);
    if (!msg) return { handled: true, status: 202, body: 'ignored' };
    this.emit('message', msg);
    return { handled: true, status: 200, body: 'OK' };
  }
}

class SlackPlatform extends BasePlatform {
  constructor(config = {}) {
    super('slack', config);
    this.supportsGroups = true;
    this.botToken = config.botToken || config.token || '';
    this.signingSecret = config.signingSecret || '';
    this.inboundSecret = config.inboundSecret || '';
    this._botUserId = null;
    if (Array.isArray(config.allowedIds || config.allowedEntries)) {
      this.setAllowedEntries(config.allowedIds || config.allowedEntries);
    }
  }

  async connect() {
    if (!this.botToken && !this.inboundSecret && !this.signingSecret) {
      throw new Error('Slack bot token or inbound secret is required');
    }
    if (this.botToken) {
      const auth = await fetchJson('https://slack.com/api/auth.test', {
        method: 'POST',
        headers: { Authorization: `Bearer ${this.botToken}` },
      }, 'Slack');
      if (auth && auth.ok === false) throw new Error(`Slack auth failed: ${auth.error || 'unknown error'}`);
      this._botUserId = auth?.user_id || auth?.bot_id || null;
    }
    this.status = 'connected';
    this.emit('connected');
    return { status: 'connected' };
  }

  async disconnect() {
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }

  getAuthInfo() {
    return this._botUserId ? { username: this._botUserId } : null;
  }

  async sendMessage(to, content) {
    if (!this.botToken) throw new Error('Slack bot token is required for outbound messages');
    const result = await fetchJson('https://slack.com/api/chat.postMessage', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.botToken}` },
      body: JSON.stringify({ channel: to, text: content }),
    }, 'Slack');
    if (result && result.ok === false) throw new Error(`Slack post failed: ${result.error || 'unknown error'}`);
    return { success: true, ts: result?.ts };
  }

  #verifySlackRequest(req) {
    if (this.signingSecret) {
      const ts = String(req.headers?.['x-slack-request-timestamp'] || '');
      const sig = String(req.headers?.['x-slack-signature'] || '');
      const raw = req.rawBody || JSON.stringify(req.body || {});
      const age = Math.abs(Date.now() / 1000 - Number(ts || 0));
      if (!ts || !sig || age > 60 * 5) return false;
      const expected = `v0=${crypto.createHmac('sha256', this.signingSecret).update(`v0:${ts}:${raw}`).digest('hex')}`;
      return constantTimeEqual(sig, expected);
    }
    if (this.inboundSecret) return inboundAllowed(this.config, req);
    return false;
  }

  async handleWebhook(req) {
    const body = req.body || {};
    if (body.type === 'url_verification' && body.challenge) {
      if (!this.#verifySlackRequest(req)) return { handled: false, status: 403, body: 'Forbidden' };
      return { handled: true, status: 200, body: { challenge: body.challenge } };
    }
    if (!this.#verifySlackRequest(req)) return { handled: false, status: 403, body: 'Forbidden' };

    const event = body.event || body;
    if (event.type !== 'message' || event.subtype || !event.text) {
      return { handled: true, status: 202, body: 'ignored' };
    }
    if (this._botUserId && event.user === this._botUserId) {
      return { handled: true, status: 202, body: 'ignored' };
    }
    this.emit('message', {
      platform: 'slack',
      chatId: String(event.channel || 'slack'),
      sender: String(event.user || event.bot_id || 'slack'),
      senderName: event.username || null,
      content: String(event.text),
      mediaType: null,
      isGroup: String(event.channel_type || '') !== 'im',
      messageId: String(event.client_msg_id || event.ts || crypto.randomUUID()),
      timestamp: event.event_ts ? new Date(Number(event.event_ts) * 1000).toISOString() : new Date().toISOString(),
      threadTs: event.thread_ts || null,
      rawMessage: body,
    });
    return { handled: true, status: 200, body: 'OK' };
  }
}

class GoogleChatPlatform extends ConfigurableHttpPlatform {
  constructor(config = {}) {
    super('google_chat', config, { label: 'Google Chat', contentField: 'text' });
  }

  async handleWebhook(req) {
    if (!inboundAllowed(this.config, req)) return { handled: false, status: 403, body: 'Forbidden' };
    const body = req.body || {};
    const message = body.message || body;
    const content = message.argumentText || message.text || body.text;
    if (!content) return { handled: true, status: 202, body: 'ignored' };
    this.emit('message', {
      platform: 'google_chat',
      chatId: String(message.space?.name || body.space?.name || this.config.defaultTo || 'google_chat'),
      sender: String(body.user?.name || message.sender?.name || 'google_chat'),
      senderName: body.user?.displayName || message.sender?.displayName || null,
      content: String(content),
      mediaType: null,
      isGroup: true,
      messageId: String(message.name || crypto.randomUUID()),
      timestamp: new Date().toISOString(),
      rawMessage: body,
    });
    return { handled: true, status: 200, body: { text: 'Received.' } };
  }
}

class TeamsPlatform extends ConfigurableHttpPlatform {
  constructor(config = {}) {
    super('teams', config, { label: 'Microsoft Teams', contentField: 'text' });
  }

  async handleWebhook(req) {
    if (!inboundAllowed(this.config, req)) return { handled: false, status: 403, body: 'Forbidden' };
    const body = req.body || {};
    const content = body.text || body.message?.text || body.value?.text;
    if (!content) return { handled: true, status: 202, body: 'ignored' };
    this.emit('message', {
      platform: 'teams',
      chatId: String(body.conversation?.id || body.channelData?.channel?.id || this.config.defaultTo || 'teams'),
      sender: String(body.from?.id || 'teams'),
      senderName: body.from?.name || null,
      content: String(content).replace(/<[^>]+>/g, '').trim(),
      mediaType: null,
      isGroup: true,
      messageId: String(body.id || crypto.randomUUID()),
      timestamp: body.timestamp || new Date().toISOString(),
      rawMessage: body,
    });
    return { handled: true, status: 200, body: { type: 'message', text: 'Received.' } };
  }
}

class MatrixPlatform extends BasePlatform {
  constructor(config = {}) {
    super('matrix', config);
    this.supportsGroups = true;
    this.homeserver = trimTrailingSlash(config.homeserver);
    this.accessToken = config.accessToken || '';
    this.userId = config.userId || '';
    this.pollEnabled = config.pollEnabled !== false;
    this.pollIntervalMs = Math.max(1000, Number(config.pollIntervalMs) || 5000);
    this._since = config.since || null;
    this._timer = null;
    if (Array.isArray(config.allowedIds || config.allowedEntries)) {
      this.setAllowedEntries(config.allowedIds || config.allowedEntries);
    }
  }

  async #matrix(path, options = {}) {
    const url = `${this.homeserver}/_matrix/client/v3${path}`;
    return fetchJson(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        ...(options.headers || {}),
      },
    }, 'Matrix');
  }

  async connect() {
    requireText(this.homeserver, 'Matrix homeserver');
    requireText(this.accessToken, 'Matrix access token');
    const whoami = await this.#matrix('/account/whoami').catch(() => null);
    this.userId = this.userId || whoami?.user_id || '';
    this.status = 'connected';
    this.emit('connected');
    if (this.pollEnabled) this.#schedulePoll(0);
    return { status: 'connected' };
  }

  async disconnect() {
    if (this._timer) clearTimeout(this._timer);
    this._timer = null;
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }

  getAuthInfo() {
    return this.userId ? { username: this.userId } : null;
  }

  #schedulePoll(delay = this.pollIntervalMs) {
    if (this._timer || this.status !== 'connected') return;
    this._timer = setTimeout(async () => {
      this._timer = null;
      await this.#poll().catch((err) => console.error('[Matrix] Poll error:', err.message));
      this.#schedulePoll();
    }, delay);
    this._timer.unref?.();
  }

  async #poll() {
    const query = new URLSearchParams({ timeout: String(Math.min(this.pollIntervalMs, 30000)) });
    if (this._since) query.set('since', this._since);
    const sync = await this.#matrix(`/sync?${query.toString()}`);
    this._since = sync?.next_batch || this._since;
    const rooms = sync?.rooms?.join || {};
    for (const [roomId, room] of Object.entries(rooms)) {
      const events = room?.timeline?.events || [];
      for (const event of events) {
        if (event.type !== 'm.room.message') continue;
        if (event.sender && this.userId && event.sender === this.userId) continue;
        const content = event.content?.body || '';
        if (!content) continue;
        this.emit('message', {
          platform: 'matrix',
          chatId: roomId,
          sender: String(event.sender || roomId),
          senderName: event.sender || null,
          content: String(content),
          mediaType: null,
          isGroup: true,
          messageId: String(event.event_id || crypto.randomUUID()),
          timestamp: event.origin_server_ts ? new Date(event.origin_server_ts).toISOString() : new Date().toISOString(),
          rawMessage: event,
        });
      }
    }
  }

  async sendMessage(to, content) {
    if (this.status !== 'connected') throw new Error('Matrix not connected');
    const txnId = encodeURIComponent(crypto.randomUUID());
    await this.#matrix(`/rooms/${encodeURIComponent(to)}/send/m.room.message/${txnId}`, {
      method: 'PUT',
      body: JSON.stringify({ msgtype: 'm.text', body: content }),
    });
    return { success: true };
  }
}

class BlueBubblesPlatform extends ConfigurableHttpPlatform {
  constructor(name, config = {}) {
    super(name, config, { label: name === 'imessage' ? 'iMessage' : 'BlueBubbles' });
    this.serverUrl = trimTrailingSlash(config.serverUrl || config.baseUrl || '');
    this.password = config.password || config.apiPassword || config.token || '';
  }

  async connect() {
    requireText(this.serverUrl || this.config.outboundUrl, `${this.defaults.label} server URL`);
    this.status = 'connected';
    this.emit('connected');
    return { status: 'connected' };
  }

  async sendMessage(to, content) {
    if (this.config.outboundUrl || this.config.webhookUrl) {
      return super.sendMessage(to, content);
    }
    const url = new URL(`${this.serverUrl}${this.config.sendPath || '/api/v1/message/text'}`);
    url.searchParams.set('guid', to);
    url.searchParams.set('tempGuid', crypto.randomUUID());
    if (this.password) url.searchParams.set('password', this.password);
    await fetchJson(url.toString(), {
      method: 'POST',
      body: JSON.stringify({ message: content }),
    }, this.defaults.label);
    return { success: true };
  }
}

class SignalPlatform extends ConfigurableHttpPlatform {
  constructor(config = {}) {
    super('signal', config, { label: 'Signal', contentField: 'message' });
    this.restUrl = trimTrailingSlash(config.restUrl || config.baseUrl || '');
    this.account = config.account || config.number || '';
    this.pollEnabled = config.pollEnabled === true;
    this.pollIntervalMs = Math.max(3000, Number(config.pollIntervalMs) || 10000);
    this._timer = null;
  }

  async connect() {
    requireText(this.restUrl || this.config.outboundUrl, 'Signal REST API URL');
    if (!this.config.outboundUrl) requireText(this.account, 'Signal account number');
    this.status = 'connected';
    this.emit('connected');
    if (this.pollEnabled) this.#schedulePoll(0);
    return { status: 'connected' };
  }

  async disconnect() {
    if (this._timer) clearTimeout(this._timer);
    this._timer = null;
    await super.disconnect();
  }

  #schedulePoll(delay = this.pollIntervalMs) {
    if (this._timer || this.status !== 'connected') return;
    this._timer = setTimeout(async () => {
      this._timer = null;
      await this.#poll().catch((err) => console.error('[Signal] Poll error:', err.message));
      this.#schedulePoll();
    }, delay);
    this._timer.unref?.();
  }

  async #poll() {
    const messages = await fetchJson(`${this.restUrl}/v1/receive/${encodeURIComponent(this.account)}`, {}, 'Signal');
    for (const item of Array.isArray(messages) ? messages : []) {
      const envelope = item.envelope || item;
      const dataMessage = envelope.dataMessage || {};
      const content = dataMessage.message || '';
      if (!content) continue;
      this.emit('message', {
        platform: 'signal',
        chatId: String(envelope.sourceNumber || envelope.source || 'signal'),
        sender: String(envelope.sourceNumber || envelope.source || 'signal'),
        senderName: envelope.sourceName || null,
        content: String(content),
        mediaType: null,
        isGroup: Boolean(dataMessage.groupInfo),
        messageId: String(envelope.timestamp || crypto.randomUUID()),
        timestamp: envelope.timestamp ? new Date(Number(envelope.timestamp)).toISOString() : new Date().toISOString(),
        rawMessage: item,
      });
    }
  }

  async sendMessage(to, content) {
    if (this.config.outboundUrl || this.config.webhookUrl) {
      return super.sendMessage(to, content);
    }
    await fetchJson(`${this.restUrl}/v2/send`, {
      method: 'POST',
      body: JSON.stringify({
        message: content,
        number: this.account,
        recipients: [to],
      }),
    }, 'Signal');
    return { success: true };
  }
}

class LinePlatform extends ConfigurableHttpPlatform {
  constructor(config = {}) {
    super('line', config, { label: 'LINE', outboundUrl: 'https://api.line.me/v2/bot/message/push' });
  }

  async connect() {
    if (!(this.config.channelAccessToken || this.config.token || this.config.inboundSecret)) {
      throw new Error('LINE channel access token or inbound secret is required');
    }
    this.status = 'connected';
    this.emit('connected');
    return { status: 'connected' };
  }

  async sendMessage(to, content) {
    const token = requireText(this.config.channelAccessToken || this.config.token, 'LINE channel access token');
    await fetchJson('https://api.line.me/v2/bot/message/push', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({
        to,
        messages: [{ type: 'text', text: content }],
      }),
    }, 'LINE');
    return { success: true };
  }

  async handleWebhook(req) {
    if (!inboundAllowed(this.config, req)) return { handled: false, status: 403, body: 'Forbidden' };
    const events = Array.isArray(req.body?.events) ? req.body.events : [];
    for (const event of events) {
      const content = event.message?.text || '';
      if (!content) continue;
      this.emit('message', {
        platform: 'line',
        chatId: String(event.source?.groupId || event.source?.roomId || event.source?.userId || 'line'),
        sender: String(event.source?.userId || 'line'),
        senderName: null,
        content: String(content),
        mediaType: null,
        isGroup: Boolean(event.source?.groupId || event.source?.roomId),
        messageId: String(event.message?.id || event.webhookEventId || crypto.randomUUID()),
        timestamp: event.timestamp ? new Date(Number(event.timestamp)).toISOString() : new Date().toISOString(),
        rawMessage: event,
      });
    }
    return { handled: true, status: 200, body: 'OK' };
  }
}

class MattermostPlatform extends ConfigurableHttpPlatform {
  constructor(config = {}) {
    super('mattermost', config, { label: 'Mattermost' });
  }

  async connect() {
    if (!this.config.webhookUrl && !this.config.baseUrl && !this.config.inboundSecret) {
      throw new Error('Mattermost webhook URL, base URL, or inbound secret is required');
    }
    this.status = 'connected';
    this.emit('connected');
    return { status: 'connected' };
  }

  async sendMessage(to, content) {
    if (this.config.webhookUrl || this.config.outboundUrl) return super.sendMessage(to, content);
    const baseUrl = trimTrailingSlash(this.config.baseUrl);
    const token = requireText(this.config.token, 'Mattermost token');
    await fetchJson(`${baseUrl}/api/v4/posts`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ channel_id: to, message: content }),
    }, 'Mattermost');
    return { success: true };
  }
}

class IrcPlatform extends BasePlatform {
  constructor(name, config = {}) {
    super(name, config);
    this.supportsGroups = true;
    this.server = config.server || (name === 'twitch' ? 'irc.chat.twitch.tv' : '');
    this.port = Number(config.port || (name === 'twitch' || config.tls ? 6697 : 6667));
    this.tls = config.tls !== false && (name === 'twitch' || config.tls === true);
    this.nick = config.nick || config.nickname || '';
    this.password = config.password || config.oauthToken || '';
    this.channels = String(config.channels || config.channel || '').split(',').map((item) => item.trim()).filter(Boolean);
    this._socket = null;
    this._buffer = '';
    if (Array.isArray(config.allowedIds || config.allowedEntries)) {
      this.setAllowedEntries(config.allowedIds || config.allowedEntries);
    }
  }

  async connect() {
    requireText(this.server, `${this.name} server`);
    requireText(this.nick, `${this.name} nickname`);
    return new Promise((resolve, reject) => {
      const socketFactory = this.tls ? tls.connect : net.connect;
      let settled = false;
      let timeout;
      const fail = (err) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        try { socket.destroy(); } catch {}
        reject(err);
      };
      const succeed = (value) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        resolve(value);
      };
      const socket = socketFactory({ host: this.server, port: this.port }, () => {
        this._socket = socket;
        if (this.password) this.#write(`PASS ${this.password}`);
        this.#write(`NICK ${this.nick}`);
        this.#write(`USER ${this.nick} 0 * :${this.nick}`);
        for (const channel of this.channels) this.#write(`JOIN ${this.#channel(channel)}`);
        this.status = 'connected';
        this.emit('connected');
        succeed({ status: 'connected' });
      });
      timeout = setTimeout(() => fail(new Error(`${this.name} connection timed out`)), 20000);
      socket.once('connect', () => clearTimeout(timeout));
      socket.once('error', (err) => {
        clearTimeout(timeout);
        if (this.status !== 'connected') fail(err);
        else console.error(`[${this.name}] IRC error:`, err.message);
      });
      socket.on('data', (chunk) => this.#handleData(chunk));
      socket.on('close', () => {
        this.status = 'disconnected';
        this.emit('disconnected', { manual: false });
      });
    });
  }

  async disconnect() {
    if (this._socket) {
      try { this.#write('QUIT :NeoAgent disconnecting'); } catch {}
      this._socket.destroy();
      this._socket = null;
    }
    this.status = 'disconnected';
    this.emit('disconnected', { manual: true });
  }

  async logout() { await this.disconnect(); }

  getAuthInfo() {
    return this.nick ? { username: this.nick } : null;
  }

  #channel(value) {
    const text = String(value || '').trim();
    return text.startsWith('#') ? text : `#${text}`;
  }

  #write(line) {
    if (!this._socket) return;
    this._socket.write(`${line}\r\n`);
  }

  #handleData(chunk) {
    this._buffer += chunk.toString('utf8');
    const lines = this._buffer.split(/\r?\n/);
    this._buffer = lines.pop() || '';
    for (const line of lines) {
      if (line.startsWith('PING ')) {
        this.#write(`PONG ${line.slice(5)}`);
        continue;
      }
      const match = line.match(/^:([^! ]+)!?[^ ]* PRIVMSG ([^ ]+) :(.+)$/);
      if (!match) continue;
      const [, nick, target, content] = match;
      if (nick === this.nick) continue;
      this.emit('message', {
        platform: this.name,
        chatId: target,
        sender: nick,
        senderName: nick,
        content,
        mediaType: null,
        isGroup: target.startsWith('#'),
        messageId: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
      });
    }
  }

  async sendMessage(to, content) {
    if (!this._socket || this.status !== 'connected') throw new Error(`${this.name} not connected`);
    this.#write(`PRIVMSG ${to} :${String(content).replace(/\r?\n/g, ' ')}`);
    return { success: true };
  }
}

const genericPlatformSpecs = {
  feishu: { label: 'Feishu', contentField: 'text' },
  nextcloud_talk: { label: 'Nextcloud Talk', contentField: 'message' },
  nostr: { label: 'Nostr', contentField: 'content' },
  synology_chat: { label: 'Synology Chat', contentField: 'text' },
  tlon: { label: 'Tlon', contentField: 'text' },
  zalo: { label: 'Zalo', contentField: 'message' },
  zalo_personal: { label: 'Zalo Personal', contentField: 'message' },
  wechat: { label: 'WeChat', contentField: 'content' },
  webchat: { label: 'WebChat', contentField: 'content' },
};

function createGenericPlatformClass(name) {
  return class extends ConfigurableHttpPlatform {
    constructor(config = {}) {
      super(name, config, genericPlatformSpecs[name] || { label: name });
    }
  };
}

module.exports = {
  SlackPlatform,
  GoogleChatPlatform,
  TeamsPlatform,
  MatrixPlatform,
  SignalPlatform,
  LinePlatform,
  MattermostPlatform,
  IrcPlatform,
  BlueBubblesPlatform,
  createGenericPlatformClass,
};
