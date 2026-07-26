'use strict';

const crypto = require('crypto');
const db = require('../../db/database');
const { resolveAgentId } = require('../agents/manager');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { validateCloudUrlWithDns } = require('../../utils/cloud-security');

const ALLOWED_HTTP_METHODS = new Set(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
const ALLOWED_AUTH_TYPES = new Set(['bearer', 'basic', 'header']);
const PROTECTED_FILL_TTL_MS = 5 * 60 * 1000;
const MAX_RESPONSE_BYTES = 512 * 1024;

function parseJson(value, fallback = {}) {
  try {
    const parsed = JSON.parse(String(value || ''));
    return parsed && typeof parsed === 'object' ? parsed : fallback;
  } catch {
    return fallback;
  }
}

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

function normalizeHttpsOrigin(value) {
  const url = new URL(requireText(value, 'Origin'));
  if (url.protocol !== 'https:' || url.username || url.password) {
    throw new Error('Credential targets must use an HTTPS origin without embedded credentials.');
  }
  return url.origin;
}

function normalizePathPrefix(value) {
  const text = String(value || '/').trim() || '/';
  if (
    !text.startsWith('/')
    || text.includes('\\')
    || /(?:^|\/)\.\.?($|\/)/.test(text)
    || /%(?:2e|2f|5c)/i.test(text)
  ) {
    throw new Error('Credential API path prefixes must start with /.');
  }
  return text;
}

function itemOrigins(item) {
  const values = Array.isArray(item?.login?.uris) ? item.login.uris : [];
  const origins = new Set();
  for (const entry of values) {
    try {
      origins.add(normalizeHttpsOrigin(entry?.uri));
    } catch {
      // Ignore non-HTTPS and malformed vault URIs.
    }
  }
  return Array.from(origins).sort();
}

function sanitizeItem(item) {
  const username = String(item?.login?.username || '');
  const fields = Array.isArray(item?.fields) ? item.fields : [];
  return {
    id: String(item?.id || ''),
    name: String(item?.name || 'Untitled'),
    usernameMasked: username
      ? `${username.slice(0, 1)}${'*'.repeat(Math.min(8, Math.max(3, username.length - 2)))}${username.length > 1 ? username.slice(-1) : ''}`
      : '',
    origins: itemOrigins(item),
    hasPassword: Boolean(item?.login && Object.hasOwn(item.login, 'password')),
    fields: fields.map((field) => ({
      id: String(field?.id || ''),
      name: String(field?.name || ''),
      type: Number(field?.type || 0),
    })).filter((field) => field.id || field.name),
  };
}

function readItemField(item, reference) {
  const ref = String(reference || '').trim();
  if (ref === 'login.username') return String(item?.login?.username || '');
  if (ref === 'login.password') return String(item?.login?.password || '');
  const fields = Array.isArray(item?.fields) ? item.fields : [];
  const field = fields.find((candidate) =>
    String(candidate?.id || '') === ref || String(candidate?.name || '') === ref
  );
  return String(field?.value || '');
}

function encodeSecretVariants(value) {
  const text = String(value || '');
  if (!text) return [];
  return Array.from(new Set([
    text,
    encodeURIComponent(text),
    Buffer.from(text, 'utf8').toString('base64'),
    Buffer.from(text, 'utf8').toString('base64url'),
    Buffer.from(text, 'utf8').toString('hex'),
  ].filter(Boolean))).sort((left, right) => right.length - left.length);
}

function redactResolvedValues(value, resolvedValues) {
  let text = String(value || '');
  for (const resolved of resolvedValues) {
    for (const variant of encodeSecretVariants(resolved)) {
      text = text.split(variant).join('[redacted]');
    }
  }
  return text;
}

function safeResponseHeaders(headers, resolvedValues = []) {
  const blocked = new Set([
    'authorization',
    'cookie',
    'set-cookie',
    'proxy-authenticate',
    'proxy-authorization',
    'www-authenticate',
  ]);
  return Object.fromEntries(
    Array.from(headers.entries())
      .filter(([name]) => !blocked.has(name.toLowerCase()))
      .map(([name, value]) => [name, redactResolvedValues(value, resolvedValues)]),
  );
}

function pathMatchesPrefix(pathname, prefix) {
  if (prefix === '/') return true;
  const normalized = prefix.endsWith('/') ? prefix.slice(0, -1) : prefix;
  return pathname === normalized || pathname.startsWith(`${normalized}/`);
}

class CredentialBroker {
  constructor(options = {}) {
    this.bitwarden = options.bitwarden;
    this.runtimeManager = options.runtimeManager || null;
    this.protectedFills = new Map();
  }

  setRuntimeManager(runtimeManager) {
    this.runtimeManager = runtimeManager;
  }

  #scope(userId, agentId) {
    const normalizedUserId = Number(userId);
    if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
      throw new Error('A valid user is required.');
    }
    return {
      userId: normalizedUserId,
      agentId: resolveAgentId(normalizedUserId, agentId || null),
    };
  }

  #bindingRow(userId, agentId, bindingId) {
    return db.prepare(
      `SELECT * FROM credential_bindings
       WHERE id = ? AND user_id = ? AND agent_id = ?`,
    ).get(String(bindingId || ''), userId, agentId) || null;
  }

  #decodeBinding(row) {
    if (!row) return null;
    return {
      id: row.id,
      alias: row.alias,
      providerKey: row.provider_key,
      connectionId: row.connection_id,
      usageType: row.usage_type,
      itemRef: decryptValue(row.item_ref_encrypted),
      fieldConfig: parseJson(decryptValue(row.field_config_encrypted), {}),
      targetConfig: parseJson(row.target_config_json, {}),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  #publicBinding(row) {
    const binding = this.#decodeBinding(row);
    return binding && {
      id: binding.id,
      alias: binding.alias,
      providerKey: binding.providerKey,
      usageType: binding.usageType,
      target: binding.usageType === 'browser'
        ? { origins: binding.targetConfig.origins || [] }
        : {
          origin: binding.targetConfig.origin,
          pathPrefix: binding.targetConfig.pathPrefix,
          methods: binding.targetConfig.methods || [],
          authType: binding.targetConfig.authType,
          headerName: binding.targetConfig.authType === 'header'
            ? binding.targetConfig.headerName
            : undefined,
        },
      createdAt: binding.createdAt,
      updatedAt: binding.updatedAt,
    };
  }

  listBindings(userId, agentId) {
    const scope = this.#scope(userId, agentId);
    return db.prepare(
      `SELECT * FROM credential_bindings
       WHERE user_id = ? AND agent_id = ?
       ORDER BY lower(alias), created_at`,
    ).all(scope.userId, scope.agentId).map((row) => this.#publicBinding(row));
  }

  async listVaultItems(userId, agentId, options = {}) {
    const scope = this.#scope(userId, agentId);
    await this.bitwarden.sync(scope.userId, scope.agentId, options);
    const items = await this.bitwarden.listItems(scope.userId, scope.agentId, options);
    return items.map(sanitizeItem).filter((item) => item.id);
  }

  async #bindingValues(scope, input, options = {}) {
    const alias = requireText(input?.alias, 'Binding alias').slice(0, 120);
    const usageType = String(input?.usageType || '').trim();
    if (!['browser', 'http'].includes(usageType)) {
      throw new Error('Binding usageType must be browser or http.');
    }
    const connectionId = Number(input?.connectionId);
    if (!Number.isInteger(connectionId) || connectionId <= 0) {
      throw new Error('A connected Bitwarden account is required.');
    }
    const connection = db.prepare(
      `SELECT id FROM integration_connections
       WHERE id = ? AND user_id = ? AND agent_id = ?
         AND provider_key = 'bitwarden' AND status = 'connected'`,
    ).get(connectionId, scope.userId, scope.agentId);
    if (!connection) throw new Error('The Bitwarden connection was not found.');
    const itemRef = requireText(input?.itemId, 'Bitwarden item');
    const item = await this.bitwarden.getItem(scope.userId, scope.agentId, itemRef, options);
    let fieldConfig;
    let targetConfig;

    if (usageType === 'browser') {
      const availableOrigins = itemOrigins(item);
      const requested = Array.isArray(input?.origins) ? input.origins.map(normalizeHttpsOrigin) : [];
      const origins = requested.length > 0 ? requested : availableOrigins;
      if (origins.length === 0 || origins.some((origin) => !availableOrigins.includes(origin))) {
        throw new Error('Browser credential origins must be selected from HTTPS URIs saved on the Bitwarden item.');
      }
      if (!readItemField(item, 'login.password')) {
        throw new Error('The selected Bitwarden item does not contain a login password.');
      }
      fieldConfig = {
        usernameField: 'login.username',
        passwordField: 'login.password',
      };
      targetConfig = { origins: Array.from(new Set(origins)).sort() };
    } else {
      const authType = String(input?.authType || '').trim().toLowerCase();
      if (!ALLOWED_AUTH_TYPES.has(authType)) {
        throw new Error('HTTP authType must be bearer, basic, or header.');
      }
      const secretField = requireText(input?.secretField, 'Secret field');
      if (!readItemField(item, secretField)) {
        throw new Error('The selected Bitwarden secret field is empty.');
      }
      const origin = normalizeHttpsOrigin(input?.origin);
      const pathPrefix = normalizePathPrefix(input?.pathPrefix);
      const methods = Array.from(new Set(
        (Array.isArray(input?.methods) ? input.methods : ['GET'])
          .map((method) => String(method || '').toUpperCase())
          .filter((method) => ALLOWED_HTTP_METHODS.has(method)),
      ));
      if (methods.length === 0) throw new Error('At least one supported HTTP method is required.');
      const headerName = authType === 'header'
        ? requireText(input?.headerName, 'Header name')
        : null;
      if (headerName && !/^[A-Za-z0-9-]+$/.test(headerName)) {
        throw new Error('Credential header names may contain only letters, numbers, and hyphens.');
      }
      if (headerName && ['authorization', 'cookie', 'set-cookie'].includes(headerName.toLowerCase())) {
        throw new Error('Use bearer or basic authentication for reserved authentication headers.');
      }
      fieldConfig = {
        secretField,
        usernameField: authType === 'basic'
          ? requireText(input?.usernameField, 'Username field')
          : null,
      };
      targetConfig = { origin, pathPrefix, methods, authType, headerName };
    }
    return { alias, usageType, connectionId, itemRef, fieldConfig, targetConfig };
  }

  async createBinding(userId, agentId, input, options = {}) {
    const scope = this.#scope(userId, agentId);
    const values = await this.#bindingValues(scope, input, options);
    const id = crypto.randomUUID();
    db.prepare(
      `INSERT INTO credential_bindings (
         id, user_id, agent_id, provider_key, connection_id, alias, usage_type,
         item_ref_encrypted, field_config_encrypted, target_config_json
       ) VALUES (?, ?, ?, 'bitwarden', ?, ?, ?, ?, ?, ?)`,
    ).run(
      id,
      scope.userId,
      scope.agentId,
      values.connectionId,
      values.alias,
      values.usageType,
      encryptValue(values.itemRef),
      encryptValue(JSON.stringify(values.fieldConfig)),
      JSON.stringify(values.targetConfig),
    );
    return this.#publicBinding(this.#bindingRow(scope.userId, scope.agentId, id));
  }

  async updateBinding(userId, agentId, bindingId, input, options = {}) {
    const scope = this.#scope(userId, agentId);
    const current = this.#decodeBinding(this.#bindingRow(scope.userId, scope.agentId, bindingId));
    if (!current) throw new Error('Credential binding not found.');
    const values = await this.#bindingValues(scope, {
      ...input,
      alias: input?.alias ?? current.alias,
      usageType: input?.usageType ?? current.usageType,
      connectionId: input?.connectionId ?? current.connectionId,
      itemId: input?.itemId ?? current.itemRef,
      origins: input?.origins ?? current.targetConfig.origins,
      origin: input?.origin ?? current.targetConfig.origin,
      pathPrefix: input?.pathPrefix ?? current.targetConfig.pathPrefix,
      methods: input?.methods ?? current.targetConfig.methods,
      authType: input?.authType ?? current.targetConfig.authType,
      headerName: input?.headerName ?? current.targetConfig.headerName,
      secretField: input?.secretField ?? current.fieldConfig.secretField,
      usernameField: input?.usernameField ?? current.fieldConfig.usernameField,
    }, options);
    db.prepare(
      `UPDATE credential_bindings
       SET connection_id = ?, alias = ?, usage_type = ?, item_ref_encrypted = ?,
           field_config_encrypted = ?, target_config_json = ?, updated_at = datetime('now')
       WHERE id = ? AND user_id = ? AND agent_id = ?`,
    ).run(
      values.connectionId,
      values.alias,
      values.usageType,
      encryptValue(values.itemRef),
      encryptValue(JSON.stringify(values.fieldConfig)),
      JSON.stringify(values.targetConfig),
      String(bindingId || ''),
      scope.userId,
      scope.agentId,
    );
    return this.#publicBinding(this.#bindingRow(scope.userId, scope.agentId, bindingId));
  }

  deleteBinding(userId, agentId, bindingId) {
    const scope = this.#scope(userId, agentId);
    const result = db.prepare(
      'DELETE FROM credential_bindings WHERE id = ? AND user_id = ? AND agent_id = ?',
    ).run(String(bindingId || ''), scope.userId, scope.agentId);
    return { deleted: result.changes > 0 };
  }

  #audit(scope, bindingId, operation, target, outcome, errorCode = null, runId = null) {
    db.prepare(
      `INSERT INTO credential_usage_audit (
         id, user_id, agent_id, run_id, binding_id, operation, target, outcome, error_code
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      crypto.randomUUID(),
      scope.userId,
      scope.agentId,
      runId || null,
      bindingId || null,
      operation,
      target || null,
      outcome,
      errorCode || null,
    );
  }

  async #resolveBindingItem(scope, binding, work, options = {}) {
    if (binding.providerKey !== 'bitwarden') {
      throw new Error(`Unsupported credential provider: ${binding.providerKey}`);
    }
    await this.bitwarden.sync(scope.userId, scope.agentId, options);
    const item = await this.bitwarden.getItem(scope.userId, scope.agentId, binding.itemRef, options);
    return work(item);
  }

  async fillBrowser(userId, agentId, input, context = {}) {
    const scope = this.#scope(userId, agentId);
    const binding = this.#decodeBinding(this.#bindingRow(scope.userId, scope.agentId, input?.binding_id));
    if (!binding || binding.usageType !== 'browser') throw new Error('Browser credential binding not found.');
    if (!this.runtimeManager) throw new Error('Browser runtime is unavailable.');
    const provider = await this.runtimeManager.getBrowserProviderForUser(scope.userId);
    if (!provider || typeof provider.fillCredential !== 'function') {
      throw new Error('The selected browser backend does not support protected credential fill.');
    }
    const page = await provider.getPageInfo();
    const origin = page?.url ? new URL(page.url).origin : '';
    if (!binding.targetConfig.origins?.includes(origin)) {
      throw new Error(`Credential binding ${binding.alias} is not allowed on the current browser origin.`);
    }

    try {
      const result = await this.#resolveBindingItem(scope, binding, async (item) => {
        const username = readItemField(item, binding.fieldConfig.usernameField);
        const password = readItemField(item, binding.fieldConfig.passwordField);
        const requestedStage = String(input?.stage || 'both');
        if (!['username', 'password', 'both'].includes(requestedStage)) {
          throw new Error('Credential stage must be username, password, or both.');
        }
        const stage = requestedStage;
        const usernameSelector = String(input?.username_selector || '').trim();
        const passwordSelector = String(input?.password_selector || '').trim();
        if (stage !== 'password' && !usernameSelector) {
          throw new Error('Username selector is required for this credential stage.');
        }
        if (stage !== 'username' && !passwordSelector) {
          throw new Error('Password selector is required for this credential stage.');
        }
        if (stage !== 'username' && !password) {
          throw new Error('The bound Bitwarden password is empty.');
        }
        return provider.fillCredential({
          usernameSelector: stage === 'password' ? '' : usernameSelector,
          passwordSelector: stage === 'username' ? '' : passwordSelector,
          username: stage === 'password' ? '' : username,
          password: stage === 'username' ? '' : password,
          allowedOrigin: origin,
        });
      });
      const protectedFillId = String(result?.protectedFillId || crypto.randomUUID());
      this.protectedFills.set(protectedFillId, {
        userId: scope.userId,
        agentId: scope.agentId,
        bindingId: binding.id,
        runId: context.runId || null,
        expiresAt: Date.now() + PROTECTED_FILL_TTL_MS,
      });
      this.#audit(scope, binding.id, 'browser_fill', origin, 'success', null, context.runId);
      return {
        success: true,
        protected_fill_id: protectedFillId,
        binding: binding.alias,
        origin,
        protected: true,
        message: 'Credentials filled in protected mode. Submit or cancel the protected form.',
      };
    } catch (error) {
      this.#audit(scope, binding.id, 'browser_fill', origin, 'failed', error.code, context.runId);
      throw error;
    }
  }

  async submitProtected(userId, agentId, protectedFillId, context = {}) {
    const scope = this.#scope(userId, agentId);
    const entry = this.protectedFills.get(String(protectedFillId || ''));
    if (!entry || entry.userId !== scope.userId || entry.agentId !== scope.agentId) {
      throw new Error('Protected browser fill is missing or expired.');
    }
    const provider = await this.runtimeManager.getBrowserProviderForUser(scope.userId);
    if (entry.expiresAt <= Date.now()) {
      await provider.cancelProtectedCredential(String(protectedFillId)).catch(() => {});
      this.protectedFills.delete(String(protectedFillId));
      throw new Error('Protected browser fill expired and was cleared.');
    }
    const result = await provider.submitProtectedCredential(String(protectedFillId));
    this.protectedFills.delete(String(protectedFillId));
    this.#audit(scope, entry.bindingId, 'browser_submit', result?.url || null, 'success', null, context.runId);
    return result;
  }

  async cancelProtected(userId, agentId, protectedFillId, context = {}) {
    const scope = this.#scope(userId, agentId);
    const entry = this.protectedFills.get(String(protectedFillId || ''));
    if (!entry || entry.userId !== scope.userId || entry.agentId !== scope.agentId) {
      throw new Error('Protected browser fill is missing or expired.');
    }
    const provider = await this.runtimeManager.getBrowserProviderForUser(scope.userId);
    const result = await provider.cancelProtectedCredential(String(protectedFillId));
    this.protectedFills.delete(String(protectedFillId));
    this.#audit(scope, entry.bindingId, 'browser_cancel', null, 'success', null, context.runId);
    return result;
  }

  async httpRequest(userId, agentId, input, context = {}) {
    const scope = this.#scope(userId, agentId);
    const binding = this.#decodeBinding(this.#bindingRow(scope.userId, scope.agentId, input?.binding_id));
    if (!binding || binding.usageType !== 'http') throw new Error('HTTP credential binding not found.');
    const method = String(input?.method || 'GET').toUpperCase();
    const url = new URL(requireText(input?.url, 'Request URL'));
    const target = binding.targetConfig;
    if (
      url.protocol !== 'https:'
      || /%(?:2e|2f|5c)/i.test(url.pathname)
      || url.origin !== target.origin
      || !pathMatchesPrefix(url.pathname, target.pathPrefix)
      || !target.methods.includes(method)
    ) {
      throw new Error('Credential request does not match the binding target policy.');
    }
    const validation = await validateCloudUrlWithDns(url.toString(), { signal: context.signal });
    if (!validation.allowed) throw new Error('Credential request target is not allowed.');
    const headers = Object.fromEntries(Object.entries(input?.headers || {}).map(([name, value]) => [
      String(name),
      String(value),
    ]));
    const blockedNames = new Set(['authorization', 'cookie', String(target.headerName || '').toLowerCase()]);
    if (Object.keys(headers).some((name) => blockedNames.has(name.toLowerCase()))) {
      throw new Error('Authentication and cookie headers are controlled by the credential binding.');
    }

    try {
      return await this.#resolveBindingItem(scope, binding, async (item) => {
        const secret = readItemField(item, binding.fieldConfig.secretField);
        const username = binding.fieldConfig.usernameField
          ? readItemField(item, binding.fieldConfig.usernameField)
          : '';
        if (!secret) throw new Error('The bound Bitwarden secret is empty.');
        if (target.authType === 'bearer') headers.Authorization = `Bearer ${secret}`;
        if (target.authType === 'basic') {
          headers.Authorization = `Basic ${Buffer.from(`${username}:${secret}`, 'utf8').toString('base64')}`;
        }
        if (target.authType === 'header') headers[target.headerName] = secret;
        const controller = new AbortController();
        const timeoutMs = Math.max(1000, Math.min(Number(input?.timeout_ms || 30_000), 120_000));
        const timer = setTimeout(() => controller.abort(), timeoutMs);
        const onAbort = () => controller.abort();
        context.signal?.addEventListener('abort', onAbort, { once: true });
        try {
          const response = await fetch(url, {
            method,
            headers,
            body: ['POST', 'PUT', 'PATCH'].includes(method) && input?.body != null
              ? String(input.body)
              : undefined,
            redirect: 'manual',
            signal: controller.signal,
          });
          const chunks = [];
          let byteCount = 0;
          const reader = response.body?.getReader();
          if (reader) {
            while (byteCount <= MAX_RESPONSE_BYTES) {
              const { done, value } = await reader.read();
              if (done) break;
              const chunk = Buffer.from(value);
              chunks.push(chunk);
              byteCount += chunk.length;
            }
            if (byteCount > MAX_RESPONSE_BYTES) await reader.cancel().catch(() => {});
          }
          const bytes = Buffer.concat(chunks);
          const truncated = byteCount > MAX_RESPONSE_BYTES;
          const body = bytes.subarray(0, MAX_RESPONSE_BYTES).toString('utf8');
          const resolvedValues = [secret, username, `${username}:${secret}`, `Bearer ${secret}`];
          this.#audit(scope, binding.id, 'http_request', `${method} ${url.origin}${url.pathname}`, 'success', null, context.runId);
          return {
            status: response.status,
            headers: safeResponseHeaders(response.headers, resolvedValues),
            body: redactResolvedValues(body, resolvedValues),
            truncated,
          };
        } finally {
          clearTimeout(timer);
          context.signal?.removeEventListener('abort', onAbort);
        }
      }, { signal: context.signal });
    } catch (error) {
      this.#audit(scope, binding.id, 'http_request', `${method} ${url.origin}${url.pathname}`, 'failed', error.code, context.runId);
      throw error;
    }
  }

  summarizeBindings(userId, agentId) {
    const bindings = this.listBindings(userId, agentId);
    if (bindings.length === 0) return 'No Bitwarden credential bindings are configured.';
    return bindings.map((binding) => {
      const targets = binding.usageType === 'browser'
        ? binding.target.origins.join(', ')
        : `${binding.target.methods.join('/')} ${binding.target.origin}${binding.target.pathPrefix}`;
      return `${binding.id}: ${binding.alias} (${binding.usageType}; ${targets})`;
    }).join('; ');
  }
}

module.exports = {
  CredentialBroker,
  itemOrigins,
  readItemField,
  redactResolvedValues,
  sanitizeItem,
};
