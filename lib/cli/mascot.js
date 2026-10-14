'use strict';

const ui = require('./ui');

// The NeoAgent face: a 9×9 dot matrix on a near-black screen inside a rounded
// rim, gold where lit. These faces are the same frames the landing page
// (landing/js/mascot.js), the app and the wearable firmware draw.
const BLANK = '.........';
const FACES = Object.freeze({
  idle: [BLANK, BLANK, '..##.##..', '..##.##..', '..##.##..', BLANK, BLANK, BLANK, BLANK],
  done: [BLANK, BLANK, '..#...#..', '.#.#.#.#.', BLANK, BLANK, '..#...#..', '...###...', BLANK],
});

// A dot and the space after it are about square in a terminal cell. The rim
// is drawn with half and quarter blocks, so it is half a cell thick and its
// corners round off.
function renderFace(name = 'idle') {
  const rows = FACES[name];
  if (ui.colorDepth === 0) {
    return [
      `╭${'─'.repeat(19)}╮`,
      ...rows.map((row) => `│ ${[...row].map((cell) => (cell === '#' ? '●' : '·')).join(' ')} │`),
      `╰${'─'.repeat(19)}╯`,
    ];
  }
  const rim = (text) => ui.sgr(ui.foreground('rim'), text);
  const screenColor = ui.background('screen');
  const dot = (cell) => (cell === '#'
    ? `\x1b[1;${ui.foreground('accent')}m●`
    : `\x1b[22;${ui.foreground('unlit')}m·`);
  const screen = (row) => `\x1b[${screenColor}m ${[...row].map(dot).join(' ')} \x1b[0m`;
  return [
    rim(`▗${'▄'.repeat(19)}▖`),
    ...rows.map((row) => `${rim('▐')}${screen(row)}${rim('▌')}`),
    rim(`▝${'▀'.repeat(19)}▘`),
  ];
}

module.exports = {
  renderFace,
};
