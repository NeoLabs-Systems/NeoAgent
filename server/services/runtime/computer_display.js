'use strict';

const COMPUTER_DISPLAY_WIDTH = 1280;
const COMPUTER_DISPLAY_HEIGHT = 720;

function computerDisplayMode() {
  return `${COMPUTER_DISPLAY_WIDTH}x${COMPUTER_DISPLAY_HEIGHT}`;
}

function buildComputerDisplayPage({ websocketPath, viewOnly = false }) {
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
// A dropped socket leaves the last frame painted on the canvas, which is
// indistinguishable from a live but idle desktop, so reconnect on a fresh
// session instead of leaving a still image the viewer cannot control.
const connect = (websocketPath, viewOnly) => {
  screen.innerHTML = '';
  const rfb = new RFB(screen, scheme + '://' + location.host + websocketPath);
  rfb.scaleViewport = true;
  rfb.resizeSession = false;
  rfb.clipViewport = false;
  rfb.focusOnClick = true;
  rfb.showDotCursor = true;
  rfb.qualityLevel = 6;
  rfb.compressionLevel = 2;
  rfb.viewOnly = viewOnly === true;
  rfb.addEventListener('connect', () => {
    attempt = 0;
    rfb.focus();
  });
  rfb.addEventListener('disconnect', reconnect);
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
connect(${JSON.stringify(websocketPath)}, ${viewOnly === true ? 'true' : 'false'});
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
