'use strict';

const { describeEnvStatus, resolveMicrosoftOAuthConfig } = require('../env');
const {
  appendQuery,
  createOAuthProvider,
  escapeScope,
  fetchJson,
} = require('../oauth_provider');

const MICROSOFT_BASE_SCOPES = ['openid', 'profile', 'email', 'offline_access', 'User.Read'];

const MICROSOFT_APPS = [
  {
    id: 'outlook',
    label: 'Outlook',
    description: 'Connect Outlook mail access for future Microsoft 365 native tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Mail.ReadWrite', 'Mail.Send'],
  },
  {
    id: 'calendar',
    label: 'Calendar',
    description: 'Connect Outlook Calendar access for future Microsoft 365 scheduling tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Calendars.ReadWrite'],
  },
  {
    id: 'onedrive',
    label: 'OneDrive',
    description: 'Connect OneDrive file access for future Microsoft 365 document tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Files.ReadWrite.All'],
  },
  {
    id: 'teams',
    label: 'Teams',
    description: 'Connect Microsoft Teams chat access for future collaboration tools.',
    scopes: [...MICROSOFT_BASE_SCOPES, 'Chat.ReadWrite', 'ChannelMessage.Read.All'],
  },
];

const graphApiTool = (appId, label) => ({
  appId,
  name: `microsoft_365_${appId}_graph_request`,
  access: 'dynamic_http_method',
  description: `Make an authenticated Microsoft Graph API request for advanced ${label} operations.`,
  parameters: {
    type: 'object',
    properties: {
      method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
      path: { type: 'string', description: 'Graph path or URL, e.g. /v1.0/me/messages.' },
      query: { type: 'object', description: 'Optional query parameters.' },
      body: { type: 'object', description: 'Optional JSON request body.' },
    },
    required: ['method', 'path'],
  },
});

const microsoftToolDefinitions = [
  {
    appId: 'outlook',
    name: 'microsoft_365_outlook_list_messages',
    access: 'read',
    description: 'List Outlook messages from the connected mailbox.',
    parameters: {
      type: 'object',
      properties: {
        folder_id: { type: 'string', description: 'Optional mail folder ID, default inbox.' },
        query: { type: 'string', description: 'Optional OData $search query.' },
        top: { type: 'number', description: 'Maximum messages, default 10.' },
      },
    },
  },
  {
    appId: 'outlook',
    name: 'microsoft_365_outlook_send_mail',
    access: 'write',
    description: 'Send an Outlook email from the connected mailbox.',
    parameters: {
      type: 'object',
      properties: {
        to: { type: 'array', items: { type: 'string' }, description: 'Recipient email addresses.' },
        subject: { type: 'string', description: 'Subject line.' },
        body_text: { type: 'string', description: 'Plain-text body.' },
        cc: { type: 'array', items: { type: 'string' }, description: 'Optional CC recipients.' },
        save_to_sent_items: { type: 'boolean', description: 'Whether to save to Sent Items, default true.' },
      },
      required: ['to', 'subject', 'body_text'],
    },
  },
  {
    appId: 'calendar',
    name: 'microsoft_365_calendar_list_events',
    access: 'read',
    description: 'List Microsoft 365 calendar events.',
    parameters: {
      type: 'object',
      properties: {
        start: { type: 'string', description: 'Optional ISO start datetime.' },
        end: { type: 'string', description: 'Optional ISO end datetime.' },
        top: { type: 'number', description: 'Maximum events, default 10.' },
      },
    },
  },
  {
    appId: 'calendar',
    name: 'microsoft_365_calendar_create_event',
    access: 'write',
    description: 'Create a Microsoft 365 calendar event.',
    parameters: {
      type: 'object',
      properties: {
        subject: { type: 'string', description: 'Event subject.' },
        start: { type: 'string', description: 'Start ISO datetime.' },
        end: { type: 'string', description: 'End ISO datetime.' },
        timezone: { type: 'string', description: 'IANA/Windows timezone label, default UTC.' },
        body_text: { type: 'string', description: 'Optional plain-text body.' },
        attendees: { type: 'array', items: { type: 'string' }, description: 'Attendee email addresses.' },
      },
      required: ['subject', 'start', 'end'],
    },
  },
  {
    appId: 'onedrive',
    name: 'microsoft_365_onedrive_list_children',
    access: 'read',
    description: 'List OneDrive children under root or a drive item.',
    parameters: {
      type: 'object',
      properties: {
        item_id: { type: 'string', description: 'Optional drive item ID. Omit for root.' },
        top: { type: 'number', description: 'Maximum items, default 25.' },
      },
    },
  },
  {
    appId: 'teams',
    name: 'microsoft_365_teams_list_chats',
    access: 'read',
    description: 'List Microsoft Teams chats visible to the connected user.',
    parameters: {
      type: 'object',
      properties: {
        top: { type: 'number', description: 'Maximum chats, default 20.' },
      },
    },
  },
  {
    appId: 'teams',
    name: 'microsoft_365_teams_send_chat_message',
    access: 'write',
    description: 'Send a Microsoft Teams chat message.',
    parameters: {
      type: 'object',
      properties: {
        chat_id: { type: 'string', description: 'Microsoft Graph chat ID.' },
        content: { type: 'string', description: 'Message content.' },
        content_type: { type: 'string', description: 'html or text, default text.' },
      },
      required: ['chat_id', 'content'],
    },
  },
  graphApiTool('outlook', 'Outlook'),
  graphApiTool('calendar', 'Calendar'),
  graphApiTool('onedrive', 'OneDrive'),
  graphApiTool('teams', 'Teams'),
];

