(function iife() { const inner = 1; })();
if (process.env.X) {
  function insideIf() {}
}
export default async function named(): Promise<{ ok: boolean }> {
  const r = /\/\*not a comment/.test('x'); return { ok: r };
}
let a = 1, b = 2;
var fn = function () {
  return a
    + b;
};
const multi =
  'line one' +
  'line two';
function divide(x) { return x / 2 / 1; }
const ratio = a / b; const next = 3;
@decorator()
class Decorated {}
export type Mapped<T> = {
  [K in keyof T]: T[K];
};
interface Merge extends A, B<{ x: 1 }> { y: string }
const obj = {
  get value() { return 1 },
};
for (const item of [1]) { console.log(item); }
export async function last() {}
