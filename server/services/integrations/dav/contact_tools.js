'use strict';

const { buildContactVcard, parseContact, parseDavResponses } = require('./format');
const { encodePathSegments, hrefToRemotePath, normalizeRemotePath } = require('./paths');
const { requireText, trimText: text } = require('../../../utils/text');

const CONTACT_FIELDS = Object.freeze({
  full_name: { type: 'string', description: 'Display name.' },
  email: { type: 'string', description: 'Email address.' },
  phone: { type: 'string', description: 'Phone number.' },
  organization: { type: 'string', description: 'Organization name.' },
});

function matchesQuery(contact, query) {
  const needle = text(query).toLowerCase();
  if (!needle) return true;
  return [contact.fullName, contact.email, contact.phone, contact.organization]
    .some((value) => text(value).toLowerCase().includes(needle));
}

function contactFromArgs(args, uid) {
  return {
    uid,
    fullName: requireText(args.full_name, 'full_name'),
    email: args.email,
    phone: args.phone,
    organization: args.organization,
  };
}

/**
 * CardDAV contact tools for any integration that reaches an address book
 * home. `execute` takes the same `{ home, request }` store as the calendar
 * tools, with `home` pointing at the address book home.
 */
function createContactTools({ prefix, label, appId }) {
  const tools = Object.freeze([
    {
      name: `${prefix}_list_addressbooks`,
      access: 'read',
      description: `List CardDAV address books for the connected ${label} account.`,
      parameters: { type: 'object', properties: {} },
    },
    {
      name: `${prefix}_list_contacts`,
      access: 'read',
      description: `List contacts in a ${label} address book.`,
      parameters: {
        type: 'object',
        properties: {
          addressbook: { type: 'string', description: `Address book path from ${prefix}_list_addressbooks.` },
          query: { type: 'string', description: 'Optional name or email filter.' },
        },
        required: ['addressbook'],
      },
    },
    {
      name: `${prefix}_get_contact`,
      access: 'read',
      description: `Get one ${label} contact by address book and contact path.`,
      parameters: {
        type: 'object',
        properties: {
          addressbook: { type: 'string', description: 'Address book path.' },
          contact_path: { type: 'string', description: 'Contact href path, for example contacts/person.vcf.' },
        },
        required: ['addressbook', 'contact_path'],
      },
    },
    {
      name: `${prefix}_create_contact`,
      access: 'write',
      description: `Create a ${label} contact in an address book.`,
      parameters: {
        type: 'object',
        properties: {
          addressbook: { type: 'string', description: 'Address book path.' },
          ...CONTACT_FIELDS,
        },
        required: ['addressbook', 'full_name'],
      },
    },
    {
      name: `${prefix}_update_contact`,
      access: 'write',
      description: `Replace a ${label} contact. Include the full replacement fields.`,
      parameters: {
        type: 'object',
        properties: {
          addressbook: { type: 'string', description: 'Address book path.' },
          contact_path: { type: 'string', description: 'Existing contact path.' },
          ...CONTACT_FIELDS,
          uid: { type: 'string', description: 'Optional UID to preserve.' },
        },
        required: ['addressbook', 'contact_path', 'full_name'],
      },
    },
    {
      name: `${prefix}_delete_contact`,
      access: 'write',
      description: `Delete a ${label} contact.`,
      parameters: {
        type: 'object',
        properties: {
          addressbook: { type: 'string', description: 'Address book path.' },
          contact_path: { type: 'string', description: `Contact path from ${prefix}_list_contacts.` },
        },
        required: ['addressbook', 'contact_path'],
      },
    },
  ].map((tool) => Object.freeze({ ...tool, appId })));
  const names = new Set(tools.map((tool) => tool.name));

  async function execute(toolName, args, store, options = {}) {
    if (!names.has(toolName)) return null;
    const signal = options.signal || null;
    const { home } = store;
    const pathIn = (relative) => `${home}${encodePathSegments(relative)}`;
    const contactHref = (addressbook, contactPath) => {
      const relative = normalizeRemotePath(contactPath);
      return pathIn(relative.includes('/') ? relative : `${normalizeRemotePath(addressbook)}/${relative}`);
    };
    const putContact = (href, vcard) => store.request(href, {
      method: 'PUT',
      headers: { 'Content-Type': 'text/vcard; charset=utf-8' },
      body: vcard,
      signal,
    });

    switch (toolName.slice(prefix.length + 1)) {
      case 'list_addressbooks': {
        const { text: xml } = await store.request(home, {
          method: 'PROPFIND',
          headers: { Depth: '1', 'Content-Type': 'application/xml; charset=utf-8' },
          body: `<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop><d:displayname/><d:resourcetype/></d:prop>
</d:propfind>`,
          signal,
        });
        const books = parseDavResponses(xml)
          .filter((entry) => entry.ok && entry.isAddressbook)
          .map((entry) => ({
            path: hrefToRemotePath(entry.href, home),
            name: text(entry.displayName) || hrefToRemotePath(entry.href, home),
          }))
          .filter((entry) => entry.path);
        return { result: books };
      }
      case 'list_contacts': {
        const { text: xml } = await store.request(pathIn(args.addressbook), {
          method: 'REPORT',
          headers: { Depth: '1', 'Content-Type': 'application/xml; charset=utf-8' },
          body: `<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop><d:getetag/><c:address-data/></d:prop>
</c:addressbook-query>`,
          signal,
        });
        const contacts = parseDavResponses(xml)
          .filter((entry) => entry.ok && entry.addressData)
          .map((entry) => ({
            path: hrefToRemotePath(entry.href, home),
            etag: text(entry.etag) || null,
            ...parseContact(entry.addressData),
          }))
          .filter((contact) => matchesQuery(contact, args.query));
        return { result: contacts };
      }
      case 'get_contact': {
        const href = contactHref(args.addressbook, args.contact_path);
        const { text: vcard } = await store.request(href, {
          method: 'GET',
          accept: 'text/vcard, */*',
          signal,
        });
        return { result: { path: hrefToRemotePath(href, home), ...parseContact(vcard) } };
      }
      case 'create_contact': {
        const vcard = buildContactVcard(contactFromArgs(args));
        const uid = parseContact(vcard).uid;
        const contactPath = `${normalizeRemotePath(args.addressbook)}/${uid}.vcf`;
        await putContact(pathIn(contactPath), vcard);
        return { result: { path: contactPath, uid, fullName: text(args.full_name) } };
      }
      case 'update_contact': {
        const href = contactHref(args.addressbook, args.contact_path);
        const currentPath = hrefToRemotePath(href, home);
        const uid = text(args.uid) || pathUid(currentPath);
        await putContact(href, buildContactVcard(contactFromArgs(args, uid)));
        return { result: { path: currentPath, uid, fullName: text(args.full_name) } };
      }
      case 'delete_contact': {
        const href = contactHref(args.addressbook, args.contact_path);
        await store.request(href, { method: 'DELETE', signal });
        return { result: { deleted: true, path: hrefToRemotePath(href, home) } };
      }
      default:
        return null;
    }
  }

  return { tools, execute };
}

function pathUid(contactPath) {
  const name = normalizeRemotePath(contactPath).split('/').filter(Boolean).pop() || '';
  return name.replace(/\.vcf$/i, '');
}

module.exports = { createContactTools };
