'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { DATA_DIR } = require('../runtime/paths');

const HOUR_MS = 60 * 60 * 1000;
const SAMPLE_MS = 5 * 60 * 1000;
const HOURS = 48;
const severity = { operational: 0, degraded: 1, unavailable: 2 };

function createStatusHistory({ directory = DATA_DIR, clock = Date.now } = {}) {
  const filename = path.join(directory, 'public-status-history.json');
  function read() {
    try {
      const value = JSON.parse(fs.readFileSync(filename, 'utf8'));
      return Array.isArray(value) ? value.filter((item) => Number.isFinite(item.time) && Object.hasOwn(severity, item.status)) : [];
    } catch { return []; }
  }
  function history() {
    const current = Math.floor(clock() / HOUR_MS) * HOUR_MS;
    const byHour = new Map(read().map((item) => [item.time, item.status]));
    return Array.from({ length: HOURS }, (_, index) => {
      const time = current - (HOURS - 1 - index) * HOUR_MS;
      return { time: new Date(time).toISOString(), status: byHour.get(time) || null };
    });
  }
  function record(status) {
    if (!Object.hasOwn(severity, status)) return;
    const current = Math.floor(clock() / HOUR_MS) * HOUR_MS;
    const entries = read().filter((item) => item.time > current - HOURS * HOUR_MS && item.time <= current);
    const previous = entries.find((item) => item.time === current);
    if (previous) {
      if (severity[status] > severity[previous.status]) previous.status = status;
    } else entries.push({ time: current, status });
    try {
      fs.mkdirSync(directory, { recursive: true });
      const temporary = `${filename}.${process.pid}.tmp`;
      fs.writeFileSync(temporary, JSON.stringify(entries), { mode: 0o600 });
      fs.renameSync(temporary, filename);
    } catch { /* A status history write must not disrupt the server. */ }
  }
  function start(sample, server) {
    let running = false;
    async function collect() {
      if (running) return;
      running = true;
      try { record((await sample()).status); } catch { /* Missing samples stay unknown. */ }
      finally { running = false; }
    }
    const initial = setTimeout(collect, 15000);
    const timer = setInterval(collect, SAMPLE_MS);
    initial.unref(); timer.unref();
    server.once('close', () => { clearTimeout(initial); clearInterval(timer); });
  }
  return { history, record, start };
}

module.exports = { createStatusHistory };
