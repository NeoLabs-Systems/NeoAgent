'use strict';

// Terminal output for the neoagent CLI: the brand palette, a handful of line
// shapes, and a quiet mode for --json runs where stdout belongs to events.
// Every line fits the window: anything wider is cut, never wrapped, so the
// live blocks that redraw in place always know how many lines they own.

const ESC = '\x1b[';

// The app's dark-surface tokens (landing/css/styles.css, --app-*).
const PALETTE = Object.freeze({
  accent: { rgb: [225, 176, 82], ansi256: 179, ansi16: 33 },
  ok: { rgb: [116, 192, 124], ansi256: 114, ansi16: 32 },
  error: { rgb: [222, 138, 120], ansi256: 174, ansi16: 31 },
  muted: { rgb: [174, 183, 166], ansi256: 145, ansi16: 37 },
  faint: { rgb: [126, 136, 119], ansi256: 102, ansi16: 90 },
  // The mascot (flutter_app/lib/src/mascot/neo_mascot.dart): a green-grey
  // rim around a near-black screen of dim dots.
  rim: { rgb: [68, 80, 73], ansi256: 239, ansi16: 90 },
  screen: { rgb: [5, 8, 6], ansi256: 232, ansi16: 40 },
  unlit: { rgb: [64, 72, 68], ansi256: 238, ansi16: 90 },
});

const TONES = Object.freeze({
  ok: { mark: '✓', color: 'ok' },
  warn: { mark: '!', color: 'accent' },
  error: { mark: '✕', color: 'error' },
  pending: { mark: '○', color: 'faint' },
  info: { mark: '•', color: 'faint' },
});

function detectColorDepth(stream = process.stdout, env = process.env) {
  if (!stream.isTTY || 'NO_COLOR' in env || env.TERM === 'dumb') return 0;
  if (/truecolor|24bit/i.test(env.COLORTERM || '')) return 24;
  if (/256/.test(env.TERM || '')) return 8;
  return 4;
}

const colorDepth = detectColorDepth();
let silent = false;
let liveBlock = null;

function sgr(code, text) {
  return colorDepth === 0 ? String(text) : `${ESC}${code}m${text}${ESC}0m`;
}

function foreground(name) {
  const color = PALETTE[name];
  if (colorDepth === 24) return `38;2;${color.rgb.join(';')}`;
  if (colorDepth === 8) return `38;5;${color.ansi256}`;
  return String(color.ansi16);
}

function background(name) {
  const color = PALETTE[name];
  if (colorDepth === 24) return `48;2;${color.rgb.join(';')}`;
  if (colorDepth === 8) return `48;5;${color.ansi256}`;
  return String(color.ansi16 + 10);
}

const paint = Object.freeze({
  accent: (text) => sgr(foreground('accent'), text),
  error: (text) => sgr(foreground('error'), text),
  muted: (text) => sgr(foreground('muted'), text),
  faint: (text) => sgr(foreground('faint'), text),
  bold: (text) => sgr('1', text),
  command: (text) => sgr(`1;${foreground('accent')}`, text),
  tone: (tone, text) => sgr(foreground(TONES[tone].color), text),
});

