'use strict';

const PROVIDER_KEY = 'nextcloud';
const USER_AGENT = 'NeoAgent Nextcloud Integration';
const LOGIN_TIMEOUT_MS = 5 * 60 * 1000;
const LOGIN_POLL_MS = 1500;
const MAX_UPLOAD_BYTES = 100 * 1024 * 1024;
const MAX_READ_BYTES = 512 * 1024;

const FILES_APP = Object.freeze({
  id: 'files',
  label: 'Files',
  description: 'Browse, search, upload, share, and restore files in a connected Nextcloud account.',
});

const CALENDAR_APP = Object.freeze({
  id: 'calendar',
  label: 'Calendar',
  description: 'List calendars and create, update, or delete events in Nextcloud Calendar.',
});

const CONTACTS_APP = Object.freeze({
  id: 'contacts',
  label: 'Contacts',
  description: 'List address books and create, update, or delete Nextcloud contacts.',
});

const APPS = Object.freeze([FILES_APP, CALENDAR_APP, CONTACTS_APP]);

module.exports = {
  APPS,
  CALENDAR_APP,
  CONTACTS_APP,
  FILES_APP,
  LOGIN_POLL_MS,
  LOGIN_TIMEOUT_MS,
  MAX_READ_BYTES,
  MAX_UPLOAD_BYTES,
  PROVIDER_KEY,
  USER_AGENT,
};
