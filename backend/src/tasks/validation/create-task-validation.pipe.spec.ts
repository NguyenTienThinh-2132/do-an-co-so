import 'reflect-metadata';
import { BadRequestException } from '@nestjs/common';
import { CreateTaskDto } from '../dto/create-task.dto.js';
import { CreateTaskValidationPipe } from './create-task-validation.pipe.js';

describe('CreateTaskDto through validation pipe', () => {
  const pipe = new CreateTaskValidationPipe();
  const valid = {
    title: 'Viết báo cáo',
    startAt: '2026-11-07T02:00:00.000Z',
    endAt: '2026-11-07T03:00:00.000Z',
  };
  const parse = (body: unknown) => pipe.transform(body, { type: 'body' });

  it('trims title, creates DTO and defaults priority without mutating input', async () => {
    const input = { ...valid, title: '  Viết báo cáo  ' };
    const dto = await parse(input);
    expect(dto).toBeInstanceOf(CreateTaskDto);
    expect(dto.title).toBe('Viết báo cáo');
    expect(dto.priority).toBe('medium');
    expect(dto.description).toBeUndefined();
    expect(dto.categoryId).toBeUndefined();
    expect(input.title).toBe('  Viết báo cáo  ');
  });

  it.each(['low', 'medium', 'high'])(
    'accepts priority %s',
    async (priority) => {
      const dto = await parse({ ...valid, priority });
      expect(dto.priority).toBe(priority);
    },
  );

  it('accepts optional text and null fields', async () => {
    const text = await parse({
      ...valid,
      description: 'Báo cáo TV3',
      categoryId: 'study',
    });
    expect(text.description).toBe('Báo cáo TV3');
    expect(text.categoryId).toBe('study');
    const nullable = await parse({
      ...valid,
      description: null,
      categoryId: null,
    });
    expect(nullable.description).toBeNull();
    expect(nullable.categoryId).toBeNull();
  });

  it.each(['', ' \t\n ', 123, null, {}, []])(
    'rejects invalid title %j',
    async (title) => {
      await expect(parse({ ...valid, title })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    },
  );

  it.each(['title', 'startAt', 'endAt'])('requires %s', async (field) => {
    const input: Record<string, unknown> = { ...valid };
    delete input[field];
    await expect(parse(input)).rejects.toBeInstanceOf(BadRequestException);
  });

  it.each(['urgent', 'HIGH', '', null, 1])(
    'rejects invalid priority %j',
    async (priority) => {
      await expect(parse({ ...valid, priority })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    },
  );

  it.each(['description', 'categoryId'])(
    'does not coerce %s to text',
    async (field) => {
      for (const value of [123, false, {}, []]) {
        await expect(
          parse({ ...valid, [field]: value }),
        ).rejects.toBeInstanceOf(BadRequestException);
      }
    },
  );

  it.each(['id', 'status', 'createdAt', 'updatedAt', 'extra'])(
    'rejects extra field %s',
    async (field) => {
      await expect(
        parse({ ...valid, [field]: 'client value' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    },
  );

  it.each(['startAt', 'endAt'])(
    'validates ISO time and timezone for %s',
    async (field) => {
      for (const value of [
        '2026-11-07T02:30:00',
        '2026-11-07',
        '2026-02-30T02:30:00Z',
        'not-a-date',
        '2026-11-07T02:30:00+25:00',
        123,
        null,
      ]) {
        await expect(
          parse({ ...valid, [field]: value }),
        ).rejects.toBeInstanceOf(BadRequestException);
      }
    },
  );

  it('rejects equal and reversed instants, including different timezone offsets', async () => {
    for (const endAt of [
      valid.startAt,
      '2026-11-07T01:00:00Z',
      '2026-11-07T09:00:00+07:00',
    ]) {
      await expect(parse({ ...valid, endAt })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    }
  });

  it('compares absolute instants rather than clock text', async () => {
    const dto = await parse({
      ...valid,
      startAt: '2026-11-07T09:00:00+07:00',
      endAt: '2026-11-07T02:30:00Z',
    });
    expect(dto.endAt).toBe('2026-11-07T02:30:00Z');
  });

  it.each([null, undefined, [], [valid], 'text', 123, false])(
    'rejects a non-object body %j',
    async (body) => {
      await expect(parse(body)).rejects.toBeInstanceOf(BadRequestException);
    },
  );

  it('returns HTTP 400 and does not echo invalid values', async () => {
    try {
      await parse({ ...valid, priority: 'private-invalid-input' });
      throw new Error('Expected validation error');
    } catch (error) {
      expect(error).toBeInstanceOf(BadRequestException);
      const failure = error as BadRequestException;
      expect(failure.getStatus()).toBe(400);
      expect(JSON.stringify(failure.getResponse())).not.toContain(
        'private-invalid-input',
      );
    }
  });
});
