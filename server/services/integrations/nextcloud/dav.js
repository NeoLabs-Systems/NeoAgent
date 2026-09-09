'use strict';

const crypto = require('node:crypto');
const { text } = require('./network');

function decodeXml(value) {
  return String(value || '')
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .trim();
}

function xmlBlocks(xml, localName) {
  const pattern = new RegExp(
    `<(?:[\\w-]+:)?${localName}(?:\\s[^>]*)?>([\\s\\S]*?)</(?:[\\w-]+:)?${localName}>`,
    'gi',
  );
  const blocks = [];
  let match = pattern.exec(String(xml || ''));
  while (match) {
    blocks.push(match[1]);
    match = pattern.exec(String(xml || ''));
  }
  return blocks;
}

function xmlText(xml, localName) {
  const blocks = xmlBlocks(xml, localName);
  return decodeXml(blocks[0] || '');
}

function xmlHas(xml, localName) {
  return new RegExp(`<(?:[\\w-]+:)?${localName}(?:\\s[^>]*)?/?>`, 'i').test(String(xml || ''));
}

function parseDavResponses(xml) {
  return xmlBlocks(xml, 'response').map((block) => {
    const href = decodeXml(xmlText(block, 'href'));
    const status = xmlText(block, 'status');
    const ok = !status || /\b200\b/.test(status);
    return {
      href,
      status,
      ok,
      displayName: xmlText(block, 'displayname'),
      contentType: xmlText(block, 'getcontenttype'),
      contentLength: xmlText(block, 'getcontentlength'),
      lastModified: xmlText(block, 'getlastmodified'),
      etag: xmlText(block, 'getetag'),
      fileId: xmlText(block, 'fileid'),
      calendarData: xmlText(block, 'calendar-data'),
      addressData: xmlText(block, 'address-data'),
      isCollection: xmlHas(block, 'collection'),
      isCalendar: xmlHas(block, 'calendar'),
      isAddressbook: xmlHas(block, 'addressbook'),
      trashDeletedAt: xmlText(block, 'trashbin-deletion-time'),
      trashOriginalPath: xmlText(block, 'trashbin-original-filename')
        || xmlText(block, 'trashbin-original-location'),
    };
  }).filter((entry) => entry.href);
}

function unfoldIcs(value) {
  return String(value || '').replace(/\r\n/g, '\n').replace(/\n[ \t]/g, '');
}

function icsBlocks(value, name) {
  const textValue = unfoldIcs(value);
  const pattern = new RegExp(`BEGIN:${name}\\n([\\s\\S]*?)\\nEND:${name}`, 'g');
  const blocks = [];
  let match = pattern.exec(textValue);
  while (match) {
    blocks.push(match[1]);
    match = pattern.exec(textValue);
  }
  return blocks;
}

function icsField(block, name) {
  const pattern = new RegExp(`^${name}(;[^:\\n]*)?:([^\\n]*)`, 'mi');
  const match = String(block || '').match(pattern);
  if (!match) return '';
  return String(match[2] || '')
    .replace(/\\n/g, '\n')
    .replace(/\\,/g, ',')
    .replace(/\\;/g, ';')
    .replace(/\\\\/g, '\\')
    .trim();
}

function parseIcsDate(value) {
  const raw = text(value);
  if (!raw) return null;
  if (/^\d{8}$/.test(raw)) {
    return `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`;
  }
  const match = raw.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/);
  if (!match) return raw;
  const iso = `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}`;
  return match[7] ? `${iso}Z` : iso;
}

function parseEvent(ics) {
  const block = icsBlocks(ics, 'VEVENT')[0] || unfoldIcs(ics);
  return {
    uid: icsField(block, 'UID'),
    summary: icsField(block, 'SUMMARY'),
    description: icsField(block, 'DESCRIPTION'),
    location: icsField(block, 'LOCATION'),
    start: parseIcsDate(icsField(block, 'DTSTART')),
    end: parseIcsDate(icsField(block, 'DTEND')),
  };
}

function parseContact(vcard) {
  const block = icsBlocks(vcard, 'VCARD')[0] || unfoldIcs(vcard);
  return {
    uid: icsField(block, 'UID'),
    fullName: icsField(block, 'FN'),
    email: icsField(block, 'EMAIL'),
    phone: icsField(block, 'TEL'),
    organization: icsField(block, 'ORG'),
  };
}

function escapeIcs(value) {
  return String(value || '')
    .replace(/\\/g, '\\\\')
    .replace(/\n/g, '\\n')
    .replace(/,/g, '\\,')
    .replace(/;/g, '\\;');
}

function formatIcsDate(value) {
  const raw = text(value);
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    return { param: ';VALUE=DATE', stamp: raw.replace(/-/g, '') };
  }
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    throw new Error('Datetime must be an ISO-8601 value.');
  }
  return {
    param: '',
    stamp: date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z'),
  };
}

function buildEventIcs(event) {
  const uid = text(event.uid) || `${crypto.randomUUID()}@neoagent`;
  const start = formatIcsDate(event.start);
  const end = formatIcsDate(event.end);
  const stamp = formatIcsDate(new Date().toISOString()).stamp;
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//NeoAgent//Nextcloud//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    `UID:${uid}`,
    `DTSTAMP:${stamp}`,
    `DTSTART${start.param}:${start.stamp}`,
    `DTEND${end.param}:${end.stamp}`,
    `SUMMARY:${escapeIcs(event.summary)}`,
    event.description ? `DESCRIPTION:${escapeIcs(event.description)}` : null,
    event.location ? `LOCATION:${escapeIcs(event.location)}` : null,
    'END:VEVENT',
    'END:VCALENDAR',
    '',
  ].filter((line) => line !== null).join('\r\n');
}

function buildContactVcard(contact) {
  const uid = text(contact.uid) || crypto.randomUUID();
  return [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `UID:${uid}`,
    `FN:${escapeIcs(contact.fullName)}`,
    contact.email ? `EMAIL:${escapeIcs(contact.email)}` : null,
    contact.phone ? `TEL:${escapeIcs(contact.phone)}` : null,
    contact.organization ? `ORG:${escapeIcs(contact.organization)}` : null,
    'END:VCARD',
    '',
  ].filter((line) => line !== null).join('\r\n');
}

function toCalDavUtc(value) {
  const date = new Date(text(value));
  if (Number.isNaN(date.getTime())) {
    throw new Error('Datetime must be an ISO-8601 value.');
  }
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

module.exports = {
  buildContactVcard,
  buildEventIcs,
  parseContact,
  parseDavResponses,
  parseEvent,
  toCalDavUtc,
  xmlText,
};
