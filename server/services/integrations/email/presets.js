'use strict';

// Mail providers that accept an app password over IMAP/SMTP (and CalDAV or
// CardDAV where they offer it), plus calendars shared by an iCal link. The
// setup dialog is built from this list, so adding a provider here is all it
// takes to offer it.
const PRESETS = Object.freeze([
  {
    id: 'gmail',
    label: 'Gmail',
    icon: 'google',
    imap: { host: 'imap.gmail.com', port: 993, secure: true },
    smtp: { host: 'smtp.gmail.com', port: 465, secure: true },
    savesSentMail: true,
    passwordUrl: 'https://myaccount.google.com/apppasswords',
    help: 'Turn on 2-Step Verification for your Google account, then create an app password named NeoAgent. For Google Calendar, add a Calendar link with its secret iCal address.',
  },
  {
    id: 'icloud',
    label: 'iCloud',
    icon: 'apple',
    imap: { host: 'imap.mail.me.com', port: 993, secure: true },
    smtp: { host: 'smtp.mail.me.com', port: 587, secure: false },
    caldavUrl: 'https://caldav.icloud.com',
    carddavUrl: 'https://contacts.icloud.com',
    passwordUrl: 'https://account.apple.com/account/manage',
    help: 'Under Sign-In and Security, choose App-Specific Passwords and create one named NeoAgent. Use your Apple Account email address.',
  },
  {
    id: 'fastmail',
    label: 'Fastmail',
    icon: 'mail',
    imap: { host: 'imap.fastmail.com', port: 993, secure: true },
    smtp: { host: 'smtp.fastmail.com', port: 465, secure: true },
    caldavUrl: 'https://caldav.fastmail.com',
    carddavUrl: 'https://carddav.fastmail.com',
    passwordUrl: 'https://www.fastmail.help/hc/en-us/articles/360058752854-App-passwords',
    help: 'Create an app password with access to mail, calendars and contacts.',
  },
  {
    id: 'yahoo',
    label: 'Yahoo Mail',
    icon: 'mail',
    imap: { host: 'imap.mail.yahoo.com', port: 993, secure: true },
    smtp: { host: 'smtp.mail.yahoo.com', port: 465, secure: true },
    passwordUrl: 'https://login.yahoo.com/account/security',
    help: 'Under Account Security, choose Generate app password and name it NeoAgent.',
  },
  {
    id: 'outlook',
    label: 'Outlook / Microsoft 365',
    icon: 'microsoft',
    unsupported: true,
    alternativeProvider: 'microsoft_365',
    help: 'Microsoft no longer accepts app passwords for mail. Connect it through the Microsoft 365 integration instead, or add your Outlook calendar as a Calendar link.',
  },
  {
    id: 'ical',
    label: 'Calendar link (iCal)',
    icon: 'calendar',
    feed: true,
    help: 'Paste a calendar\'s iCal address to let the agent read it. Google Calendar: Settings › your calendar › Integrate calendar › Secret address in iCal format. Outlook: Settings › Calendar › Shared calendars › Publish a calendar, then the ICS link. iCloud: share the calendar as a Public Calendar. The agent can read it but not change it.',
  },
  {
    id: 'custom',
    label: 'Other provider',
    icon: 'mail',
    custom: true,
    help: 'Enter the IMAP and SMTP servers from your provider. Calendar and contacts are optional and need CalDAV or CardDAV URLs.',
  },
]);

function findPreset(id) {
  return PRESETS.find((preset) => preset.id === String(id || '').trim()) || null;
}

module.exports = { PRESETS, findPreset };
