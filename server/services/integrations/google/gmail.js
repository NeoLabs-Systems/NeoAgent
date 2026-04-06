'use strict';

const { google } = require('googleapis');
const {
  coerceStringList,
  extractMessageBody,
  getHeader,
  stringToBase64Url,
} = require('./common');

function sanitizeHeaderValue(value, label) {
  const normalized = String(value || '').trim();
  if (/[\r\n]/.test(normalized)) {
    throw new Error(`${label} must not contain newline characters.`);
  }
  return normalized;
}

const gmailToolDefinitions = [
  {
    name: 'google_workspace_gmail_search_threads',
    description: 'Search Gmail threads for the connected Google Workspace account.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Gmail search query, e.g. "is:unread newer_than:7d".',
        },
        max_results: {
          type: 'number',
          description: 'Maximum number of threads to return (default 10).',
        },
      },
      required: ['query'],
    },
  },
  {
    name: 'google_workspace_gmail_get_thread',
    description: 'Read a Gmail thread with headers and decoded plain-text bodies.',
    parameters: {
      type: 'object',
      properties: {
        thread_id: { type: 'string', description: 'Gmail thread ID.' },
      },
      required: ['thread_id'],
    },
  },
  {
    name: 'google_workspace_gmail_get_message',
    description: 'Read a single Gmail message with headers and decoded body.',
    parameters: {
      type: 'object',
      properties: {
        message_id: { type: 'string', description: 'Gmail message ID.' },
      },
      required: ['message_id'],
    },
  },
  {
    name: 'google_workspace_gmail_list_labels',
    description: 'List Gmail labels available to the connected account.',
    parameters: { type: 'object', properties: {} },
  },
  {
    name: 'google_workspace_gmail_send_email',
    description: 'Send an email from the connected Gmail account.',
    parameters: {
      type: 'object',
      properties: {
        to: {
          type: 'string',
          description: 'Comma-separated recipient email addresses.',
        },
        subject: { type: 'string', description: 'Email subject line.' },
        body_text: { type: 'string', description: 'Plain-text email body.' },
        cc: { type: 'string', description: 'Optional comma-separated CC addresses.' },
        bcc: {
          type: 'string',
          description: 'Optional comma-separated BCC addresses.',
        },
        thread_id: {
          type: 'string',
          description: 'Optional Gmail thread ID to reply in-thread.',
        },
      },
      required: ['to', 'subject', 'body_text'],
    },
  },
  {
    name: 'google_workspace_gmail_modify_thread_labels',
    description:
      'Add or remove Gmail labels from a thread, optionally archiving it by removing INBOX.',
    parameters: {
      type: 'object',
      properties: {
        thread_id: { type: 'string', description: 'Gmail thread ID.' },
        add_label_names: {
          type: 'array',
          items: { type: 'string' },
          description: 'Label names to add, e.g. ["STARRED"] or custom labels.',
        },
        remove_label_names: {
          type: 'array',
          items: { type: 'string' },
          description: 'Label names to remove.',
        },
        archive: {
          type: 'boolean',
          description: 'When true, remove the INBOX label.',
        },
      },
      required: ['thread_id'],
    },
  },
];

function summarizeMessage(message) {
  const headers = Array.isArray(message.payload?.headers)
    ? message.payload.headers
    : [];
  return {
    id: message.id,
    threadId: message.threadId,
    labelIds: Array.isArray(message.labelIds) ? message.labelIds : [],
    snippet: message.snippet || '',
    internalDate: message.internalDate
      ? new Date(Number(message.internalDate)).toISOString()
      : null,
    subject: getHeader(headers, 'Subject'),
    from: getHeader(headers, 'From'),
    to: getHeader(headers, 'To'),
    date: getHeader(headers, 'Date'),
    bodyText: extractMessageBody(message.payload),
  };
}

async function listLabels(auth) {
  const gmail = google.gmail({ version: 'v1', auth });
  const response = await gmail.users.labels.list({ userId: 'me' });
  const labels = Array.isArray(response.data.labels) ? response.data.labels : [];
  return labels.map((label) => ({
    id: label.id || '',
    name: label.name || '',
    type: label.type || 'user',
    messagesTotal: label.messagesTotal ?? null,
    threadsTotal: label.threadsTotal ?? null,
  }));
}

async function resolveLabelIds(auth, names) {
  const wanted = new Map(
    coerceStringList(names).map((name) => [name.toLowerCase(), name]),
  );
  if (wanted.size === 0) return [];
  const labels = await listLabels(auth);
  return labels
    .filter((label) => wanted.has(String(label.name || '').toLowerCase()))
    .map((label) => label.id);
}

