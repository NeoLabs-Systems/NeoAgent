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
const rfb = new RFB(document.getElementById('screen'), scheme + '://' + location.host + ${JSON.stringify(websocketPath)});
rfb.scaleViewport = true;
rfb.resizeSession = false;
rfb.clipViewport = false;
rfb.focusOnClick = true;
rfb.showDotCursor = true;
rfb.qualityLevel = 6;
rfb.compressionLevel = 2;
rfb.viewOnly = ${viewOnly === true ? 'true' : 'false'};
rfb.addEventListener('connect', () => rfb.focus());
const record = (event) => fetch('/api/computer/teach/events', {
  method: 'POST', credentials: 'same-origin', headers: {'content-type':'application/json'},
  body: JSON.stringify(event),
}).catch(() => {});
document.getElementById('screen').addEventListener('pointerup', (event) => {
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
