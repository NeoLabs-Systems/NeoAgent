"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const db = require("../../../db/database");
const { resolveAgentId } = require("../../agents/manager");
const {
  getProviderConfig,
  setProviderConfig,
  deleteProviderConfig,
} = require("../provider_config_store");
const { getConnectionAccessMode } = require("../access");
const { decryptValue } = require("../secrets");
const { appendQuery, fetchJson } = require("../oauth_provider");
const { fetchResponseText } = require("../http");
const { resolvePublicBaseUrl } = require("../env");

const KEY = "neoarchive";
const MAX_UPLOAD_BYTES = 100 * 1024 * 1024;
const APP = Object.freeze({
  id: "archive",
  label: "Archive",
  description:
    "Search, manage, and upload documents in a connected NeoArchive account.",
});
const SCOPES = Object.freeze([
  "documents:read",
  "documents:write",
  "search:read",
  "labels:read",
  "authors:read",
  "document-types:read",
]);
const TOOLS = Object.freeze(
  [
    {
      name: "neoarchive_list_documents",
      access: "read",
      description: "List documents in NeoArchive.",
      parameters: {
        type: "object",
        properties: {
          status: { type: "string" },
          archived: { type: "boolean" },
          limit: { type: "number" },
          offset: { type: "number" },
        },
      },
    },
    {
      name: "neoarchive_search_documents",
      access: "read",
      description: "Search NeoArchive documents by text or semantic query.",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string" },
          mode: { type: "string", enum: ["fulltext", "semantic", "hybrid"] },
          limit: { type: "number" },
        },
        required: ["query"],
      },
    },
    {
      name: "neoarchive_get_document",
      access: "read",
      description: "Get NeoArchive document metadata and detail.",
      parameters: {
        type: "object",
        properties: { document_id: { type: "string" } },
        required: ["document_id"],
      },
    },
    {
      name: "neoarchive_get_document_text",
      access: "read",
      description: "Get extracted or OCR text for a NeoArchive document.",
      parameters: {
        type: "object",
        properties: { document_id: { type: "string" } },
        required: ["document_id"],
      },
    },
    {
      name: "neoarchive_list_labels",
      access: "read",
      description: "List NeoArchive labels.",
      parameters: { type: "object", properties: {} },
    },
    {
      name: "neoarchive_list_authors",
      access: "read",
      description: "List NeoArchive authors.",
      parameters: { type: "object", properties: {} },
    },
    {
      name: "neoarchive_list_document_types",
      access: "read",
      description: "List NeoArchive document types.",
      parameters: { type: "object", properties: {} },
    },
    {
      name: "neoarchive_upload_document",
      access: "write",
      description: "Upload a readable local file to NeoArchive.",
      parameters: {
        type: "object",
        properties: {
          file_path: {
            type: "string",
            description: "Absolute path to the local file.",
          },
        },
        required: ["file_path"],
      },
    },
    {
      name: "neoarchive_update_document",
      access: "write",
      description: "Update NeoArchive document metadata.",
      parameters: {
        type: "object",
        properties: {
          document_id: { type: "string" },
          metadata: { type: "object" },
        },
        required: ["document_id", "metadata"],
      },
    },
    {
      name: "neoarchive_archive_document",
      access: "write",
      description: "Archive a NeoArchive document.",
      parameters: {
        type: "object",
        properties: { document_id: { type: "string" } },
        required: ["document_id"],
      },
    },
    {
      name: "neoarchive_restore_document",
      access: "write",
      description: "Restore an archived NeoArchive document.",
      parameters: {
        type: "object",
        properties: { document_id: { type: "string" } },
        required: ["document_id"],
      },
    },
    {
      name: "neoarchive_reprocess_document",
      access: "write",
      description: "Queue a NeoArchive document for reprocessing.",
      parameters: {
        type: "object",
        properties: {
          document_id: { type: "string" },
          force_ocr: { type: "boolean" },
        },
        required: ["document_id"],
      },
    },
  ].map((tool) => ({ ...tool, appId: APP.id })),
);

