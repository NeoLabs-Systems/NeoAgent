import type { Foo } from './foo';
export interface Shape {
  area(): number;
  nested: { a: string };
}
export type Id = string | number;
type Pair<T> = [T, T];
export enum Color { Red, Green = 'g' }
export const enum Flag { A = 1 }
export default function () {
  return 1;
}
export abstract class Base<T> implements Shape {
  abstract area(): number;
}
export const handler = async (req: Request): Promise<void> => {
  await fetch(req);
};
export function overload(a: string): string;
export function overload(a: any) { return a; }
declare function external(x: number): void;
export { Foo };
export * from './bar';
const arrow = (x: number) => x * 2
const second = 2;
let [first] = [1];
