'use strict';

const readline = require('readline');
const ui = require('./ui');

function cancelledError() {
  const error = new Error('Cancelled.');
  error.code = 'CLI_CANCELLED';
  return error;
}

function questionLine(message, suffix = '') {
  return `  ${ui.paint.accent('?')} ${ui.paint.bold(message)}${suffix ? ` ${ui.paint.muted(suffix)}` : ''}`;
}

// Raw keypresses for the duration of one prompt, restored afterwards.
function withKeypresses(onKey, { showCursor = false } = {}) {
  const input = process.stdin;
  const wasRaw = Boolean(input.isRaw);
  readline.emitKeypressEvents(input);
  input.setRawMode(true);
  input.resume();
  if (!showCursor) process.stdout.write('\x1b[?25l');
  return new Promise((resolve, reject) => {
    const done = (finish) => {
      input.removeListener('keypress', handler);
      input.setRawMode(wasRaw);
      input.pause();
      process.stdout.write('\x1b[?25h');
      finish();
    };
    const handler = (text, key = {}) => {
      if (key.ctrl && key.name === 'c') {
        done(() => reject(cancelledError()));
        return;
      }
      onKey(text, key, (value) => done(() => resolve(value)));
    };
    input.on('keypress', handler);
  });
}

function readLine(prompt) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// Arrow-key menu. Choices are { label, value, hint? }. With a cancelValue,
// q and escape leave the menu with it. Without a terminal the same choices
// become a numbered list read from stdin.
async function select(message, choices, { initial = 0, cancelValue } = {}) {
  const cancellable = cancelValue !== undefined;
  if (!ui.isInteractive()) {
    ui.print(questionLine(message));
    choices.forEach((choice, index) => {
      ui.print(`    ${index + 1}. ${choice.label}${choice.hint ? ` ${ui.paint.muted(`— ${choice.hint}`)}` : ''}`);
    });
    const answer = await readLine(`  Choose 1-${choices.length} [${initial + 1}]: `);
    const index = answer ? Number(answer) - 1 : initial;
    return (choices[index] || choices[initial]).value;
  }

  const labelWidth = Math.max(...choices.map((choice) => ui.visibleLength(choice.label))) + 3;
  let cursor = initial;
  let drawn = [];
  const render = () => {
    ui.clearBlock(drawn);
    // Hints share the line only when the window has room for them.
    const showHints = ui.width() >= labelWidth + 30;
    const lines = [questionLine(message), ''];
    choices.forEach((choice, index) => {
      const selected = index === cursor;
      const marker = selected ? ui.paint.accent('›') : ' ';
      const label = selected ? ui.paint.command(choice.label) : choice.label;
      const hint = showHints && choice.hint ? ui.paint.muted(choice.hint) : '';
      lines.push(`  ${marker} ${ui.padEnd(label, labelWidth)}${hint}`.trimEnd());
    });
    lines.push('');
    const footer = [`↑ ↓ ${ui.paint.muted('move')}`, `enter ${ui.paint.muted('choose')}`];
    if (cancellable) footer.push(`q ${ui.paint.muted('quit')}`);
    lines.push(`  ${footer.join(ui.paint.muted('  ·  '))}`);
    drawn = ui.drawBlock(lines);
  };
  process.stdout.on('resize', render);
  render();
  const value = await withKeypresses((text, key, resolve) => {
    if (key.name === 'up' || key.name === 'k') cursor = (cursor - 1 + choices.length) % choices.length;
    else if (key.name === 'down' || key.name === 'j') cursor = (cursor + 1) % choices.length;
    else if (/^[1-9]$/.test(text || '') && Number(text) <= choices.length) cursor = Number(text) - 1;
    else if (key.name === 'return') {
      resolve(choices[cursor].value);
      return;
    } else if (cancellable && (key.name === 'q' || key.name === 'escape')) {
      cursor = -1;
      resolve(cancelValue);
      return;
    } else return;
    render();
  });
  process.stdout.removeListener('resize', render);
  ui.clearBlock(drawn);
  if (cursor >= 0) ui.print(`${questionLine(message)} ${ui.paint.accent(choices[cursor].label)}`);
  return value;
}

async function confirm(message, { initial = true } = {}) {
  const suffix = initial ? '(Y/n)' : '(y/N)';
  if (!ui.isInteractive()) {
    const answer = (await readLine(`${questionLine(message, suffix)} `)).toLowerCase();
    return answer ? answer.startsWith('y') : initial;
  }
  process.stdout.write(`${questionLine(message, suffix)} `);
  const answer = await withKeypresses((text, key, resolve) => {
    if (key.name === 'return') resolve(initial);
    else if (key.name === 'y') resolve(true);
    else if (key.name === 'n' || key.name === 'escape') resolve(false);
  });
  process.stdout.write(`${answer ? ui.paint.accent('Yes') : 'No'}\n`);
  return answer;
}

async function ask(message, fallback = '') {
  const answer = await readLine(`${questionLine(message, fallback ? `[${fallback}]` : '')} `);
  return answer || fallback;
}

// Typed characters show as dots. Escape sequences (arrow keys) are ignored.
async function askSecret(message, currentValue = '') {
  const suffix = currentValue ? '[saved — enter keeps it]' : '';
  if (!ui.isInteractive() || typeof process.stdin.setRawMode !== 'function') {
    return (await readLine(`${questionLine(message, suffix)} `)) || currentValue;
  }
  process.stdout.write(`${questionLine(message, suffix)} `);
  let value = '';
  const result = await withKeypresses((text, key, resolve) => {
    if (key.name === 'return' || key.name === 'enter') {
      resolve(value || currentValue);
    } else if (key.name === 'backspace') {
      if (value) {
        value = value.slice(0, -1);
        process.stdout.write('\b \b');
      }
    } else if (key.ctrl && key.name === 'u') {
      process.stdout.write('\b \b'.repeat(value.length));
      value = '';
    } else if (text && !key.ctrl && !key.meta && text >= ' ' && !text.startsWith('\x1b')) {
      value += text;
      process.stdout.write('•'.repeat(text.length));
    }
  }, { showCursor: true });
  process.stdout.write('\n');
  return result;
}

// Waits for one of the given keys; resolves with its name.
async function waitForKey(names) {
  if (!ui.isInteractive()) return null;
  return withKeypresses((text, key, resolve) => {
    if (names.includes(key.name)) resolve(key.name);
  });
}

module.exports = {
  ask,
  askSecret,
  cancelledError,
  confirm,
  select,
  waitForKey,
};
