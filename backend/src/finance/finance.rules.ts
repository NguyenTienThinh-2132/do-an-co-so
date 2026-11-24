import { BadRequestException } from '@nestjs/common';

export const categories = [
  'food',
  'transport',
  'shopping',
  'education',
  'housing',
  'other',
];
export const styles = [
  'home',
  'savings',
  'education',
  'enjoyment',
  'investment',
  'giving',
  'target',
];
export function text(value: unknown, max: number, label: string): string {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max)
    throw new BadRequestException(`${label} không hợp lệ.`);
  return value.trim().replace(/\s+/g, ' ');
}
export function money(value: unknown): bigint {
  if (typeof value !== 'string' || !/^[1-9]\d{0,11}$/.test(value))
    throw new BadRequestException(
      'Số tiền phải là số nguyên VND từ 1 đến 999999999999.',
    );
  return BigInt(value);
}
export function date(value: unknown): Date {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value) ||
    !Number.isFinite(Date.parse(value))
  )
    throw new BadRequestException('Thời gian cần ISO 8601 có múi giờ.');
  return new Date(value);
}
export function uuid(value: unknown): string {
  if (
    typeof value !== 'string' ||
    !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(value)
  )
    throw new BadRequestException('ID không hợp lệ.');
  return value;
}
export function revision(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0)
    throw new BadRequestException('Phiên bản dữ liệu không hợp lệ.');
  return value as number;
}
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object')
    return (
      '{' +
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([k, v]) => JSON.stringify(k) + ':' + canonical(v))
        .join(',') +
      '}'
    );
  return JSON.stringify(value);
}
export function split(
  amount: bigint,
  jars: { id: string; allocationBps: number }[],
) {
  if (
    jars.length === 0 ||
    jars.reduce((s, j) => s + j.allocationBps, 0) !== 10000
  )
    throw new BadRequestException('Tổng tỷ lệ phải bằng 100%.');
  const result = new Map(
    jars.map((j) => [j.id, (amount * BigInt(j.allocationBps)) / 10000n]),
  );
  const sorted = [...jars].sort((a, b) => {
    const d =
      ((amount * BigInt(b.allocationBps)) % 10000n) -
      ((amount * BigInt(a.allocationBps)) % 10000n);
    return d === 0n ? a.id.localeCompare(b.id) : d > 0n ? 1 : -1;
  });
  const remainder = Number(
    amount - [...result.values()].reduce((s, v) => s + v, 0n),
  );
  for (let i = 0; i < remainder; i++)
    result.set(sorted[i].id, result.get(sorted[i].id)! + 1n);
  return result;
}
