'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const originalFetch = global.fetch;
let ctx;

function xmlResponse(body, status = 207) {
  return new Response(body, { status, headers: { 'Content-Type': 'application/xml' } });
}

afterEach(() => {
  global.fetch = originalFetch;
  teardownTestRuntime(ctx);
  ctx = null;
});

test('the setup dialog gets every provider, with Outlook pointed at Microsoft 365', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'email_presets' });
  const { createEmailProvider } = require('../../../server/services/integrations/email/provider');
  const provider = createEmailProvider();

  const config = provider.getUserConfig({ userId: user.userId });
  const ids = config.presets.map((preset) => preset.id);
  assert.deepEqual(ids, ['gmail', 'icloud', 'fastmail', 'yahoo', 'outlook', 'ical', 'custom']);
  assert.equal(config.presets.find((preset) => preset.id === 'ical').feed, true);
  const outlook = config.presets.find((preset) => preset.id === 'outlook');
  assert.equal(outlook.unsupported, true);
  assert.equal(outlook.alternativeProvider, 'microsoft_365');
  assert.equal(config.presets.find((preset) => preset.id === 'icloud').calendar, true);
  assert.equal(config.presets.find((preset) => preset.id === 'gmail').calendar, false);
  assert.deepEqual(config.accounts, []);

  await assert.rejects(
    () => provider.saveUserConfig({ userId: user.userId, config: { preset: 'outlook', email: 'a@b.test', password: 'x' } }),
    /Microsoft 365 integration/,
  );
  await assert.rejects(
    () => provider.saveUserConfig({ userId: user.userId, config: { preset: 'gmail', email: 'nope', password: 'x' } }),
    /valid email/,
  );
  await assert.rejects(
    () => provider.saveUserConfig({
      userId: user.userId,
      config: { preset: 'custom', email: 'a@b.test', password: 'x', imap: { host: 'mail.b.test', port: 22 } },
    }),
    /IMAP port must be one of 143, 993/,
  );
});

test('custom mail servers get implicit TLS on 993 and 465 and STARTTLS elsewhere', () => {
  const { parseServer } = require('../../../server/services/integrations/email/mail');
  assert.deepEqual(parseServer({ host: 'Mail.Example.test', port: 993 }, 'imap'), {
    host: 'mail.example.test', port: 993, secure: true,
  });
  assert.equal(parseServer({ host: 'smtp.example.test', port: 587 }, 'smtp').secure, false);
  assert.throws(() => parseServer({ host: 'bad host', port: 993 }, 'imap'), /host name/);
});

test('CalDAV discovery follows the principal to a home on a sibling host', async () => {
  ctx = createTestRuntime();
  const { discoverHome } = require('../../../server/services/integrations/email/dav_client');
  const seen = [];
  global.fetch = async (url, options = {}) => {
    seen.push(`${options.method} ${url}`);
    assert.match(options.headers.Authorization, /^Basic /);
    if (String(url) === 'https://caldav.icloud.test/') {
      return xmlResponse(`<d:multistatus xmlns:d="DAV:"><d:response><d:href>/</d:href><d:propstat><d:prop>
        <d:current-user-principal><d:href>/123/principal/</d:href></d:current-user-principal>
      </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>`);
    }
    if (String(url) === 'https://caldav.icloud.test/123/principal/') {
      return xmlResponse(`<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response>
        <d:href>/123/principal/</d:href><d:propstat><d:prop>
        <c:calendar-home-set><d:href>https://p57-caldav.icloud.test:443/123/calendars/</d:href></c:calendar-home-set>
      </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>`);
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const location = await discoverHome('https://caldav.icloud.test', 'caldav', { username: 'me@icloud.test', password: 'pw' });
  assert.deepEqual(location, { origin: 'https://p57-caldav.icloud.test', home: '/123/calendars/' });
  assert.deepEqual(seen, ['PROPFIND https://caldav.icloud.test/', 'PROPFIND https://caldav.icloud.test/123/principal/']);

  global.fetch = async () => xmlResponse(`<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response>
    <d:href>/</d:href><d:propstat><d:prop>
    <c:calendar-home-set><d:href>https://evil.example/calendars/</d:href></c:calendar-home-set>
    </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>`);
  await assert.rejects(
    () => discoverHome('https://caldav.icloud.test', 'caldav', { username: 'me', password: 'pw' }),
    /different site/,
  );
});

test('the shared calendar tools run against any DAV home', async () => {
  const { createCalendarTools } = require('../../../server/services/integrations/dav/calendar_tools');
  const tools = createCalendarTools({ prefix: 'caldav', label: 'Email & Calendar', appId: 'calendar' });
  assert.ok(tools.tools.some((tool) => tool.name === 'caldav_list_events' && tool.appId === 'calendar'));
  assert.equal(await tools.execute('email_search', {}, {}), null);

  const requests = [];
  const store = {
    home: '/123/calendars/',
    async request(path, options) {
      requests.push(`${options.method} ${path}`);
      return {
        text: `<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response>
          <d:href>/123/calendars/home/a.ics</d:href><d:propstat><d:prop><c:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:a
SUMMARY:Dentist
DTSTART:20261020T090000Z
DTEND:20261020T100000Z
END:VEVENT
END:VCALENDAR</c:calendar-data></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>`,
      };
    },
  };
  const listed = await tools.execute('caldav_list_events', { calendar: 'home' }, store);
  assert.deepEqual(requests, ['REPORT /123/calendars/home']);
  assert.equal(listed.result[0].summary, 'Dentist');
  assert.equal(listed.result[0].path, 'home/a.ics');
  await assert.rejects(() => tools.execute('caldav_get_event', { calendar: 'home', event_path: '../x' }, store), /parent traversal/);
});

test('a calendar link expands repeating events, keeps moved ones and all-day dates', () => {
  const ICAL = require('ical.js');
  const { eventsBetween, normalizeFeedUrl } = require('../../../server/services/integrations/email/feeds');
  assert.equal(normalizeFeedUrl('webcal://p01-caldav.icloud.test/published/2/abc'), 'https://p01-caldav.icloud.test/published/2/abc');
  assert.throws(() => normalizeFeedUrl('ftp://example.test/cal.ics'), /https:\/\/ or webcal/);

  const ics = [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'X-WR-CALNAME:Family',
    'BEGIN:VEVENT', 'UID:w', 'DTSTART:20261001T090000Z', 'DTEND:20261001T093000Z', 'RRULE:FREQ=WEEKLY', 'SUMMARY:Standup', 'END:VEVENT',
    'BEGIN:VEVENT', 'UID:w', 'RECURRENCE-ID:20261022T090000Z', 'DTSTART:20261022T110000Z', 'DTEND:20261022T113000Z', 'SUMMARY:Standup (moved)', 'END:VEVENT',
    'BEGIN:VEVENT', 'UID:d', 'DTSTART;VALUE=DATE:20261020', 'DTEND;VALUE=DATE:20261021', 'SUMMARY:Holiday', 'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
  const events = eventsBetween(new ICAL.Component(ICAL.parse(ics)), new Date('2026-10-14T00:00:00Z'), new Date('2026-10-30T00:00:00Z'));
  assert.deepEqual(events.map((event) => [event.title, event.start]), [
    ['Standup', '2026-10-15T09:00:00.000Z'],
    ['Holiday', '2026-10-20'],
    ['Standup (moved)', '2026-10-22T11:00:00.000Z'],
    ['Standup', '2026-10-29T09:00:00.000Z'],
  ]);
  assert.equal(events[1].allDay, true);
  assert.equal(events[0].calendar, 'Family');
});
