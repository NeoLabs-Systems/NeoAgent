'use strict';
// A comment with function inside: function fake() {}
const { x } = require('x');
const answer = 42;
let template = `value ${ { a: 1 }.a } and } brace`;
var re = /}\/{/g, other = 1
function plain(a, b = { c: 1 }) {
  if (a) { return "}"; }
  return b;
}
async function* gen() { yield 1; }
class Animal extends Base {
  constructor() { super(); this.s = '{'; }
  speak() { return `${this.s}}`; }
}
/* block } comment */
module.exports = { plain, Animal };