function text(value) {
  return String(value || "").trim();
}
function isPrivateHost(host) {
  const value = String(host || "").toLowerCase();
  return (
    value === "localhost" ||
    value === "::1" ||
    value.startsWith("127.") ||
    value.startsWith("10.") ||
    value.startsWith("192.168.") ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(value)
  );
}
function normalizeBaseUrl(value) {
  const raw = text(value);
  if (!raw) throw new Error("NeoArchive backend URL is required.");
  const candidate = raw.includes("://")
    ? raw
    : `${isPrivateHost(raw.split("/")[0]) ? "http" : "https"}://${raw}`;
  let url;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error(
      "NeoArchive backend URL must be a valid HTTP or HTTPS URL.",
    );
  }
  if (!["http:", "https:"].includes(url.protocol) || url.hash)
    throw new Error(
      "NeoArchive backend URL must be an HTTP or HTTPS URL without a fragment.",
    );
  url.pathname = url.pathname.replace(/\/+$/, "");
  return url.toString().replace(/\/+$/, "");
}
function config(input, existing = {}) {
  return { baseUrl: text(input?.baseUrl) || text(existing.baseUrl) };
}
function callbackUrl() {
  return `${resolvePublicBaseUrl()}/api/integrations/oauth/callback`;
}
function credentials(connection) {
  try {
    return JSON.parse(
      decryptValue(connection.credentials_json || "{}") || "{}",
    );
  } catch {
    return {};
  }
}
function account(connection, env) {
  return !env.configured
    ? {
        id: connection?.id || null,
        status: "env_not_configured",
        connected: false,
        accountEmail: connection?.account_email || null,
      }
    : !connection
      ? {
          id: null,
          status: "not_connected",
          connected: false,
          accountEmail: null,
        }
      : {
          id: connection.id,
          status: connection.status,
          connected: connection.status === "connected",
          accountEmail: connection.account_email || null,
          lastConnectedAt: connection.last_connected_at || null,
          accessMode: getConnectionAccessMode(connection),
        };
}
function snapshot(provider, rows, context) {
  const env = provider.getEnvStatus(context);
  const accounts = rows.map((row) => account(row, env));
  const connected = accounts.filter((item) => item.connected);
  const connection = {
    status: !env.configured
      ? "env_not_configured"
      : connected.length
        ? "connected"
        : "not_connected",
    connected: connected.length > 0,
    accountCount: connected.length,
    accountEmail: connected.length === 1 ? connected[0].accountEmail : null,
    lastConnectedAt:
      connected
        .map((item) => item.lastConnectedAt)
        .filter(Boolean)
        .sort()
        .reverse()[0] || null,
  };
  return {
    id: KEY,
    label: "NeoArchive",
    description: provider.description,
    icon: "neoarchive",
    apps: [
      {
        ...APP,
        accounts,
        connection,
        availableToolCount: connection.connected ? TOOLS.length : 0,
      },
    ],
    env,
    connection,
    availableToolCount: connection.connected ? TOOLS.length : 0,
    connectPrompt: provider.connectPrompt,
    supportsMultipleAccounts: true,
    connectionMethod: "oauth",
  };
}
async function bootstrap(baseUrl, options = {}) {
  return fetchJson(
    `${baseUrl}/api/oauth/companion/neoagent/bootstrap`,
    {
      method: "POST",
      json: { redirectUri: callbackUrl(), appName: "NeoAgent" },
      signal: options.signal,
    },
    { serviceName: "NeoArchive companion bootstrap" },
  );
}
async function token(baseUrl, form, options = {}) {
  return fetchJson(
    `${baseUrl}/oauth/token`,
    { method: "POST", form, signal: options.signal },
    { serviceName: "NeoArchive OAuth token" },
  );
}
async function access(connection, options = {}) {
  const saved = credentials(connection);
  const baseUrl = normalizeBaseUrl(saved.baseUrl);
  if (saved.access_token && Number(saved.expires_at_ms) > Date.now() + 60000)
    return { baseUrl, accessToken: saved.access_token, credentials: saved };
  if (!saved.refresh_token || !saved.client_id)
    throw new Error(
      "NeoArchive refresh token is missing. Reconnect the NeoArchive account.",
    );
  const refreshed = await token(baseUrl, {
    grant_type: "refresh_token",
    client_id: saved.client_id,
    refresh_token: saved.refresh_token,
  }, options);
  const next = {
    ...saved,
    access_token: text(refreshed.access_token),
    refresh_token: text(refreshed.refresh_token) || saved.refresh_token,
    expires_at_ms:
      Date.now() + Math.max(1, Number(refreshed.expires_in) || 3600) * 1000,
    scope: text(refreshed.scope) || saved.scope,
  };
  return { baseUrl, accessToken: next.access_token, credentials: next };
}
async function request(connection, apiPath, options = {}) {
  const auth = await access(connection, options);
  const response = await fetchJson(
    `${auth.baseUrl}${apiPath}`,
    {
      method: options.method || "GET",
      headers: { Authorization: `Bearer ${auth.accessToken}` },
      ...(options.json === undefined ? {} : { json: options.json }),
      signal: options.signal,
    },
    { serviceName: "NeoArchive API" },
  );
  return { response, credentials: auth.credentials };
}
function required(value, name) {
  const normalized = text(value);
  if (!normalized) throw new Error(`${name} is required.`);
  return normalized;
}
async function upload(connection, filePath, options = {}) {
  const raw = text(filePath);
  if (!raw || raw.split(/[\\/]+/).includes(".."))
    throw new Error(
      "file_path must be an absolute readable file path without parent traversal.",
    );
  const resolved = path.resolve(raw);
  const stats = await fs.promises.stat(resolved);
  if (!stats.isFile())
    throw new Error("file_path must point to a readable file.");
  if (stats.size > MAX_UPLOAD_BYTES)
    throw new Error(`file_path exceeds the ${MAX_UPLOAD_BYTES}-byte upload limit.`);
  await fs.promises.access(resolved, fs.constants.R_OK);
  const auth = await access(connection, options);
  const form = new FormData();
  form.append(
    "files",
    new Blob([await fs.promises.readFile(resolved, { signal: options.signal })]),
    path.basename(resolved),
  );
  const { response, text: responseText } = await fetchResponseText(
    `${auth.baseUrl}/api/v1/documents`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${auth.accessToken}` },
      body: form,
      signal: options.signal,
      timeoutMs: 120000,
    },
    { serviceName: "NeoArchive upload" },
  );
  let result = null;
  try {
    result = responseText ? JSON.parse(responseText) : null;
  } catch {
    result = null;
  }
  if (!response.ok)
    throw new Error(
      `NeoArchive upload request failed: ${result?.error || response.statusText}`,
    );
  return { result, credentials: auth.credentials };
}
async function execute(toolName, args, connection, options = {}) {
  let pathName;
  let method = "GET";
  let json;
  const query = {};
  switch (toolName) {
    case "neoarchive_list_documents":
      ["status", "archived", "limit", "offset"].forEach((key) => {
        if (args[key] !== undefined) query[key] = args[key];
      });
      pathName = appendQuery("/api/v1/documents", query);
      break;
    case "neoarchive_search_documents":
      pathName = appendQuery("/api/v1/search", {
        q: required(args.query, "query"),
        mode: text(args.mode) || undefined,
        limit: args.limit,
      });
      break;
    case "neoarchive_get_document":
      pathName = `/api/v1/documents/${encodeURIComponent(required(args.document_id, "document_id"))}`;
      break;
    case "neoarchive_get_document_text":
      pathName = `/api/v1/documents/${encodeURIComponent(required(args.document_id, "document_id"))}/text`;
      break;
    case "neoarchive_list_labels":
      pathName = "/api/v1/labels";
      break;
    case "neoarchive_list_authors":
      pathName = "/api/v1/authors";
      break;
    case "neoarchive_list_document_types":
      pathName = "/api/v1/document-types";
      break;
    case "neoarchive_upload_document":
      return upload(connection, args.file_path, options);
    case "neoarchive_update_document":
      pathName = `/api/v1/documents/${encodeURIComponent(required(args.document_id, "document_id"))}`;
      method = "PATCH";
      json =
        args.metadata && typeof args.metadata === "object" ? args.metadata : {};
      break;
    case "neoarchive_archive_document":
      pathName = `/api/v1/documents/${encodeURIComponent(required(args.document_id, "document_id"))}/archive`;
      method = "POST";
      json = {};
      break;
    case "neoarchive_restore_document":
      pathName = `/api/v1/documents/${encodeURIComponent(required(args.document_id, "document_id"))}/restore`;
      method = "POST";
      json = {};
      break;
    case "neoarchive_reprocess_document":
      pathName = `/api/v1/documents/${encodeURIComponent(required(args.document_id, "document_id"))}/reprocess`;
      method = "POST";
      json = { forceOcr: args.force_ocr === true };
      break;
    default:
      throw new Error(`Unsupported NeoArchive tool: ${toolName}`);
  }
  const result = await request(connection, pathName, {
    method,
    json,
    signal: options.signal,
  });
  return { result: result.response, credentials: result.credentials };
}

function createNeoArchiveProvider() {
  return {
    key: KEY,
    label: "NeoArchive",
    description:
      "Connect a self-hosted NeoArchive server to search, organize, and upload documents.",
    icon: "neoarchive",
    apps: [APP],
    connectPrompt:
      "Add the NeoArchive backend URL once, then authorize NeoAgent with OAuth.",
    supportsMultipleAccounts: true,
    connectionMethod: "user_config",
    requiresRefreshToken: true,
    getApp(appId) {
      return text(appId) === APP.id ? APP : null;
    },
    getToolAppId(name) {
      return TOOLS.some((tool) => tool.name === text(name)) ? APP.id : null;
    },
    getEnvStatus(context = {}) {
      const userId = Number(context.userId);
      const stored =
        Number.isInteger(userId) && userId > 0
          ? config(getProviderConfig(userId, KEY, context.agentId))
          : { baseUrl: "" };
      const configured = Boolean(stored.baseUrl);
      return {
        configured,
        missing: configured ? [] : ["baseUrl"],
        summary: configured
          ? "NeoArchive is ready for account connections."
          : "Add the NeoArchive backend URL to enable account connections.",
        setupMode: "user",
      };
    },
    getToolDefinitions(options = {}) {
      return new Set(options.connectedAppIds || []).has(APP.id)
        ? TOOLS.slice()
        : [];
    },
    supportsTool(name) {
      return TOOLS.some((tool) => tool.name === text(name));
    },
    buildSnapshot(rows, context = {}) {
      return snapshot(this, rows, context);
    },
    summarizeForModel(item) {
      return !item?.env?.configured
        ? "NeoArchive: setup is not complete yet."
        : !item.connection?.connected
          ? "NeoArchive: setup is ready, but no archive account is connected."
          : "NeoArchive: connected with document search, metadata, text, upload, archive, and reprocessing tools.";
    },
    async beginOAuth({ state, codeVerifier, userId, agentId, appKey, signal }) {
      if (text(appKey) !== APP.id) throw new Error("Unknown NeoArchive app.");
      const stored = config(
        getProviderConfig(
          Number(userId),
          KEY,
          resolveAgentId(Number(userId), agentId),
        ),
      );
      const baseUrl = normalizeBaseUrl(stored.baseUrl);
      const boot = await bootstrap(baseUrl, { signal });
      const challenge = crypto
        .createHash("sha256")
        .update(String(codeVerifier))
        .digest("base64url");
      return {
        url: appendQuery(
          text(boot.authorizationEndpoint) || `${baseUrl}/oauth/authorize`,
          {
            response_type: "code",
            client_id: boot.clientId,
            redirect_uri: text(boot.redirectUri) || callbackUrl(),
            state,
            code_challenge: challenge,
            code_challenge_method: "S256",
            scope: Array.isArray(boot.scopes)
              ? boot.scopes.join(" ")
              : SCOPES.join(" "),
          },
        ),
      };
    },
    async finishOAuth({ userId, agentId, code, codeVerifier, signal }) {
      const stored = config(
        getProviderConfig(
          Number(userId),
          KEY,
          resolveAgentId(Number(userId), agentId),
        ),
      );
      const baseUrl = normalizeBaseUrl(stored.baseUrl);
      const boot = await bootstrap(baseUrl, { signal });
      const issued = await token(baseUrl, {
        grant_type: "authorization_code",
        client_id: boot.clientId,
        code: text(code),
        redirect_uri: text(boot.redirectUri) || callbackUrl(),
        code_verifier: text(codeVerifier),
      }, { signal });
      const accessToken = text(issued.access_token);
      const refreshToken = text(issued.refresh_token);
      if (!accessToken || !refreshToken)
        throw new Error("NeoArchive did not return durable OAuth credentials.");
      const info = await fetchJson(
        `${baseUrl}/oauth/userinfo`,
        {
          headers: { Authorization: `Bearer ${accessToken}` },
          signal,
        },
        { serviceName: "NeoArchive userinfo" },
      );
      const host = new URL(baseUrl).host;
      const accountEmail =
        text(info.email) ||
        text(info.preferred_username) ||
        `neoarchive:${host}`;
      return {
        accountEmail,
        scopes: text(issued.scope).split(/\s+/).filter(Boolean),
        credentials: {
          baseUrl,
          client_id: text(boot.clientId),
          access_token: accessToken,
          refresh_token: refreshToken,
          scope: text(issued.scope),
          expires_at_ms:
            Date.now() + Math.max(1, Number(issued.expires_in) || 3600) * 1000,
        },
        metadata: {
          baseUrl,
          username: text(info.preferred_username),
          email: text(info.email) || null,
        },
      };
    },
    async executeTool(toolName, args, connection, executionOptions = {}) {
      return execute(toolName, args || {}, connection, {
        signal: executionOptions.signal || null,
      });
    },
    async testConnection(connection, executionOptions = {}) {
      const result = await request(connection, "/oauth/userinfo", {
        signal: executionOptions.signal || null,
      });
      return { credentials: result.credentials };
    },
    getUserConfig({ userId, agentId }) {
      const scoped = resolveAgentId(Number(userId), agentId);
      const stored = config(getProviderConfig(Number(userId), KEY, scoped));
      const accountCount =
        db
          .prepare(
            "SELECT COUNT(*) AS count FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND status = 'connected'",
          )
          .get(userId, scoped, KEY)?.count || 0;
      return {
        baseUrl: stored.baseUrl,
        configured: Boolean(stored.baseUrl),
        accountCount,
        hasConnectedAccount: accountCount > 0,
      };
    },
    async saveUserConfig({ userId, agentId, config: input, signal }) {
      const scoped = resolveAgentId(Number(userId), agentId);
      const existing = config(getProviderConfig(Number(userId), KEY, scoped));
      const parsed = config(input, existing);
      const baseUrl = normalizeBaseUrl(parsed.baseUrl);
      await fetchJson(
        `${baseUrl}/api/v1/health`,
        { method: "GET", signal },
        { serviceName: "NeoArchive health check" },
      );
      await bootstrap(baseUrl, { signal });
      setProviderConfig(Number(userId), KEY, { baseUrl }, scoped);
      if (existing.baseUrl && existing.baseUrl !== baseUrl)
        db.prepare(
          "DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?",
        ).run(userId, scoped, KEY);
      return this.getUserConfig({ userId, agentId: scoped });
    },
    clearUserConfig({ userId, agentId }) {
      const scoped = resolveAgentId(Number(userId), agentId);
      deleteProviderConfig(Number(userId), KEY, scoped);
      db.prepare(
        "DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?",
      ).run(userId, scoped, KEY);
      return { cleared: true };
    },
  };
}

module.exports = { createNeoArchiveProvider };
