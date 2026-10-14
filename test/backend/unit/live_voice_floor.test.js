'use strict';

const assert = require('node:assert/strict');
const { mock, test } = require('node:test');

const { LiveFloor, QUIET_LINE_MS } = require('../../../server/services/voice/live/floor');

function connectedFloor() {
  const floor = new LiveFloor();
  floor.setConnected(true);
  return floor;
}

// The model answers in one spoken turn.
function modelAnswers(floor) {
  floor.modelSpeaking(Date.now());
  floor.modelSilent();
  floor.turnEnded();
}

test('deliveries wait for a free line and go out in order', () => {
  const floor = new LiveFloor();
  const delivered = [];
  floor.whenFree(() => delivered.push('while connecting'));
  assert.deepEqual(delivered, []);
  floor.setConnected(true);
  assert.deepEqual(delivered, ['while connecting']);

  floor.modelSpeaking(Date.now());
  floor.whenFree(() => delivered.push('a'));
  floor.whenFree(() => delivered.push('b'));
  assert.deepEqual(delivered, ['while connecting']);
  floor.modelSilent();
  assert.deepEqual(delivered, ['while connecting', 'a', 'b']);

  floor.setInputHeld(true);
  floor.whenFree(() => delivered.push('after push-to-talk'));
  floor.setInputHeld(false);
  // Releasing push-to-talk hands the turn to the model, which answers first.
  assert.equal(delivered.length, 3);
  modelAnswers(floor);
  assert.equal(delivered.at(-1), 'after push-to-talk');
});

test('the model answers each tool result and told message before the next delivery', () => {
  const floor = connectedFloor();
  const delivered = [];
  // Two tool calls in a row, as when the model corrects its own hand-off.
  floor.ownerSpoke();
  floor.expectReply();
  floor.expectReply();
  floor.whenFree(() => delivered.push('outcome'));
  // Gemini ends the turn of a tool call before it speaks; that settles nothing.
  floor.turnEnded();
  modelAnswers(floor);
  assert.deepEqual(delivered, []);
  modelAnswers(floor);
  assert.deepEqual(delivered, ['outcome']);
});

test('a delivery that makes the model speak holds the next until it is answered', () => {
  const floor = connectedFloor();
  const delivered = [];
  floor.whenFree(() => {
    delivered.push('outcome');
    floor.expectReply();
  });
  floor.whenFree(() => delivered.push('next'));
  assert.deepEqual(delivered, ['outcome']);
  modelAnswers(floor);
  assert.deepEqual(delivered, ['outcome', 'next']);
});

test('speech cut off by the owner answers nothing', () => {
  const floor = connectedFloor();
  const delivered = [];
  floor.ownerSpoke();
  floor.modelSpeaking(Date.now());
  floor.ownerInterrupted();
  floor.whenFree(() => delivered.push('outcome'));
  // The interrupted turn ends, and the speech the owner stopped plays out.
  floor.turnEnded();
  floor.droppedSpeech();
  floor.modelSilent();
  assert.deepEqual(delivered, []);
  modelAnswers(floor);
  assert.deepEqual(delivered, ['outcome']);
});

test('a model that keeps working after its turn holds the line until idle', () => {
  const floor = connectedFloor();
  const delivered = [];
  floor.modelWorking();
  floor.whenFree(() => delivered.push('outcome'));
  modelAnswers(floor);
  assert.deepEqual(delivered, []);
  floor.modelIdle();
  assert.deepEqual(delivered, ['outcome']);
});

test('an unanswered turn or a lost connection stops holding the line', (t) => {
  mock.timers.enable({ apis: ['setTimeout'] });
  t.after(() => mock.timers.reset());
  const floor = connectedFloor();
  const delivered = [];
  floor.ownerSpoke();
  floor.expectReply();
  floor.whenFree(() => delivered.push('after silence'));
  mock.timers.tick(5999);
  assert.deepEqual(delivered, []);
  mock.timers.tick(1);
  assert.deepEqual(delivered, ['after silence']);

  // The connection drops mid-sentence; the speech timer that would have
  // ended it goes with the connection.
  floor.modelSpeaking(Date.now());
  floor.modelWorking();
  floor.expectReply();
  floor.whenFree(() => delivered.push('after reconnect'));
  floor.setConnected(false);
  floor.setConnected(true);
  assert.deepEqual(delivered, ['after silence', 'after reconnect']);
});

test('the line is quiet once nobody has spoken for a while, counted from the end of playback', (t) => {
  mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  t.after(() => mock.timers.reset());
  const floor = connectedFloor();
  assert.equal(floor.quiet, true);
  // Five seconds of speech arrive at once and play on after the last chunk.
  floor.modelSpeaking(Date.now() + 5000);
  floor.modelSilent();
  assert.equal(floor.free, true);
  mock.timers.tick(QUIET_LINE_MS);
  assert.equal(floor.quiet, false);
  mock.timers.tick(5000);
  assert.equal(floor.quiet, true);
  floor.setInputHeld(true);
  assert.equal(floor.quiet, false);
});
