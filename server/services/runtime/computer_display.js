'use strict';

const COMPUTER_DISPLAY_WIDTH = 1280;
const COMPUTER_DISPLAY_HEIGHT = 720;

function computerDisplayMode() {
  return `${COMPUTER_DISPLAY_WIDTH}x${COMPUTER_DISPLAY_HEIGHT}`;
}

// `websocketPath` may be empty: a page loaded from a token the server no longer knows
// (a restart, an expired link) opens its own session rather than dead-ending.
function buildComputerDisplayPage({ websocketPath = '', viewOnly = false }) {
  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body,#screen{width:100%;height:100%;margin:0;overflow:hidden;background:#111}
#screen{display:flex;align-items:center;justify-content:center}
canvas{outline:none}
</style></head>
<body><div id="screen"></div><script type="module">
import RFB from '/api/computer/novnc/core/rfb.js';
const scheme = location.protocol === 'https:' ? 'wss' : 'ws';
const screen = document.getElementById('screen');
let attempt = 0;
let generation = 0;
// Keep the last painted frame until the next RFB session is connected. Clearing
// the screen on every retry flashes the guest console, which looks like the
// desktop and terminal swapping. A still image is only a problem if we never
// reconnect, so reconnect on the same generation rather than wiping first.
const connect = (websocketPath, viewOnly) => {
  const current = ++generation;
  const rfb = new RFB(screen, scheme + '://' + location.host + websocketPath);
  rfb.scaleViewport = true;
  rfb.resizeSession = false;
  rfb.clipViewport = true;
  rfb.focusOnClick = true;
  rfb.showDotCursor = true;
  rfb.qualityLevel = 6;
  rfb.compressionLevel = 2;
  rfb.viewOnly = viewOnly === true;
  rfb.addEventListener('connect', () => {
    attempt = 0;
    while (screen.childElementCount > 1) screen.removeChild(screen.firstElementChild);
    rfb.focus();
  });
  rfb.addEventListener('disconnect', () => {
    if (current === generation) reconnect();
  });
};
const reconnect = () => {
  attempt += 1;
  setTimeout(async () => {
    try {
      const response = await fetch('/api/computer/display-session', {
        method: 'POST', credentials: 'same-origin', headers: {'content-type':'application/json'}, body: '{}',
      });
      const session = response.ok ? await response.json() : null;
      if (session?.websocketPath) connect(session.websocketPath, session.viewOnly);
      else reconnect();
    } catch {
      reconnect();
    }
  }, Math.min(10000, 500 * attempt));
};
${websocketPath
    ? `connect(${JSON.stringify(websocketPath)}, ${viewOnly === true ? 'true' : 'false'});`
    : 'reconnect();'}
const record = (event) => fetch('/api/computer/teach/events', {
  method: 'POST', credentials: 'same-origin', headers: {'content-type':'application/json'},
  body: JSON.stringify(event),
}).catch(() => {});
screen.addEventListener('pointerup', (event) => {
  const rect = event.currentTarget.getBoundingClientRect();
  record({type:'pointer', x:Math.round(event.clientX-rect.left), y:Math.round(event.clientY-rect.top), button:event.button});
}, true);
document.addEventListener('keydown', (event) => {
  const printable = event.key && event.key.length === 1;
  record({type:printable?'text-input':'key', key:printable?null:event.key, modifiers:{alt:event.altKey,ctrl:event.ctrlKey,meta:event.metaKey,shift:event.shiftKey}});
}, true);
</script></body></html>`;
}

module.exports = {
  COMPUTER_DISPLAY_WIDTH,
  COMPUTER_DISPLAY_HEIGHT,
  buildComputerDisplayPage,
  computerDisplayMode,
};
