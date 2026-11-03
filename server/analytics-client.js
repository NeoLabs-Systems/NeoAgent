/* Coarse browser analytics: no page content, URLs, identifiers, or error details. */
(function () {
  'use strict';
  if (navigator.doNotTrack === '1' || window.doNotTrack === '1' || navigator.globalPrivacyControl === true) return;
  var area = location.pathname === '/' || location.pathname === '/index.html' ? 'landing' : 'app';
  var script = document.createElement('script');
  script.src = 'https://data.neo.eu.com/script.js';
  script.defer = true;
  script.referrerPolicy = 'no-referrer';
  script.dataset.websiteId = '__WEBSITE_ID__';
  script.dataset.autoTrack = 'false';
  script.onload = function () {
    if (!window.umami || typeof window.umami.track !== 'function') return;
    function send(name, data) {
      try {
        var result = window.umami.track(function (props) {
          var payload = { website: props.website, url: '/' + area, language: props.language, screen: props.screen };
          if (name) payload.name = name;
          if (data) payload.data = data;
          return payload;
        });
        if (result && result.catch) result.catch(function () {});
      } catch (_) { /* Analytics must not affect the application. */ }
    }
    send();
    function reportLoad() {
      var start = performance.getEntriesByType('navigation')[0];
      if (!start) return;
      var seconds = start.loadEventEnd / 1000;
      send('page-load', { duration: seconds < 1 ? '<1s' : seconds < 3 ? '1-3s' : seconds < 10 ? '3-10s' : '10s+' });
    }
    if (document.readyState === 'complete') reportLoad();
    else window.addEventListener('load', function () { setTimeout(reportLoad, 0); }, { once: true });
    // Only preselected API groups are recorded; paths and request data never leave the browser.
    var groups = ['agents', 'agent-profiles', 'tasks', 'memory', 'skills', 'integrations', 'messaging', 'computer', 'artifacts', 'settings', 'mcp', 'neorouter', 'voice-assistant', 'wearable', 'triggers'];
    var adminSections = ['version', 'update', 'health', 'logs', 'analytics', 'users', 'config', 'sql', 'messaging', 'access', 'signup-keys', 'providers', 'models'];
    var counts = Object.create(null);
    function feature(url, method, status) {
      try {
        var parsed = new URL(url, location.href);
        if (parsed.origin !== location.origin) return;
        var match = parsed.pathname.match(/^\/api\/(?:v1\/)?([^/]+)(?:\/([^/]+))?/);
        if (!match) return;
        var group = match[1];
        if (group === 'admin') {
          group = adminSections.indexOf(match[2]) === -1 ? 'admin' : 'admin-' + match[2];
        } else if (groups.indexOf(group) === -1) return;
        var operation = /^(GET|HEAD)$/i.test(method || 'GET') ? 'read' : 'write';
        var outcome = status === 0 ? 'network-error' : status < 400 ? 'success' : status < 500 ? 'client-error' : 'server-error';
        var key = group + '|' + operation + '|' + outcome;
        counts[key] = Math.min((counts[key] || 0) + 1, 1000);
      } catch (_) { /* Ignore unparseable URLs. */ }
    }
    if (window.fetch) {
      var originalFetch = window.fetch;
      window.fetch = function (input, options) {
        var url = typeof input === 'string' || input instanceof URL ? input : input.url;
        var method = (options && options.method) || (input && input.method) || 'GET';
        var request = originalFetch.apply(this, arguments);
        request.then(function (response) { feature(url, method, response.status); }, function () { feature(url, method, 0); });
        return request;
      };
    }
    if (window.XMLHttpRequest) {
      var originalOpen = XMLHttpRequest.prototype.open;
      var originalSend = XMLHttpRequest.prototype.send;
      var requests = new WeakMap();
      XMLHttpRequest.prototype.open = function (method, url) {
        var result = originalOpen.apply(this, arguments);
        requests.set(this, { method: method, url: url });
        return result;
      };
      XMLHttpRequest.prototype.send = function () {
        var info = requests.get(this);
        if (info) this.addEventListener('loadend', function () { feature(info.url, info.method, this.status); }, { once: true });
        return originalSend.apply(this, arguments);
      };
    }
    var interactions = 0;
    var errors = 0;
    document.addEventListener('click', function () { interactions++; }, true);
    window.addEventListener('error', function () { errors++; });
    window.addEventListener('unhandledrejection', function () { errors++; });
    function flush() {
      Object.keys(counts).forEach(function (key) {
        var parts = key.split('|');
        send('feature-requests', { feature: parts[0], operation: parts[1], outcome: parts[2], count: counts[key] });
      });
      counts = Object.create(null);
      if (interactions) send('interactions', { count: Math.min(interactions, 1000) });
      if (errors) send('browser-errors', { count: Math.min(errors, 1000) });
      interactions = 0;
      errors = 0;
    }
    setInterval(flush, 30000);
    setInterval(function () {
      if (document.visibilityState === 'visible') send('active-browser');
    }, 60000);
    document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'hidden') flush(); });
    window.addEventListener('popstate', function () { send('navigation'); });
  };
  document.head.appendChild(script);
}());
