import 'reflect-metadata';
import { BadRequestException } from '@nestjs/common';
import {
  ListTasksValidationPipe,
  SetTaskStatusValidationPipe,
} from './tasks-management.pipes.js';

describe('Task management validation', () => {
  const listPipe = new ListTasksValidationPipe();
  const statusPipe = new SetTaskStatusValidationPipe();
  const range = { start: '2040-01-02T00:00:00Z', end: '2040-01-03T00:00:00Z' };
  const list = (query: unknown) => listPipe.transform(query, { type: 'query' });

  it('accepts range, trims search and keeps all filters', async () => {
    const query = await list({
      ...range,
      status: 'pending',
      priority: 'high',
      searchText: '  BÁO CÁO  ',
    });
    expect(query).toMatchObject({
      ...range,
      status: 'pending',
      priority: 'high',
      searchText: 'BÁO CÁO',
    });
  });

  it('defaults to no title/status/priority filter', async () => {
    const query = await list(range);
    expect(query.searchText).toBe('');
    expect(query.status).toBeUndefined();
    expect(query.priority).toBeUndefined();
  });

  it.each([
    {},
    { end: range.end },
    { start: range.start },
    { ...range, end: range.start },
    { ...range, start: range.end, end: range.start },
    { ...range, start: '2040-01-02T00:00:00' },
    { ...range, end: '2040-02-30T00:00:00Z' },
    { ...range, status: 'overdue' },
    { ...range, priority: 'urgent' },
    { ...range, searchText: 123 },
    { ...range, searchText: ['a', 'b'] },
    { ...range, start: [range.start, range.start] },
    { ...range, status: null },
    { ...range, priority: null },
    { ...range, unknown: 'x' },
  ])('rejects invalid query %j', async (query) => {
    await expect(list(query)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('compares query bounds as instants across timezones', async () => {
    await expect(
      list({ start: '2040-01-02T07:00:00+07:00', end: range.start }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it.each(['pending', 'inProgress', 'completed'])(
    'accepts status %s',
    async (status) => {
      expect(
        await statusPipe.transform({ status }, { type: 'body' }),
      ).toMatchObject({ status });
    },
  );

  it.each([
    {},
    { status: null },
    { status: 'overdue' },
    { status: 1 },
    { status: 'completed', title: 'x' },
    [],
    null,
  ])('rejects invalid status payload %j', async (payload) => {
    await expect(
      statusPipe.transform(payload, { type: 'body' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
