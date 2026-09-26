'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { buildStep, runBrowserAct } = require('../../../server/services/ai/integrated_tools/browser_act');
const { buildSnapshotScript } = require('../../../server/services/ai/integrated_tools/browser_act_page');

const SEARCH_PAGE = {
  url: 'https://example.test/',
  title: 'Search',
  text: 'Find anything',
  canScrollUp: false,
  canScrollDown: true,
  viewportHeight: 800,
  elements: [
    { i: 1, role: 'searchbox', name: 'Search', ops: ['TYPE_TEXT'], value: '' },
    { i: 2, role: 'button', name: 'Go', ops: ['CLICK'] },
    { i: 3, role: 'select', name: 'Language', ops: ['SELECT'], value: 'English', options: ['English', 'Deutsch'] },
    { i: 4, role: 'textbox', name: 'Password', ops: [], sensitive: true },
  ],
};

function page(overrides = {}) {
  return JSON.parse(JSON.stringify({ ...SEARCH_PAGE, ...overrides }));
}

// A browser whose page is replaced by each scripted snapshot in turn.
function fakeProvider(snapshots, calls) {
  let index = 0;
  return {
    async evaluate(script) {
      calls.push({ method: 'evaluate', script });
      if (script.includes('HTMLSelectElement')) return { result: JSON.stringify({ success: true }) };
      const snapshot = snapshots[Math.min(index, snapshots.length - 1)];
      index += 1;
      return { result: JSON.stringify(snapshot) };
    },
    async click(selector) {
      calls.push({ method: 'click', selector });
      return { success: true };
    },
    async type(selector, text, options) {
      calls.push({ method: 'type', selector, text, options });
      return { success: true };
    },
    async pressKey(key) {
      calls.push({ method: 'pressKey', key });
      return { success: true };
    },
    async scroll(dx, dy) {
      calls.push({ method: 'scroll', dy });
      return { success: true };
    },
    async navigate(url) {
      calls.push({ method: 'navigate', url });
      return { url };
    },
  };
}

function choice(picked) {
  return { type: 'choice', choice: picked, confidence: 0.9, probabilities: { [picked]: 0.95 } };
}

// Jev answers scripted one step at a time; the text helper returns `text`.
function fakeEngine(steps, text = 'weather zurich') {
  const decided = [];
  return {
    decided,
    async decide({ questions }) {
      decided.push(questions);
      return steps.shift() || null;
    },
    async inferStructured() {
      return { parsed: { text } };
    },
  };
}

test('one decision offers only operations the page supports, with a target question for each', () => {
  const step = buildStep('Search for the weather', page(), []);
  assert.deepEqual(
    Object.keys(step.questions.operation.criteria),
    ['CLICK', 'TYPE_TEXT', 'SELECT', 'SCROLL_DOWN', 'WAIT', 'DONE', 'BLOCKED'],
  );
  assert.deepEqual(Object.keys(step.questions.click_target.criteria), ['2']);
  assert.deepEqual(Object.keys(step.questions.type_text_target.criteria), ['1']);
  assert.deepEqual(Object.keys(step.questions.select_target.criteria), ['3:0', '3:1']);
  assert.equal(step.state.elements.find((element) => element.i === 4).sensitive, true);

  const focused = page();
  focused.elements[0].focused = true;
  assert.ok(buildStep('Search', focused, []).questions.operation.criteria.PRESS_ENTER);
});

test('the page script stays under the browser evaluate limit', () => {
  assert.ok(buildSnapshotScript('abcd1234').length < 10000);
});

test('Jev types the query, submits it, and stops when the goal is visibly done', async () => {
  const typed = page({ elements: SEARCH_PAGE.elements.map((element) => (
    element.i === 1 ? { ...element, value: 'weather zurich', focused: true } : element
  )) });
  const results = page({ url: 'https://example.test/?q=weather+zurich', title: 'Results', text: 'Zurich: sunny, 24°C' });
  const calls = [];
  const engine = fakeEngine([
    { operation: choice('TYPE_TEXT'), type_text_target: choice('1') },
    { operation: choice('PRESS_ENTER') },
    { operation: choice('DONE') },
  ]);

  const result = await runBrowserAct({
    provider: fakeProvider([page(), typed, results], calls),
    engine,
    goal: 'Search for the weather in Zurich',
    userId: 1,
  });

  assert.equal(result.status, 'done');
  assert.deepEqual(result.actions, [
    'type "weather zurich" into [1] searchbox "Search"',
    'press enter',
  ]);
  assert.equal(result.url, 'https://example.test/?q=weather+zurich');
  assert.equal(result.visible_text, 'Zurich: sunny, 24°C');
  const typeCall = calls.find((call) => call.method === 'type');
  assert.match(typeCall.selector, /^\[data-neo-act="[0-9a-f]{8}-1"\]$/);
  assert.equal(typeCall.options.screenshot, false);
  assert.ok(calls.some((call) => call.method === 'pressKey' && call.key === 'Enter'));
});