async function executeGmailTool(toolName, args, auth) {
  const gmail = google.gmail({ version: 'v1', auth });

  switch (toolName) {
    case 'google_workspace_gmail_search_threads': {
      const maxResults = Math.max(
        1,
        Math.min(Number(args.max_results) || 10, 25),
      );
      const listResponse = await gmail.users.threads.list({
        userId: 'me',
        q: String(args.query || ''),
        maxResults,
      });
      const threadRefs = Array.isArray(listResponse.data.threads)
        ? listResponse.data.threads
        : [];
      const threads = await Promise.all(
        threadRefs.map(async (threadRef) => {
          const threadResponse = await gmail.users.threads.get({
            userId: 'me',
            id: threadRef.id,
            format: 'metadata',
            metadataHeaders: ['Subject', 'From', 'Date'],
          });
          const thread = threadResponse.data;
          const lastMessage =
            Array.isArray(thread.messages) && thread.messages.length > 0
              ? thread.messages[thread.messages.length - 1]
              : null;
          return {
            id: thread.id || '',
            snippet: thread.snippet || '',
            historyId: thread.historyId || null,
            messageCount: Array.isArray(thread.messages)
              ? thread.messages.length
              : 0,
            subject: getHeader(lastMessage?.payload?.headers, 'Subject'),
            from: getHeader(lastMessage?.payload?.headers, 'From'),
            date: getHeader(lastMessage?.payload?.headers, 'Date'),
          };
        }),
      );
      return { query: String(args.query || ''), count: threads.length, threads };
    }

    case 'google_workspace_gmail_get_thread': {
      const response = await gmail.users.threads.get({
        userId: 'me',
        id: String(args.thread_id || ''),
        format: 'full',
      });
      const thread = response.data;
      return {
        id: thread.id || '',
        historyId: thread.historyId || null,
        snippet: thread.snippet || '',
        messages: (Array.isArray(thread.messages) ? thread.messages : []).map(
          summarizeMessage,
        ),
      };
    }

    case 'google_workspace_gmail_get_message': {
      const response = await gmail.users.messages.get({
        userId: 'me',
        id: String(args.message_id || ''),
        format: 'full',
      });
      return summarizeMessage(response.data);
    }

    case 'google_workspace_gmail_list_labels': {
      const labels = await listLabels(auth);
      return { count: labels.length, labels };
    }

    case 'google_workspace_gmail_send_email': {
      const to = sanitizeHeaderValue(args.to, 'to');
      const cc = sanitizeHeaderValue(args.cc, 'cc');
      const bcc = sanitizeHeaderValue(args.bcc, 'bcc');
      const subject = sanitizeHeaderValue(args.subject, 'subject');
      const lines = [`To: ${to}`];
      if (cc) lines.push(`Cc: ${cc}`);
      if (bcc) {
        lines.push(`Bcc: ${bcc}`);
      }
      lines.push(`Subject: ${subject}`);
      lines.push('Content-Type: text/plain; charset=utf-8');
      lines.push('MIME-Version: 1.0');
      lines.push('');
      lines.push(String(args.body_text || ''));
      const raw = stringToBase64Url(lines.join('\r\n'));
      const response = await gmail.users.messages.send({
        userId: 'me',
        requestBody: {
          raw,
          ...(args.thread_id ? { threadId: String(args.thread_id) } : {}),
        },
      });
      return {
        id: response.data.id || null,
        threadId: response.data.threadId || null,
        labelIds: Array.isArray(response.data.labelIds)
          ? response.data.labelIds
          : [],
      };
    }

    case 'google_workspace_gmail_modify_thread_labels': {
      const addLabelIds = await resolveLabelIds(auth, args.add_label_names);
      const removeNames = coerceStringList(args.remove_label_names);
      if (
        args.archive === true &&
        !removeNames.some((name) => name.toUpperCase() === 'INBOX')
      ) {
        removeNames.push('INBOX');
      }
      const removeLabelIds = await resolveLabelIds(auth, removeNames);
      const response = await gmail.users.threads.modify({
        userId: 'me',
        id: String(args.thread_id || ''),
        requestBody: {
          addLabelIds,
          removeLabelIds,
        },
      });
      return {
        id: response.data.id || String(args.thread_id || ''),
        historyId: response.data.historyId || null,
        added: addLabelIds,
        removed: removeLabelIds,
      };
    }

    default:
      return null;
  }
}

module.exports = {
  executeGmailTool,
  gmailToolDefinitions,
};
