'use strict';

const ui = require('./ui');

const SPINNER = ['◐', '◓', '◑', '◒'];

function formatDuration(ms) {
  const seconds = Math.max(1, Math.round(ms / 1000));
  return seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}

// A checklist of what a command is doing, drawn in place while it runs:
//
//   ━━━━━━━━━━━━━━──────────  2 of 5
//   ✓ Saved a backup                      1s
//   ◐ Installing…  getting everything ready
//   ○ Restart NeoAgent
//
// A label is one phrase, or [while running, once done]. When every step
// succeeds the list folds away and the command prints its own one-line
// result; a failure leaves it up so the failed step stays visible. Without a
// terminal to redraw (logs, pipes) each step prints once it ends.
class StepList {
  constructor(labels, { bar = false } = {}) {
    this.steps = labels.map((label) => this.entry(label));
    this.bar = bar;
    this.drawn = [];
    this.frame = 0;
    this.timer = null;
    this.live = ui.canRedraw();
    this.onResize = () => this.redraw();
    if (this.live) {
      ui.attachLiveBlock(this);
      process.stdout.on('resize', this.onResize);
      this.draw();
    }
  }

  entry(label) {
    const [doing, done] = Array.isArray(label) ? label : [label, label];
    return { doing, done, state: 'pending', detail: '', startedAt: 0 };
  }

  add(label) {
    this.steps.push(this.entry(label));
    this.redraw();
    return this.steps.length - 1;
  }

  // The current step's detail; manager logs land here while a list is up.
  note(text) {
    const current = this.steps.find((step) => step.state === 'running');
    if (!current) return false;
    current.detail = String(text).replace(/\s+/g, ' ').trim();
    this.redraw();
    return true;
  }

  async run(index, task) {
    this.start(index);
    try {
      const result = await task();
      this.finish(index, 'ok');
      return result;
    } catch (error) {
      this.finish(index, 'error');
      throw error;
    }
  }

  start(index) {
    const step = this.steps[index];
    step.state = 'running';
    step.detail = '';
    step.startedAt = Date.now();
    if (this.live && !this.timer) {
      this.timer = setInterval(() => {
        this.frame = (this.frame + 1) % SPINNER.length;
        this.redraw();
      }, 120);
      this.timer.unref();
    }
    this.redraw();
  }

  finish(index, state) {
    const step = this.steps[index];
    step.state = state;
    step.detail = state === 'ok' ? formatDuration(Date.now() - step.startedAt) : '';
    if (!this.steps.some((entry) => entry.state === 'running')) this.stopTimer();
    if (this.live) this.redraw();
    else ui.print(this.lineFor(step));
  }

  close() {
    this.stopTimer();
    if (!this.live) return;
    if (this.steps.every((step) => step.state === 'ok')) this.clear();
    else this.redraw();
    ui.detachLiveBlock(this);
    process.stdout.removeListener('resize', this.onResize);
    this.live = false;
  }

  stopTimer() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  lineFor(step) {
    if (step.state === 'running') {
      const detail = step.detail ? `  ${ui.paint.muted(step.detail)}` : '';
      return `  ${ui.paint.accent(SPINNER[this.frame])} ${ui.paint.bold(`${step.doing}…`)}${detail}`;
    }
    if (step.state === 'ok') {
      // Durations line up on screen; in a log they follow the label directly.
      const width = this.live ? Math.min(40, ui.width() - 14) : 0;
      return ui.itemLine('ok', step.done, step.detail, width);
    }
    if (step.state === 'error') return ui.itemLine('error', step.doing);
    return `  ${ui.paint.faint(`○ ${step.doing}`)}`;
  }

  barLine() {
    const done = this.steps.filter((step) => step.state === 'ok').length;
    const size = Math.max(10, Math.min(32, ui.width() - 16));
    const filled = Math.round((done / this.steps.length) * size);
    return `  ${ui.paint.accent('━'.repeat(filled))}${ui.sgr(ui.foreground('unlit'), '━'.repeat(size - filled))}  `
      + ui.paint.faint(`${done} of ${this.steps.length}`);
  }

  draw() {
    const lines = this.steps.map((step) => this.lineFor(step));
    this.drawn = ui.drawBlock(this.bar ? [this.barLine(), '', ...lines] : lines);
  }

  clear() {
    ui.clearBlock(this.drawn);
    this.drawn = [];
  }

  redraw() {
    if (!this.live) return;
    this.clear();
    this.draw();
  }
}

let activeList = null;

function createStepList(labels, options) {
  activeList = new StepList(labels, options);
  return activeList;
}

function closeStepList(list) {
  list.close();
  if (activeList === list) activeList = null;
}

function noteActiveStep(text) {
  return Boolean(activeList?.note(text));
}

module.exports = {
  closeStepList,
  createStepList,
  formatDuration,
  noteActiveStep,
};