function getMicrosoftEndpoints() {
  const config = resolveMicrosoftOAuthConfig();
  const tenant = encodeURIComponent(config.tenantId);
  return {
    config,
    authorizeUrl: `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/authorize`,
    tokenUrl: `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token`,
  };
}

function requireText(value, label) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`${label} is required.`);
  return text;
}

function emailRecipients(values) {
  return (Array.isArray(values) ? values : String(values || '').split(','))
    .map((email) => String(email || '').trim())
    .filter(Boolean)
    .map((address) => ({ emailAddress: { address } }));
}

function graphUrl(path, query) {
  const url = new URL(
    String(path || '').startsWith('http')
      ? String(path)
      : `https://graph.microsoft.com${String(path || '').startsWith('/') ? '' : '/'}${path}`,
  );
  if (url.hostname !== 'graph.microsoft.com') {
    throw new Error('Microsoft Graph request URL must target graph.microsoft.com.');
  }
  for (const [key, value] of Object.entries(query || {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }
  return url.toString();
}

async function graphRequest(credentials, { method = 'GET', path, query, body }) {
  return fetchJson(
    graphUrl(path, query),
    {
      method: String(method || 'GET').toUpperCase(),
      headers: { Authorization: `Bearer ${credentials.access_token}` },
      ...(body === undefined ? {} : { json: body }),
    },
    { serviceName: 'Microsoft Graph' },
  );
}

async function executeMicrosoftTool(toolName, args, { credentials }) {
  switch (toolName) {
    case 'microsoft_365_outlook_list_messages': {
      const folder = String(args.folder_id || 'inbox').trim();
      const path = folder === 'inbox'
        ? '/v1.0/me/mailFolders/inbox/messages'
        : `/v1.0/me/mailFolders/${encodeURIComponent(folder)}/messages`;
      return {
        result: await graphRequest(credentials, {
          path,
          query: {
            '$top': Math.max(1, Math.min(Number(args.top) || 10, 50)),
            '$orderby': 'receivedDateTime desc',
            ...(args.query ? { '$search': `"${String(args.query).replace(/"/g, '\\"')}"` } : {}),
          },
        }),
      };
    }
    case 'microsoft_365_outlook_send_mail':
      await graphRequest(credentials, {
        method: 'POST',
        path: '/v1.0/me/sendMail',
        body: {
          message: {
            subject: requireText(args.subject, 'subject'),
            body: {
              contentType: 'Text',
              content: String(args.body_text || ''),
            },
            toRecipients: emailRecipients(args.to),
            ccRecipients: emailRecipients(args.cc),
          },
          saveToSentItems: args.save_to_sent_items !== false,
        },
      });
      return {
        result: { sent: true },
      };
    case 'microsoft_365_calendar_list_events': {
      const hasWindow = args.start && args.end;
      return {
        result: await graphRequest(credentials, {
          path: hasWindow ? '/v1.0/me/calendarView' : '/v1.0/me/events',
          query: {
            '$top': Math.max(1, Math.min(Number(args.top) || 10, 50)),
            ...(hasWindow
              ? { startDateTime: String(args.start), endDateTime: String(args.end) }
              : { '$orderby': 'start/dateTime' }),
          },
        }),
      };
    }
    case 'microsoft_365_calendar_create_event':
      return {
        result: await graphRequest(credentials, {
          method: 'POST',
          path: '/v1.0/me/events',
          body: {
            subject: requireText(args.subject, 'subject'),
            body: {
              contentType: 'Text',
              content: String(args.body_text || ''),
            },
            start: {
              dateTime: requireText(args.start, 'start'),
              timeZone: String(args.timezone || 'UTC'),
            },
            end: {
              dateTime: requireText(args.end, 'end'),
              timeZone: String(args.timezone || 'UTC'),
            },
            attendees: emailRecipients(args.attendees).map((recipient) => ({
              ...recipient,
              type: 'required',
            })),
          },
        }),
      };
    case 'microsoft_365_onedrive_list_children':
      return {
        result: await graphRequest(credentials, {
          path: args.item_id
            ? `/v1.0/me/drive/items/${encodeURIComponent(String(args.item_id))}/children`
            : '/v1.0/me/drive/root/children',
          query: { '$top': Math.max(1, Math.min(Number(args.top) || 25, 200)) },
        }),
      };
    case 'microsoft_365_teams_list_chats':
      return {
        result: await graphRequest(credentials, {
          path: '/v1.0/me/chats',
          query: { '$top': Math.max(1, Math.min(Number(args.top) || 20, 50)) },
        }),
      };
    case 'microsoft_365_teams_send_chat_message':
      return {
        result: await graphRequest(credentials, {
          method: 'POST',
          path: `/v1.0/chats/${encodeURIComponent(requireText(args.chat_id, 'chat_id'))}/messages`,
          body: {
            body: {
              contentType: String(args.content_type || 'text').toLowerCase() === 'html' ? 'html' : 'text',
              content: requireText(args.content, 'content'),
            },
          },
        }),
      };
    default:
      if (/^microsoft_365_.*_graph_request$/.test(toolName)) {
        if (process.env.NEOAGENT_ENABLE_MICROSOFT_DYNAMIC_GRAPH_REQUEST !== 'true') {
          throw new Error('microsoft_365_*_graph_request tools are disabled by default. Set NEOAGENT_ENABLE_MICROSOFT_DYNAMIC_GRAPH_REQUEST=true to enable them.');
        }
        return {
          result: await graphRequest(credentials, {
            method: args.method,
            path: requireText(args.path, 'path'),
            query: args.query,
            body: args.body,
          }),
        };
      }
      return null;
  }
}

function createMicrosoftProvider() {
  return createOAuthProvider({
    key: 'microsoft_365',
    label: 'Microsoft 365',
    description:
      'Official Microsoft 365 OAuth account connections for Outlook, Calendar, OneDrive, and Teams.',
    icon: 'microsoft',
    requiresRefreshToken: true,
    apps: MICROSOFT_APPS,
    toolDefinitions: microsoftToolDefinitions,
    connectPrompt:
      'This wires Microsoft 365 account connections into Official Integrations now. Native Outlook, Calendar, OneDrive, and Teams tools can be layered on later.',
    getEnvStatus() {
      return describeEnvStatus(resolveMicrosoftOAuthConfig(), {
        label: 'Microsoft 365',
      });
    },
    async beginOAuth({ state, app }) {
      const { config, authorizeUrl } = getMicrosoftEndpoints();
      return {
        url: appendQuery(authorizeUrl, {
          client_id: config.clientId,
          redirect_uri: config.redirectUri,
          response_type: 'code',
          response_mode: 'query',
          scope: escapeScope(app.scopes),
          state,
          prompt: 'select_account',
        }),
        appId: app.id,
      };
    },
    async finishOAuth({ code, app }) {
      const { config, tokenUrl } = getMicrosoftEndpoints();
      const token = await fetchJson(
        tokenUrl,
        {
          method: 'POST',
          form: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            grant_type: 'authorization_code',
            code,
            redirect_uri: config.redirectUri,
            scope: escapeScope(app.scopes),
          },
        },
        { serviceName: 'Microsoft 365' },
      );

      const profile = await fetchJson(
        'https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName',
        {
          headers: {
            Authorization: `Bearer ${token.access_token}`,
          },
        },
        { serviceName: 'Microsoft 365' },
      );

      const accountEmail = String(
        profile?.mail || profile?.userPrincipalName || profile?.displayName || profile?.id || '',
      ).trim();
      if (!accountEmail) {
        throw new Error('Microsoft 365 OAuth did not return a stable account identifier.');
      }

      return {
        appId: app.id,
        accountEmail,
        credentials: {
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_in: token.expires_in,
          scope: token.scope,
          token_type: token.token_type,
        },
        scopes: app.scopes,
        metadata: {
          id: profile?.id || null,
          displayName: profile?.displayName || null,
          mail: profile?.mail || null,
          userPrincipalName: profile?.userPrincipalName || null,
        },
      };
    },
    executeTool: executeMicrosoftTool,
  });
}

module.exports = {
  createMicrosoftProvider,
};
