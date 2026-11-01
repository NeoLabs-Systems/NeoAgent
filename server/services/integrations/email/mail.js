'use strict';

const { ImapFlow } = require('imapflow');
const { simpleParser } = require('mailparser');
const nodemailer = require('nodemailer');
const MailComposer = require('nodemailer/lib/mail-composer');
const { requireText, trimText: text } = require('../../../utils/text');

const MAIL_APP = Object.freeze({
  id: 'mail',
  label: 'Mail',
  description: 'Search, read, send and organize mail over IMAP and SMTP.',
});

const IMAP_PORTS = new Set([143, 993]);
const SMTP_PORTS = new Set([25, 465, 587, 2525]);
const HOST_PATTERN = /^[a-z0-9.-]{1,253}$/i;
const MAX_BODY_CHARS = 20000;
const SPECIAL_FOLDERS = Object.freeze({ trash: '\\Trash', archive: '\\Archive', junk: '\\Junk', sent: '\\Sent' });

const MAIL_TOOLS = Object.freeze([
  {
    name: 'email_list_folders',
    access: 'read',
    description: 'List the mailbox folders (Inbox, Sent, Archive, labels, ...).',
    parameters: { type: 'object', properties: {} },
  },
  {
    name: 'email_search',
    access: 'read',
    description: 'Search mail in one folder, newest first. Combine filters as needed.',
    parameters: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder path from email_list_folders. Default INBOX.' },
        query: { type: 'string', description: 'Text to find in headers or body.' },
        from: { type: 'string', description: 'Sender address or name.' },
        to: { type: 'string', description: 'Recipient address or name.' },
        subject: { type: 'string', description: 'Text in the subject.' },
        unread_only: { type: 'boolean', description: 'Only unread messages.' },
        since: { type: 'string', description: 'Only messages on or after this ISO date.' },
        before: { type: 'string', description: 'Only messages before this ISO date.' },
        limit: { type: 'number', description: 'Maximum messages (1-50), default 20.' },
      },
    },
  },
  {
    name: 'email_read',
    access: 'read',
    description: 'Read one message: headers, plain-text body and attachment names.',
    parameters: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder path. Default INBOX.' },
        uid: { type: 'number', description: 'Message uid from email_search.' },
      },
      required: ['uid'],
    },
  },
  {
    name: 'email_send',
    access: 'write',
    description: 'Send a plain-text email, or reply to a message when reply_to_uid is set.',
    parameters: {
      type: 'object',
      properties: {
        to: { type: 'string', description: 'Comma-separated recipients.' },
        cc: { type: 'string', description: 'Comma-separated Cc recipients.' },
        bcc: { type: 'string', description: 'Comma-separated Bcc recipients.' },
        subject: { type: 'string', description: 'Subject. Optional when replying.' },
        body: { type: 'string', description: 'Plain-text body.' },
        reply_to_uid: { type: 'number', description: 'Uid of the message being answered.' },
        reply_folder: { type: 'string', description: 'Folder of that message. Default INBOX.' },
      },
      required: ['to', 'body'],
    },
  },
  {
    name: 'email_update',
    access: 'write',
    description: 'Mark messages read or unread, flag them, or move them (for example to trash or archive).',
    parameters: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder holding the messages. Default INBOX.' },
        uids: { type: 'array', items: { type: 'number' }, description: 'Message uids.' },
        read: { type: 'boolean', description: 'Mark read (true) or unread (false).' },
        flagged: { type: 'boolean', description: 'Flag (true) or unflag (false).' },
        move_to: { type: 'string', description: 'Destination folder path, or trash, archive or junk.' },
      },
      required: ['uids'],
    },
  },
].map((tool) => Object.freeze({ ...tool, appId: MAIL_APP.id })));

