'use strict';

const { CONTACTS_APP } = require('./constants');
const { davRequest, parseCredentials } = require('./client');
const { buildContactVcard, parseContact, parseDavResponses } = require('./dav');
const {
  davAddressbooksPath,
  hrefToRemotePath,
  normalizeRemotePath,
  requireText,
  text,
} = require('./network');

const CONTACT_TOOLS = Object.freeze([
  {
    name: 'nextcloud_list_addressbooks',
    access: 'read',
    description: 'List CardDAV address books for the connected Nextcloud account.',
    parameters: { type: 'object', properties: {} },
  },
  {
    name: 'nextcloud_list_contacts',
    access: 'read',
    description: 'List contacts in a Nextcloud address book.',
    parameters: {
      type: 'object',
      properties: {
        addressbook: { type: 'string', description: 'Address book path from nextcloud_list_addressbooks.' },
        query: { type: 'string', description: 'Optional name or email filter.' },
      },
      required: ['addressbook'],
    },
  },
  {
    name: 'nextcloud_get_contact',
    access: 'read',
    description: 'Get one Nextcloud contact by address book and contact path.',
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
    name: 'nextcloud_create_contact',
    access: 'write',
    description: 'Create a Nextcloud contact in an address book.',
    parameters: {
      type: 'object',
      properties: {
        addressbook: { type: 'string', description: 'Address book path.' },
        full_name: { type: 'string', description: 'Display name.' },
        email: { type: 'string', description: 'Email address.' },
        phone: { type: 'string', description: 'Phone number.' },
        organization: { type: 'string', description: 'Organization name.' },
      },
      required: ['addressbook', 'full_name'],
    },
  },
  {
    name: 'nextcloud_update_contact',
    access: 'write',
    description: 'Replace a Nextcloud contact. Include the full replacement fields.',
    parameters: {
      type: 'object',
      properties: {
        addressbook: { type: 'string', description: 'Address book path.' },
        contact_path: { type: 'string', description: 'Existing contact path.' },
        full_name: { type: 'string', description: 'Display name.' },
        email: { type: 'string', description: 'Email address.' },
        phone: { type: 'string', description: 'Phone number.' },
        organization: { type: 'string', description: 'Organization name.' },
        uid: { type: 'string', description: 'Optional UID to preserve.' },
      },
      required: ['addressbook', 'contact_path', 'full_name'],
    },
  },
  {
    name: 'nextcloud_delete_contact',
    access: 'write',
    description: 'Delete a Nextcloud contact.',
    parameters: {
      type: 'object',
      properties: {
        addressbook: { type: 'string', description: 'Address book path.' },
        contact_path: { type: 'string', description: 'Contact path from nextcloud_list_contacts.' },
      },
      required: ['addressbook', 'contact_path'],
    },
  },
].map((tool) => Object.freeze({ ...tool, appId: CONTACTS_APP.id })));

function bookPrefix(username) {
  return `/remote.php/dav/addressbooks/${username}/`;
}

function contactHref(username, addressbook, contactPath) {
  const relative = normalizeRemotePath(contactPath);
  if (relative.includes('/')) return davAddressbooksPath(username, relative);
  return davAddressbooksPath(username, `${normalizeRemotePath(addressbook)}/${relative}`);
}

function matchesQuery(contact, query) {
  const needle = text(query).toLowerCase();
  if (!needle) return true;
  return [contact.fullName, contact.email, contact.phone, contact.organization]
    .some((value) => text(value).toLowerCase().includes(needle));
}

async function executeContactsTool(toolName, args, credentials, options = {}) {
  const auth = parseCredentials(credentials);
  const signal = options.signal || null;
  const prefix = bookPrefix(auth.username);

  switch (toolName) {
    case 'nextcloud_list_addressbooks': {
      const { text: xml } = await davRequest(auth, `${davAddressbooksPath(auth.username, '')}/`, {
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
          path: hrefToRemotePath(entry.href, prefix),
          name: text(entry.displayName) || hrefToRemotePath(entry.href, prefix),
        }))
        .filter((entry) => entry.path);
      return { result: books };
    }
    case 'nextcloud_list_contacts': {
      const { text: xml } = await davRequest(auth, davAddressbooksPath(auth.username, args.addressbook), {
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
          path: hrefToRemotePath(entry.href, prefix),
          etag: text(entry.etag) || null,
          ...parseContact(entry.addressData),
        }))
        .filter((contact) => matchesQuery(contact, args.query));
      return { result: contacts };
    }
    case 'nextcloud_get_contact': {
      const { text: vcard } = await davRequest(auth, contactHref(auth.username, args.addressbook, args.contact_path), {
        method: 'GET',
        accept: 'text/vcard, */*',
        signal,
      });
      return {
        result: {
          path: hrefToRemotePath(contactHref(auth.username, args.addressbook, args.contact_path), prefix),
          ...parseContact(vcard),
        },
      };
    }
    case 'nextcloud_create_contact': {
      const vcard = buildContactVcard({
        fullName: requireText(args.full_name, 'full_name'),
        email: args.email,
        phone: args.phone,
        organization: args.organization,
      });
      const uid = parseContact(vcard).uid;
      const contactPath = `${normalizeRemotePath(args.addressbook)}/${uid}.vcf`;
      await davRequest(auth, davAddressbooksPath(auth.username, contactPath), {
        method: 'PUT',
        headers: { 'Content-Type': 'text/vcard; charset=utf-8' },
        body: vcard,
        signal,
      });
      return { result: { path: contactPath, uid, fullName: text(args.full_name) } };
    }
    case 'nextcloud_update_contact': {
      const currentPath = hrefToRemotePath(
        contactHref(auth.username, args.addressbook, args.contact_path),
        prefix,
      );
      const uid = text(args.uid) || pathUid(currentPath);
      const vcard = buildContactVcard({
        uid,
        fullName: requireText(args.full_name, 'full_name'),
        email: args.email,
        phone: args.phone,
        organization: args.organization,
      });
      await davRequest(auth, contactHref(auth.username, args.addressbook, args.contact_path), {
        method: 'PUT',
        headers: { 'Content-Type': 'text/vcard; charset=utf-8' },
        body: vcard,
        signal,
      });
      return { result: { path: currentPath, uid, fullName: text(args.full_name) } };
    }
    case 'nextcloud_delete_contact':
      await davRequest(auth, contactHref(auth.username, args.addressbook, args.contact_path), {
        method: 'DELETE',
        signal,
      });
      return {
        result: {
          deleted: true,
          path: hrefToRemotePath(contactHref(auth.username, args.addressbook, args.contact_path), prefix),
        },
      };
    default:
      return null;
  }
}

function pathUid(contactPath) {
  const name = normalizeRemotePath(contactPath).split('/').filter(Boolean).pop() || '';
  return name.replace(/\.vcf$/i, '');
}

module.exports = {
  CONTACT_TOOLS,
  executeContactsTool,
};
