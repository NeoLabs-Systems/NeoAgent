'use strict';

// What the server adds around a shared page: the notice that a NeoAgent user
// made it, and the page shown while it cannot be reached. Both work without
// JavaScript, since a shared page may forbid scripts it did not write.

const NOTICE_COOKIE = 'neoagent_share_notice';
const HIDE_NOTICE_PATH = '/.neoagent/hide-notice';

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

function noticeHidden(cookieHeader) {
  return String(cookieHeader || '').split(';').some((part) => part.trim() === `${NOTICE_COOKIE}=hidden`);
}

// Dismiss is a checkbox the label toggles, so it lasts for this view; "don't
// show again" goes through the server, which remembers it in a cookie.
function noticeMarkup({ username, prefix, returnPath }) {
  const hideHref = `${prefix}${HIDE_NOTICE_PATH}?back=${encodeURIComponent(returnPath)}`;
  return `<div id="neoagent-share-notice" role="note" aria-label="About this page">`
    + '<input type="checkbox" id="neoagent-share-dismiss" hidden>'
    + '<div class="nasn-bar">'
    + `<span class="nasn-text">Shared by <b>${escapeHtml(username)}</b>. A NeoAgent user made this page; it does not come from or represent NeoAgent.</span>`
    + `<a class="nasn-link" href="${escapeHtml(hideHref)}">Don't show again</a>`
    + '<label class="nasn-close" for="neoagent-share-dismiss" title="Dismiss" aria-label="Dismiss">&#x2715;</label>'
    + '</div>'
    + '<style>'
    + '#neoagent-share-notice .nasn-bar{all:initial;position:fixed;z-index:2147483647;left:50%;bottom:16px;transform:translateX(-50%);'
    + 'box-sizing:border-box;max-width:min(680px,calc(100vw - 24px));display:flex;align-items:center;gap:12px;padding:8px 8px 8px 16px;'
    + 'border-radius:999px;background:rgba(24,24,27,.94);color:#f4f4f5;box-shadow:0 6px 24px rgba(0,0,0,.28);'
    + 'font:13px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;-webkit-font-smoothing:antialiased}'
    + '#neoagent-share-notice .nasn-text{all:unset;flex:1;min-width:0}'
    + '#neoagent-share-notice .nasn-text b{all:unset;font-weight:600}'
    + '#neoagent-share-notice .nasn-link{all:unset;cursor:pointer;white-space:nowrap;color:#a5b4fc;text-decoration:underline;text-underline-offset:2px}'
    + '#neoagent-share-notice .nasn-close{all:unset;cursor:pointer;display:grid;place-items:center;width:28px;height:28px;flex:none;border-radius:50%;color:#d4d4d8}'
    + '#neoagent-share-notice .nasn-close:hover,#neoagent-share-notice .nasn-link:hover{color:#fff}'
    + '#neoagent-share-notice .nasn-close:focus-visible,#neoagent-share-notice .nasn-link:focus-visible{outline:2px solid #a5b4fc;outline-offset:2px}'
    + '#neoagent-share-dismiss:checked+.nasn-bar{display:none}'
    + '@media (max-width:520px){#neoagent-share-notice .nasn-bar{border-radius:14px;bottom:12px;flex-wrap:wrap;gap:4px 12px;padding:10px 8px 10px 14px}'
    + '#neoagent-share-notice .nasn-text{flex-basis:calc(100% - 44px)}}'
    + '</style></div>';
}

// The notice goes right after <body>, or first when a page has none.
function injectNotice(html, notice) {
  const body = /<body\b[^>]*>/i.exec(html);
  if (body) return html.slice(0, body.index + body[0].length) + notice + html.slice(body.index + body[0].length);
  return notice + html;
}

function offlinePage({ username, title }) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>${escapeHtml(title)} is offline</title>
<style>
:root{color-scheme:light dark;--bg:#fafafa;--card:#fff;--text:#18181b;--muted:#71717a;--line:#e4e4e7}
@media (prefers-color-scheme:dark){:root{--bg:#09090b;--card:#18181b;--text:#f4f4f5;--muted:#a1a1aa;--line:#27272a}}
body{margin:0;min-height:100vh;display:grid;place-items:center;background:var(--bg);color:var(--text);font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;padding:16px;box-sizing:border-box}
main{max-width:420px;width:100%;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:28px}
h1{font-size:19px;margin:0 0 8px}p{margin:0 0 12px;color:var(--muted)}small{color:var(--muted)}
</style></head><body><main>
<h1>${escapeHtml(title)} is offline</h1>
<p>The computer serving this page is not running right now, or the app on it has stopped. It comes back when its owner starts it again.</p>
<small>Shared by ${escapeHtml(username)}. A NeoAgent user made this page; it does not come from or represent NeoAgent.</small>
</main></body></html>`;
}

module.exports = {
  HIDE_NOTICE_PATH,
  NOTICE_COOKIE,
  injectNotice,
  noticeHidden,
  noticeMarkup,
  offlinePage,
};
