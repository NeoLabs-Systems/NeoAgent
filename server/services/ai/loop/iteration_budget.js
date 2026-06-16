'use strict';

class IterationBudget {
  constructor(maxTotal) {
    this.maxTotal = Math.max(0, Number(maxTotal) || 0);
    this.used = 0;
  }

  consume() {
    if (this.used >= this.maxTotal) return false;
    this.used += 1;
    return true;
  }

  refund() {
    if (this.used > 0) this.used -= 1;
  }

  get remaining() {
    return Math.max(0, this.maxTotal - this.used);
  }
}

module.exports = { IterationBudget };