test('a value the goal does not give ends the run and names the field', async () => {
  const result = await runBrowserAct({
    provider: fakeProvider([page()], []),
    engine: {
      async decide() {
        return { operation: choice('TYPE_TEXT'), type_text_target: choice('1') };
      },
      async inferStructured() {
        return { parsed: { text: null } };
      },
    },
    goal: 'Log in',
    userId: 1,
  });
  assert.equal(result.status, 'needs_input');
  assert.match(result.missing_value, /"Search"/);
});

test('steps that leave the page unchanged stop the run', async () => {
  const calls = [];
  const result = await runBrowserAct({
    provider: fakeProvider([page()], calls),
    engine: fakeEngine([
      { operation: choice('CLICK'), click_target: choice('2') },
      { operation: choice('CLICK'), click_target: choice('2') },
      { operation: choice('CLICK'), click_target: choice('2') },
      { operation: choice('CLICK'), click_target: choice('2') },
    ]),
    goal: 'Press go',
    userId: 1,
  });
  assert.equal(result.status, 'stalled');
  assert.equal(calls.filter((call) => call.method === 'click').length, 3);
  assert.ok(result.actions.every((action) => action.endsWith('(page did not change)')));
});

test('retyping what a field already holds is not sent to the browser', async () => {
  const filled = page({ elements: SEARCH_PAGE.elements.map((element) => (
    element.i === 1 ? { ...element, value: 'weather zurich' } : element
  )) });
  const calls = [];
  const retype = { operation: choice('TYPE_TEXT'), type_text_target: choice('1') };
  const result = await runBrowserAct({
    provider: fakeProvider([filled], calls),
    engine: fakeEngine([retype, retype, retype]),
    goal: 'Search for the weather in Zurich',
    userId: 1,
  });
  assert.equal(result.status, 'stalled');
  assert.equal(calls.filter((call) => call.method === 'type').length, 0);
});

test('a target replaced after the snapshot is looked up again instead of failing', async () => {
  const calls = [];
  const provider = fakeProvider([page(), page(), page({ title: 'Done' })], calls);
  let clicks = 0;
  provider.click = async (selector) => {
    calls.push({ method: 'click', selector });
    clicks += 1;
    return clicks === 1 ? { error: `Element not found: ${selector}` } : { success: true };
  };
  const result = await runBrowserAct({
    provider,
    engine: fakeEngine([
      { operation: choice('CLICK'), click_target: choice('2') },
      { operation: choice('CLICK'), click_target: choice('2') },
      { operation: choice('DONE') },
    ]),
    goal: 'Press go',
    userId: 1,
  });
  assert.equal(result.status, 'done');
  assert.deepEqual(result.actions, ['click [2] button "Go"']);
});

test('without a Jev answer the run hands control back to the model', async () => {
  const result = await runBrowserAct({
    provider: fakeProvider([page()], []),
    engine: fakeEngine([]),
    goal: 'Search',
    userId: 1,
  });
  assert.equal(result.status, 'jev_unavailable');
  assert.deepEqual(result.actions, []);
});

test('native selects are set through the page, and the goal URL is opened first', async () => {
  const calls = [];
  const result = await runBrowserAct({
    provider: fakeProvider([page(), page({ title: 'Deutsch' })], calls),
    engine: fakeEngine([
      { operation: choice('SELECT'), select_target: choice('3:1') },
      { operation: choice('DONE') },
    ]),
    goal: 'Switch the language to Deutsch',
    url: 'https://example.test/',
    userId: 1,
  });
  assert.equal(result.status, 'done');
  assert.equal(calls[0].method, 'navigate');
  assert.deepEqual(result.actions, ['select "Deutsch" in [3] select "Language"']);
  assert.ok(calls.some((call) => call.method === 'evaluate' && call.script.includes('HTMLSelectElement')));
});
