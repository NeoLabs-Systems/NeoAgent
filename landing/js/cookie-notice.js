/* NeoAgent — EU storage/cookie notice.
   Shared by the landing pages and the Flutter web client (both same origin).
   Informational, not a consent gate: nothing non-essential is stored, so there
   is nothing to opt out of. Acknowledgement itself is the only thing written. */
(function () {
  'use strict';

  var KEY = 'neoagent.storage-notice.ack';

  function alreadyAcknowledged() {
    try {
      return window.localStorage.getItem(KEY) === '1';
    } catch {
      // Storage blocked (private mode, hardened browser) — nothing was kept, so show it.
      return false;
    }
  }

  function remember() {
    try {
      window.localStorage.setItem(KEY, '1');
    } catch {
      /* nothing we can do; the notice returns next visit */
    }
  }

  if (alreadyAcknowledged()) return;

  var CSS = [
    '#na-notice{',
    'position:fixed;left:50%;bottom:max(16px,env(safe-area-inset-bottom));',
    'transform:translate(-50%,0);z-index:2147483000;',
    'width:min(560px,calc(100vw - 32px));box-sizing:border-box;',
    'padding:16px 18px;border-radius:18px;',
    'background:var(--na-n-bg);border:1px solid var(--na-n-line);',
    '-webkit-backdrop-filter:blur(18px) saturate(1.3);backdrop-filter:blur(18px) saturate(1.3);',
    'box-shadow:0 24px 60px -28px rgba(12,16,10,.45),0 6px 18px -12px rgba(12,16,10,.25);',
    'font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;',
    'color:var(--na-n-ink);font-size:13.5px;line-height:1.55;',
    'opacity:0;animation:na-notice-in .45s cubic-bezier(.22,1,.36,1) .35s forwards;}',

    '#na-notice[data-leaving]{animation:na-notice-out .28s ease forwards;}',

    '@keyframes na-notice-in{from{opacity:0;transform:translate(-50%,14px)}',
    'to{opacity:1;transform:translate(-50%,0)}}',
    '@keyframes na-notice-out{to{opacity:0;transform:translate(-50%,10px)}}',

    '#na-notice .na-n-row{display:flex;align-items:flex-start;gap:14px;}',
    '#na-notice p{margin:0;color:var(--na-n-ink-2);}',
    '#na-notice strong{color:var(--na-n-ink);font-weight:600;}',

    '#na-notice .na-n-actions{display:flex;align-items:center;gap:10px;flex-shrink:0;}',

    '#na-notice button{font:inherit;cursor:pointer;border-radius:11px;',
    'padding:8px 15px;border:1px solid transparent;white-space:nowrap;',
    'transition:background .18s ease,color .18s ease,border-color .18s ease;}',
    '#na-notice button:focus-visible{outline:2px solid var(--na-n-gold);outline-offset:2px;}',

    '#na-notice .na-n-ok{background:var(--na-n-btn);color:var(--na-n-btn-ink);font-weight:600;}',
    '#na-notice .na-n-ok:hover{background:var(--na-n-btn-hover);}',

    '#na-notice .na-n-more{background:transparent;color:var(--na-n-ink-2);',
    'border-color:var(--na-n-line-2);padding:8px 12px;}',
    '#na-notice .na-n-more:hover{color:var(--na-n-ink);border-color:var(--na-n-ink-3);}',

    '#na-notice .na-n-detail{margin-top:12px;padding-top:12px;',
    'border-top:1px solid var(--na-n-line-2);color:var(--na-n-ink-2);font-size:12.5px;}',
    '#na-notice .na-n-detail[hidden]{display:none;}',
    '#na-notice ul{margin:0;padding-left:18px;}',
    '#na-notice li{margin:3px 0;}',

    '@media (max-width:560px){',
    '#na-notice .na-n-row{flex-direction:column;gap:12px;}',
    '#na-notice .na-n-actions{width:100%;}',
    '#na-notice .na-n-ok{flex:1;}}',

    '@media (prefers-reduced-motion:reduce){',
    '#na-notice,#na-notice[data-leaving]{animation-duration:.01ms;animation-delay:0ms;opacity:1;}}',

    ':root{',
    '--na-n-bg:rgba(253,252,248,.88);--na-n-line:rgba(28,33,23,.12);',
    '--na-n-line-2:rgba(28,33,23,.10);--na-n-ink:#1c2117;--na-n-ink-2:#49503f;',
    '--na-n-ink-3:#7e8470;--na-n-gold:#b07d2b;',
    '--na-n-btn:#1c2117;--na-n-btn-ink:#fdfcf8;--na-n-btn-hover:#2a3226;}',

    '@media (prefers-color-scheme:dark){:root{',
    '--na-n-bg:rgba(23,31,26,.9);--na-n-line:rgba(224,240,224,.14);',
    '--na-n-line-2:rgba(224,240,224,.10);--na-n-ink:#ecefe5;--na-n-ink-2:#aeb7a6;',
    '--na-n-ink-3:#7e8877;--na-n-gold:#e1b052;',
    '--na-n-btn:#e1b052;--na-n-btn-ink:#161d18;--na-n-btn-hover:#eec276;}}'
  ].join('');

  var HTML = [
    '<div class="na-n-row">',
    '<p><strong>Essential storage only.</strong> NeoAgent keeps your sign-in session, ',
    'server address and app settings on this device so the app works. ',
    'No tracking, no advertising, no analytics.</p>',
    '<div class="na-n-actions">',
    '<button type="button" class="na-n-more" aria-expanded="false">What\'s stored</button>',
    '<button type="button" class="na-n-ok">Got it</button>',
    '</div></div>',
    '<div class="na-n-detail" hidden>',
    '<ul>',
    '<li>Your session and the backend URL you connect to, so you stay signed in.</li>',
    '<li>App preferences such as update channel and notification settings.</li>',
    '<li>A flag remembering that you dismissed this notice.</li>',
    '<li>Web fonts are loaded from Google Fonts, which sees your IP address.</li>',
    '</ul>',
    '<p style="margin-top:8px">All of this is required for the site and app to ',
    'function, so no consent choice is offered — there is nothing optional to refuse.</p>',
    '</div>'
  ].join('');

  function mount() {
    var style = document.createElement('style');
    style.textContent = CSS;
    document.head.appendChild(style);

    var el = document.createElement('section');
    el.id = 'na-notice';
    el.setAttribute('role', 'region');
    el.setAttribute('aria-label', 'Storage notice');
    el.innerHTML = HTML;
    document.body.appendChild(el);

    var more = el.querySelector('.na-n-more');
    var detail = el.querySelector('.na-n-detail');
    more.addEventListener('click', function () {
      var open = detail.hidden;
      detail.hidden = !open;
      more.setAttribute('aria-expanded', String(open));
    });

    function dismiss() {
      remember();
      el.setAttribute('data-leaving', '');
      document.removeEventListener('keydown', onKey);
      el.addEventListener('animationend', function () { el.remove(); style.remove(); });
    }

    function onKey(event) {
      if (event.key === 'Escape') dismiss();
    }

    el.querySelector('.na-n-ok').addEventListener('click', dismiss);
    document.addEventListener('keydown', onKey);
  }

  // The Flutter client paints a full-screen splash first; waiting for it to go
  // keeps the notice from floating over a loading screen.
  function mountWhenReady() {
    if (!document.getElementById('splash')) {
      mount();
      return;
    }
    var waited = 0;
    var timer = setInterval(function () {
      waited += 200;
      if (document.getElementById('splash') && waited < 10000) return;
      clearInterval(timer);
      mount();
    }, 200);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mountWhenReady);
  } else {
    mountWhenReady();
  }
})();