const ANSI = /\x1b\[[0-9;]*m/g;

function visibleLength(text) {
  return [...String(text).replace(ANSI, '')].length;
}

function padEnd(text, width) {
  return `${text}${' '.repeat(Math.max(0, width - visibleLength(text)))}`;
}

function width() {
  return Math.max(20, process.stdout.columns || 80);
}

function isNarrow() {
  return width() < 64;
}

// Cuts a styled line to `max` visible characters, ending it with "…".
function truncate(text, max) {
  if (visibleLength(text) <= max) return text;
  let out = '';
  let shown = 0;
  for (const token of String(text).match(/\x1b\[[0-9;]*m|[\s\S]/gu) || []) {
    if (token.startsWith('\x1b[')) {
      out += token;
    } else if (shown < max - 1) {
      out += token;
      shown += 1;
    }
  }
  return colorDepth === 0 ? `${out}…` : `${out}…${ESC}0m`;
}

// Breaks plain text into lines of at most `max` characters, on spaces.
function wrap(text, max) {
  const lines = [];
  for (const paragraph of String(text).split('\n')) {
    let line = '';
    for (const word of paragraph.split(/\s+/).filter(Boolean)) {
      if (line && visibleLength(`${line} ${word}`) > max) {
        lines.push(line);
        line = word;
      } else {
        line = line ? `${line} ${word}` : word;
      }
    }
    lines.push(line);
  }
  return lines;
}

function configure(options = {}) {
  if (Object.hasOwn(options, 'silent')) silent = Boolean(options.silent);
}

function isInteractive() {
  return !silent && Boolean(process.stdin.isTTY && process.stdout.isTTY);
}

function canRedraw() {
  return !silent && Boolean(process.stdout.isTTY);
}

function fit(line) {
  return process.stdout.isTTY ? truncate(line, width() - 1) : line;
}

// A live block (a step list, a menu) owns the bottom of the screen. Anything
// printed while it shows goes above it, then the block is drawn again below.
function print(line = '') {
  if (silent) return;
  if (liveBlock) {
    liveBlock.clear();
    process.stdout.write(`${fit(line)}\n`);
    liveBlock.draw();
    return;
  }
  process.stdout.write(`${fit(line)}\n`);
}

// Draws lines that will be redrawn in place. Returns their widths, which
// clearBlock needs: a terminal made narrower re-wraps lines already drawn.
function drawBlock(lines) {
  const shown = lines.map(fit);
  process.stdout.write(`${shown.join('\n')}\n`);
  return shown.map(visibleLength);
}

function clearBlock(widths = []) {
  const columnCount = width();
  const rows = widths.reduce((sum, size) => sum + Math.max(1, Math.ceil(size / columnCount)), 0);
  if (rows > 0) process.stdout.write(`${ESC}${rows}F${ESC}J`);
}

function attachLiveBlock(block) {
  liveBlock = block;
}

function detachLiveBlock(block) {
  if (liveBlock === block) liveBlock = null;
}

function blank() {
  print('');
}

function title(text, subtitle = '') {
  blank();
  print(`  ${paint.bold(text)}`);
  if (subtitle) paragraph(subtitle, { indent: 2, style: paint.muted });
}

function section(text) {
  blank();
  print(`  ${paint.bold(text)}`);
}

function itemLine(tone, label, detail = '', labelWidth = 0) {
  const { mark } = TONES[tone];
  const shownLabel = labelWidth ? padEnd(label, labelWidth) : label;
  const suffix = detail ? `  ${paint.muted(detail)}` : '';
  return `  ${paint.tone(tone, mark)} ${shownLabel}${suffix}`.trimEnd();
}

function item(tone, label, detail = '', labelWidth = 0) {
  print(itemLine(tone, label, detail, labelWidth));
}

// Prose that wraps to the window instead of being cut.
function paragraph(text, { indent = 2, style = (value) => value } = {}) {
  for (const line of wrap(text, width() - indent - 1)) print(`${' '.repeat(indent)}${style(line)}`);
}

function note(text) {
  paragraph(text, { style: paint.muted });
}

function keys(pairs) {
  const shown = pairs.map(([key, action]) => `${key} ${paint.faint(action)}`);
  print(`  ${shown.join(paint.faint('  ·  '))}`);
}

// Two columns side by side (the mascot and a greeting), or stacked when the
// window is too narrow for both.
function columns(left, right, gap = 3) {
  const leftWidth = Math.max(...left.map(visibleLength));
  const rightWidth = Math.max(...right.map(visibleLength));
  if (2 + leftWidth + gap + rightWidth >= width()) {
    if (2 + leftWidth < width()) {
      for (const line of left) print(`  ${line}`);
      blank();
    }
    for (const line of right) print(`  ${line}`);
    return;
  }
  const offset = Math.max(0, Math.floor((left.length - right.length) / 2));
  for (let index = 0; index < left.length; index += 1) {
    const rightText = right[index - offset] || '';
    print(`  ${padEnd(left[index], leftWidth)}${' '.repeat(gap)}${rightText}`.trimEnd());
  }
}

module.exports = {
  TONES,
  attachLiveBlock,
  background,
  blank,
  canRedraw,
  clearBlock,
  colorDepth,
  columns,
  configure,
  detachLiveBlock,
  drawBlock,
  foreground,
  isInteractive,
  isNarrow,
  item,
  itemLine,
  keys,
  note,
  padEnd,
  paint,
  paragraph,
  print,
  section,
  sgr,
  title,
  truncate,
  visibleLength,
  width,
};
