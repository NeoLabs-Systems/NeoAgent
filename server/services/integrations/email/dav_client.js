'use strict';

const { fetchResponseBuffer } = require('../../network/http');
const { xmlText } = require('../dav/format');
const { normalizeServerUrl } = require('../dav/paths');

const MAX_REDIRECTS = 3;

const COLLECTIONS = Object.freeze({
  caldav: {
    label: 'CalDAV URL',
    wellKnown: '/.well-known/caldav',
    namespace: 'urn:ietf:params:xml:ns:caldav',
    homeSet: 'calendar-home-set',
  },
  carddav: {
    label: 'CardDAV URL',
    wellKnown: '/.well-known/carddav',
    namespace: 'urn:ietf:params:xml:ns:carddav',
    homeSet: 'addressbook-home-set',
  },
});

function authorization({ username, password }) {
  return `Basic ${Buffer.from(`${username}:${password}`, 'utf8').toString('base64')}`;
}

// Providers move the home to a sibling host (iCloud answers on pNN-caldav),
// so a hop may change host within the same site, and only over HTTPS.
function sameSite(from, to) {
  if (from.origin === to.origin) return true;
  if (to.protocol !== 'https:') return false;
  const site = (host) => host.split('.').slice(-2).join('.');
  return site(from.hostname) === site(to.hostname);
}

async function davFetch(url, auth, options = {}) {
  const { response, body } = await fetchResponseBuffer(url.toString(), {
    method: options.method || 'PROPFIND',
    headers: {
      Authorization: authorization(auth),
      Accept: options.accept || 'application/xml, text/xml, */*',
      ...(options.headers || {}),
    },
    body: options.body,
    redirect: 'manual',
    signal: options.signal,
    serviceName: options.serviceName || 'DAV server',
    timeoutCode: 'INTEGRATION_HTTP_TIMEOUT',
    tooLargeCode: 'INTEGRATION_RESPONSE_TOO_LARGE',
  });
  return { response, text: body.toString('utf8') };
}

async function propfind(startUrl, auth, prop, namespace, signal) {
  let url = startUrl;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    const { response, text } = await davFetch(url, auth, {
      headers: { Depth: '0', 'Content-Type': 'application/xml; charset=utf-8' },
      body: `<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="${namespace}"><d:prop>${prop}</d:prop></d:propfind>`,
      signal,
    });
    if (response.status >= 300 && response.status < 400) {
      const next = new URL(response.headers.get('location') || '', url);
      if (!sameSite(url, next)) throw new Error('The server redirected to a different site.');
      url = next;
      continue;
    }
    if (response.status === 401) throw new Error('The server rejected the email address or app password.');
    if (!response.ok) return null;
    return { url, xml: text };
  }
  throw new Error('The server redirected too many times.');
}

// The href inside a property such as <d:current-user-principal><d:href>…
function hrefIn(xml, property) {
  return xmlText(xmlText(xml, property), 'href');
}

/**
 * Finds the calendar or address book home for an account (RFC 6764): the URL
 * given, then its well-known path, then the principal it names.
 */
async function discoverHome(serverUrl, kind, auth, { signal } = {}) {
  const collection = COLLECTIONS[kind];
  const base = new URL(normalizeServerUrl(serverUrl, collection.label));
  const homeProp = `<c:${collection.homeSet}/>`;
  for (const candidate of [base, new URL(collection.wellKnown, base)]) {
    const root = await propfind(candidate, auth, `<d:current-user-principal/>${homeProp}`, collection.namespace, signal);
    if (!root) continue;
    let homeHref = hrefIn(root.xml, collection.homeSet);
    let from = root.url;
    if (!homeHref) {
      const principalHref = hrefIn(root.xml, 'current-user-principal');
      if (!principalHref) continue;
      const principalUrl = new URL(principalHref, root.url);
      if (!sameSite(root.url, principalUrl)) throw new Error('The server named a principal on a different site.');
      const principal = await propfind(principalUrl, auth, homeProp, collection.namespace, signal);
      homeHref = principal ? hrefIn(principal.xml, collection.homeSet) : '';
      from = principal?.url || principalUrl;
    }
    if (!homeHref) continue;
    const home = new URL(homeHref, from);
    if (!sameSite(base, home)) throw new Error('The server named a home on a different site.');
    return { origin: home.origin, home: home.pathname.replace(/\/?$/, '/') };
  }
  throw new Error(`No ${kind === 'caldav' ? 'calendars' : 'address books'} were found at ${base.host}.`);
}

/** The `{ home, request }` store the shared DAV tools run against. */
function createDavStore(location, auth) {
  return {
    home: location.home,
    async request(path, options = {}) {
      const url = new URL(path, location.origin);
      if (url.origin !== location.origin) throw new Error('DAV path must stay on the connected server.');
      const { response, text } = await davFetch(url, auth, options);
      if (response.status >= 300 && response.status < 400) {
        throw new Error('The DAV server redirected the request; redirects are not followed.');
      }
      if (!response.ok) {
        throw new Error(`DAV request failed (${response.status}): ${text.slice(0, 300)}`);
      }
      return { response, text };
    },
  };
}

module.exports = { createDavStore, discoverHome };