/** Validates one IMAP or SMTP server entered for a custom provider. */
function parseServer(input, kind) {
  const host = text(input?.host).toLowerCase();
  const port = Number(input?.port);
  const ports = kind === 'imap' ? IMAP_PORTS : SMTP_PORTS;
  if (!HOST_PATTERN.test(host)) throw new Error(`${kind.toUpperCase()} server must be a host name.`);
  if (!ports.has(port)) {
    throw new Error(`${kind.toUpperCase()} port must be one of ${[...ports].join(', ')}.`);
  }
  // Implicit TLS on the standard ports; STARTTLS (required) everywhere else.
  return { host, port, secure: port === 993 || port === 465 };
}

function formatAddresses(list) {
  return (list || [])
    .map((entry) => (entry.name ? `${entry.name} <${entry.address}>` : entry.address))
    .filter(Boolean)
    .join(', ');
}

async function withImap(account, signal, work) {
  const client = new ImapFlow({
    host: account.imap.host,
    port: account.imap.port,
    secure: account.imap.secure,
    auth: { user: account.username, pass: account.password },
    logger: false,
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 60000,
  });
  const abort = () => client.close();
  signal?.addEventListener('abort', abort, { once: true });
  try {
    await client.connect();
    return await work(client);
  } catch (error) {
    if (error?.authenticationFailed) {
      throw new Error('The mail server rejected the email address or app password.');
    }
    throw error;
  } finally {
    signal?.removeEventListener('abort', abort);
    await client.logout().catch(() => client.close());
  }
}

async function withFolder(client, folder, work) {
  const lock = await client.getMailboxLock(text(folder) || 'INBOX');
  try {
    return await work();
  } finally {
    lock.release();
  }
}

async function specialFolder(client, name) {
  const folders = await client.list();
  const match = folders.find((folder) => folder.specialUse === SPECIAL_FOLDERS[name]);
  if (!match) throw new Error(`This mailbox has no ${name} folder.`);
  return match.path;
}

function searchCriteria(args) {
  const criteria = {};
  for (const key of ['from', 'to', 'subject']) {
    if (text(args[key])) criteria[key] = text(args[key]);
  }
  if (text(args.query)) criteria.text = text(args.query);
  if (args.unread_only === true) criteria.seen = false;
  for (const key of ['since', 'before']) {
    if (!text(args[key])) continue;
    const date = new Date(text(args[key]));
    if (Number.isNaN(date.getTime())) throw new Error(`${key} must be an ISO date.`);
    criteria[key] = date;
  }
  return Object.keys(criteria).length ? criteria : { all: true };
}

function summarize(message) {
  return {
    uid: message.uid,
    from: formatAddresses(message.envelope?.from),
    to: formatAddresses(message.envelope?.to),
    subject: message.envelope?.subject || '',
    date: message.internalDate?.toISOString?.() || null,
    unread: !message.flags?.has('\\Seen'),
    flagged: Boolean(message.flags?.has('\\Flagged')),
  };
}

async function readMessage(client, uid) {
  const message = await client.fetchOne(String(uid), { source: true }, { uid: true });
  if (!message?.source) throw new Error(`Message ${uid} was not found.`);
  return simpleParser(message.source);
}

function buildRaw(mail) {
  return new Promise((resolve, reject) => {
    new MailComposer(mail).compile().build((error, raw) => (error ? reject(error) : resolve(raw)));
  });
}

async function sendMail(account, args, signal) {
  const mail = {
    from: account.email,
    to: requireText(args.to, 'to'),
    cc: text(args.cc) || undefined,
    bcc: text(args.bcc) || undefined,
    subject: text(args.subject),
    text: requireText(args.body, 'body'),
  };
  return withImap(account, signal, async (client) => {
    if (args.reply_to_uid) {
      const original = await withFolder(client, args.reply_folder, () => readMessage(client, args.reply_to_uid));
      mail.inReplyTo = original.messageId;
      mail.references = [].concat(original.references || [], original.messageId || []);
      mail.subject = mail.subject || (/^re:/i.test(original.subject || '') ? original.subject : `Re: ${original.subject || ''}`);
    }
    const raw = await buildRaw(mail);
    const transport = nodemailer.createTransport({
      host: account.smtp.host,
      port: account.smtp.port,
      secure: account.smtp.secure,
      requireTLS: !account.smtp.secure,
      auth: { user: account.username, pass: account.password },
    });
    const recipients = [mail.to, mail.cc, mail.bcc].filter(Boolean).join(',');
    const info = await transport.sendMail({ envelope: { from: account.email, to: recipients }, raw });
    // Most servers keep no copy of mail sent over SMTP; Gmail does it itself.
    if (!account.savesSentMail) {
      await client.append(await specialFolder(client, 'sent'), raw, ['\\Seen']).catch(() => {});
    }
    return { sent: true, messageId: info.messageId, to: mail.to, subject: mail.subject };
  });
}

