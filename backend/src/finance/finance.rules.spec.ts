import { canonical, date, money, split } from './finance.rules.js';
describe('Finance rules', () => {
  it('rejects fractional, zero, negative and oversized money', () => {
    for (const n of ['0', '-1', '1.5', '1000000000000', 1])
      expect(() => money(n)).toThrow();
    expect(money('999999999999')).toBe(999999999999n);
  });
  it('requires an explicit timezone', () => {
    expect(() => date('2026-11-01T00:00:00')).toThrow();
    expect(date('2026-11-01T00:00:00+07:00').toISOString()).toBe(
      '2026-10-31T17:00:00.000Z',
    );
  });
  it('preserves every dong and resolves ties by ID', () => {
    const jars = [
      { id: 'c', allocationBps: 3334 },
      { id: 'b', allocationBps: 3333 },
      { id: 'a', allocationBps: 3333 },
    ];
    for (const value of [1n, 2n, 999999999999n])
      expect([...split(value, jars).values()].reduce((s, n) => s + n, 0n)).toBe(
        value,
      );
    expect(split(2n, jars).get('a')).toBe(1n);
  });
  it('canonicalizes nested request objects', () => {
    expect(canonical({ z: { b: 2, a: 1 }, a: 0 })).toBe(
      canonical({ a: 0, z: { a: 1, b: 2 } }),
    );
  });
});
