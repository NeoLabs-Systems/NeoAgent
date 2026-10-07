'use strict';

// Who has the line in a live call. What the server puts on it (a task's
// outcome, a progress update, context) must not cut into the owner's sentence
// or the model's answer: Gemini drops the answer it is generating when a new
// turn arrives. Deliveries wait for a free line, and a progress update is only
// spoken into a line that has been quiet for a while.
const QUIET_LINE_MS = 6000;
// Replies the model owes but does not give (it may stay silent, or answer two
// things in one turn) stop holding the line after this long.
const REPLY_TIMEOUT_MS = 6000;
// Thinking and tool calls between a turn marked in progress and the idle one.
const WORKING_TIMEOUT_MS = 30 * 1000;

class LiveFloor {
  constructor() {
    this.held = [];
    this.connected = false;
    this.speaking = false;
    this.inputHeld = false;
    // The owner said something the model has not answered yet.
    this.ownerWaiting = false;
    // Tool results and told messages the model answers, a turn each.
    this.repliesDue = 0;
    this.spokeThisTurn = false;
    this.working = false;
    this.lastSpeechAt = 0;
    this.replyTimer = null;
    this.workingTimer = null;
  }

  get free() {
    return this.connected
      && !this.speaking
      && !this.inputHeld
      && !this.ownerWaiting
      && this.repliesDue === 0
      && !this.working;
  }

  // Nobody has said anything for a while: an update fills a silence instead
  // of interrupting a conversation.
  get quiet() {
    return this.free && Date.now() - this.lastSpeechAt >= QUIET_LINE_MS;
  }

  whenFree(deliver) {
    this.held.push(deliver);
    this.#release();
  }

  // A dropped connection ends whatever the model was saying or doing; the
  // next one starts with nothing pending.
  setConnected(connected) {
    this.connected = connected;
    if (!connected) {
      this.speaking = false;
      this.spokeThisTurn = false;
      this.#settleReplies();
      this.#settleWorking();
    }
    this.#release();
  }

  // The model's audio arrives faster than it plays; the owner hears it until
  // playbackEndsAt.
  modelSpeaking(playbackEndsAt) {
    this.speaking = true;
    this.spokeThisTurn = true;
    this.lastSpeechAt = Math.max(Date.now(), playbackEndsAt);
  }

  // Speech the owner stopped is dropped, but it holds the line until it ends
  // and answers nothing.
  droppedSpeech() {
    this.speaking = true;
  }

  modelSilent() {
    this.speaking = false;
    if (this.ownerWaiting || this.repliesDue) this.#armReplyTimeout();
    this.#release();
  }

  // Push-to-talk marks the owner's turn; hands-free speech shows up as their
  // transcript.
  setInputHeld(held) {
    this.inputHeld = held;
    this.lastSpeechAt = Date.now();
    if (!held) this.ownerSpoke();
    this.#release();
  }

  ownerSpoke() {
    this.lastSpeechAt = Date.now();
    this.ownerWaiting = true;
    this.#armReplyTimeout();
  }

  // The owner talked over the model: what it said so far answers nothing.
  ownerInterrupted() {
    this.speaking = false;
    this.spokeThisTurn = false;
    this.ownerSpoke();
  }

  // The model was handed something it answers in a turn of its own: a tool
  // result, or a delivery it is told to speak.
  expectReply() {
    this.repliesDue += 1;
    this.#armReplyTimeout();
  }

  // A turn the model spoke in answers the owner and one thing it owed. Gemini
  // ends the turn of a tool call before it speaks, which settles nothing.
  turnEnded() {
    if (this.spokeThisTurn) {
      this.spokeThisTurn = false;
      this.ownerWaiting = false;
      this.repliesDue = Math.max(0, this.repliesDue - 1);
    }
    this.#release();
  }

  // Gemini's extended-thinking models end turns while they go on thinking or
  // calling tools; the line stays theirs until they report idle.
  modelWorking() {
    this.working = true;
    clearTimeout(this.workingTimer);
    this.workingTimer = setTimeout(() => this.modelIdle(), WORKING_TIMEOUT_MS);
    this.workingTimer.unref?.();
  }

  modelIdle() {
    this.#settleWorking();
    this.#release();
  }

  close() {
    this.held = [];
    this.connected = false;
    this.#settleReplies();
    this.#settleWorking();
  }

  #armReplyTimeout() {
    clearTimeout(this.replyTimer);
    this.replyTimer = setTimeout(() => {
      this.#settleReplies();
      this.#release();
    }, REPLY_TIMEOUT_MS);
    this.replyTimer.unref?.();
  }

  #settleReplies() {
    this.ownerWaiting = false;
    this.repliesDue = 0;
    clearTimeout(this.replyTimer);
  }

  #settleWorking() {
    this.working = false;
    clearTimeout(this.workingTimer);
  }

  // A delivery that makes the model speak calls expectReply, so the next one
  // waits for that answer.
  #release() {
    while (this.held.length && this.free) this.held.shift()();
  }
}

module.exports = {
  LiveFloor,
  QUIET_LINE_MS,
};