async function executeMailTool(toolName, args, account, options = {}) {
  const signal = options.signal || null;
  switch (toolName) {
    case 'email_list_folders':
      return {
        result: await withImap(account, signal, async (client) => (await client.list()).map((folder) => ({
          path: folder.path,
          name: folder.name,
          specialUse: folder.specialUse || null,
        }))),
      };
    case 'email_search': {
      const limit = Math.max(1, Math.min(Number(args.limit) || 20, 50));
      return {
        result: await withImap(account, signal, (client) => withFolder(client, args.folder, async () => {
          const uids = (await client.search(searchCriteria(args), { uid: true })) || [];
          const newest = uids.slice(-limit);
          if (!newest.length) return [];
          const messages = [];
          for await (const message of client.fetch(newest.join(','), { envelope: true, flags: true, internalDate: true }, { uid: true })) {
            messages.push(summarize(message));
          }
          return messages.reverse();
        })),
      };
    }
    case 'email_read':
      return {
        result: await withImap(account, signal, (client) => withFolder(client, args.folder, async () => {
          const parsed = await readMessage(client, args.uid);
          const body = parsed.text || '';
          return {
            uid: Number(args.uid),
            from: parsed.from?.text || '',
            to: parsed.to?.text || '',
            cc: parsed.cc?.text || '',
            subject: parsed.subject || '',
            date: parsed.date?.toISOString?.() || null,
            body: body.slice(0, MAX_BODY_CHARS),
            truncated: body.length > MAX_BODY_CHARS,
            attachments: (parsed.attachments || []).map((attachment) => ({
              filename: attachment.filename || null,
              contentType: attachment.contentType,
              size: attachment.size,
            })),
          };
        })),
      };
    case 'email_send':
      return { result: await sendMail(account, args, signal) };
    case 'email_update': {
      const uids = (Array.isArray(args.uids) ? args.uids : []).map(Number).filter((uid) => Number.isInteger(uid) && uid > 0);
      if (!uids.length) throw new Error('uids must list at least one message uid.');
      const range = uids.join(',');
      return {
        result: await withImap(account, signal, (client) => withFolder(client, args.folder, async () => {
          if (typeof args.read === 'boolean') {
            await client[args.read ? 'messageFlagsAdd' : 'messageFlagsRemove'](range, ['\\Seen'], { uid: true });
          }
          if (typeof args.flagged === 'boolean') {
            await client[args.flagged ? 'messageFlagsAdd' : 'messageFlagsRemove'](range, ['\\Flagged'], { uid: true });
          }
          const target = text(args.move_to);
          let movedTo = null;
          if (target) {
            movedTo = SPECIAL_FOLDERS[target.toLowerCase()] ? await specialFolder(client, target.toLowerCase()) : target;
            await client.messageMove(range, movedTo, { uid: true });
          }
          return { updated: uids.length, movedTo };
        })),
      };
    }
    default:
      return null;
  }
}

/** Signs in once, so a wrong password fails at setup rather than later. */
function verifyMailbox(account, signal) {
  return withImap(account, signal, (client) => client.noop());
}

module.exports = {
  MAIL_APP,
  MAIL_TOOLS,
  executeMailTool,
  parseServer,
  verifyMailbox,
};
