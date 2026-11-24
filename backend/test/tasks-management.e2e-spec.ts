import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { Prisma } from '../src/generated/prisma/client.js';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('Tasks management HTTP with fake database', () => {
  let app: INestApplication;
  const id = '850ca704-a7e5-437e-a206-0c42af3bf22d';
  const range = { start: '2040-01-02T00:00:00Z', end: '2040-01-03T00:00:00Z' };
  const content = {
    title: 'Updated',
    startAt: range.start,
    endAt: range.end,
    priority: 'high',
  };
  const saved = {
    id,
    title: 'Original',
    description: null,
    categoryId: null,
    startAt: new Date(range.start),
    endAt: new Date(range.end),
    priority: 'medium',
    status: 'completed',
    createdAt: new Date('2039-12-01T00:00:00Z'),
    version: 1,
    updatedAt: new Date('2040-01-01T00:00:00Z'),
  };
  const task = { findMany: vi.fn(), update: vi.fn(), delete: vi.fn() };
  const taskTombstone = { create: vi.fn() };
  const transaction = vi.fn(async (action) =>
    action({ task, taskTombstone, $executeRaw: vi.fn().mockResolvedValue(0) }),
  );

  beforeEach(async () => {
    for (const fn of Object.values(task)) fn.mockReset();
    taskTombstone.create.mockReset();
    transaction.mockClear();
    task.findMany.mockResolvedValue([saved]);
    task.update.mockImplementation(async ({ data }) => ({
      ...saved,
      ...data,
      version: saved.version + (data.version?.increment ?? 0),
      updatedAt: new Date('2040-01-02T01:00:00Z'),
    }));
    task.delete.mockResolvedValue(saved);
    const fixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ client: { task, $transaction: transaction } })
      .compile();
    app = fixture.createNestApplication();
    await app.init();
  });
  afterEach(async () => {
    await app.close();
  });

  it('returns the incremented version on content/status responses', async () => {
    const updated = await request(app.getHttpServer())
      .put('/tasks/' + id)
      .send(content)
      .expect(200);
    expect(updated.body.version).toBe(2);
    const status = await request(app.getHttpServer())
      .patch('/tasks/' + id + '/status')
      .send({ status: 'inProgress' })
      .expect(200);
    expect(status.body.version).toBe(2); // Each mock call starts from the version-1 fixture.
  });

  it('GET list returns 200 and sends filters to storage', async () => {
    const response = await request(app.getHttpServer())
      .get('/tasks')
      .query({
        ...range,
        status: 'completed',
        priority: 'medium',
        searchText: ' Original ',
      })
      .expect(200);
    expect(response.body[0].id).toBe(id);
    expect(task.findMany.mock.calls[0][0].where).toMatchObject({
      status: 'completed',
      priority: 'medium',
      title: { contains: 'Original' },
    });
  });

  it('empty list is 200 with []', async () => {
    task.findMany.mockResolvedValue([]);
    const response = await request(app.getHttpServer())
      .get('/tasks')
      .query(range)
      .expect(200);
    expect(response.body).toEqual([]);
  });

  it.each([
    {},
    { ...range, status: 'overdue' },
    { ...range, end: range.start },
    { ...range, extra: 'x' },
  ])(
    'invalid list query returns 400 before accessing database %j',
    async (query) => {
      await request(app.getHttpServer()).get('/tasks').query(query).expect(400);
      expect(task.findMany).not.toHaveBeenCalled();
    },
  );

  it('PUT updates content and preserves existing status/creation time', async () => {
    const response = await request(app.getHttpServer())
      .put('/tasks/' + id)
      .send(content)
      .expect(200);
    expect(response.body).toMatchObject({
      id,
      title: 'Updated',
      status: 'completed',
      priority: 'high',
      createdAt: saved.createdAt.toISOString(),
    });
    expect(task.update.mock.calls[0][0].data).not.toHaveProperty('status');
    expect(task.update.mock.calls[0][0].data).not.toHaveProperty('createdAt');
  });

  it.each([
    { ...content, title: ' ' },
    { ...content, status: 'pending' },
    { ...content, id },
  ])('invalid PUT returns 400 before storage %j', async (body) => {
    await request(app.getHttpServer())
      .put('/tasks/' + id)
      .send(body)
      .expect(400);
    expect(task.update).not.toHaveBeenCalled();
  });

  it.each(['pending', 'inProgress', 'completed'])(
    'PATCH accepts status %s',
    async (status) => {
      const response = await request(app.getHttpServer())
        .patch('/tasks/' + id + '/status')
        .send({ status })
        .expect(200);
      expect(response.body.status).toBe(status);
      expect(task.update.mock.calls[0][0].data).toEqual({
        status,
        version: { increment: 1 },
      });
    },
  );

  it.each([{}, { status: 'overdue' }, { status: 'completed', title: 'x' }])(
    'invalid PATCH returns 400 before storage %j',
    async (body) => {
      await request(app.getHttpServer())
        .patch('/tasks/' + id + '/status')
        .send(body)
        .expect(400);
      expect(task.update).not.toHaveBeenCalled();
    },
  );

  it('DELETE returns 204 and empty body', async () => {
    const response = await request(app.getHttpServer())
      .delete('/tasks/' + id)
      .expect(204);
    expect(response.text).toBe('');
    expect(task.delete).toHaveBeenCalledExactlyOnceWith({ where: { id } });
    expect(transaction).toHaveBeenCalledTimes(1);
    expect(taskTombstone.create).toHaveBeenCalledExactlyOnceWith({
      data: { taskId: id, version: 2 },
    });
  });

  it('returns safe 503 when the tombstone cannot be written', async () => {
    taskTombstone.create.mockRejectedValue(new Error('private tombstone SQL'));
    const response = await request(app.getHttpServer())
      .delete('/tasks/' + id)
      .expect(503);
    expect(response.body.message).toBe(
      'Chưa thể thay đổi công việc. Vui lòng thử lại sau.',
    );
    expect(response.text).not.toContain('private tombstone SQL');
  });

  it.each(['put', 'patch', 'delete'])(
    'invalid UUID returns 400 for %s',
    async (method) => {
      if (method === 'put')
        await request(app.getHttpServer())
          .put('/tasks/bad')
          .send(content)
          .expect(400);
      if (method === 'patch')
        await request(app.getHttpServer())
          .patch('/tasks/bad/status')
          .send({ status: 'pending' })
          .expect(400);
      if (method === 'delete')
        await request(app.getHttpServer()).delete('/tasks/bad').expect(400);
      expect(task.update).not.toHaveBeenCalled();
      expect(task.delete).not.toHaveBeenCalled();
    },
  );

  it.each(['put', 'patch', 'delete'])(
    'missing record returns 404 for %s',
    async (method) => {
      const error = new Prisma.PrismaClientKnownRequestError('missing', {
        code: 'P2025',
        clientVersion: '7.10.1',
      });
      task.update.mockRejectedValue(error);
      task.delete.mockRejectedValue(error);
      if (method === 'put')
        await request(app.getHttpServer())
          .put('/tasks/' + id)
          .send(content)
          .expect(404);
      if (method === 'patch')
        await request(app.getHttpServer())
          .patch('/tasks/' + id + '/status')
          .send({ status: 'pending' })
          .expect(404);
      if (method === 'delete')
        await request(app.getHttpServer())
          .delete('/tasks/' + id)
          .expect(404);
    },
  );

  it.each(['list', 'put', 'patch', 'delete'])(
    'storage error returns safe 503 for %s',
    async (method) => {
      for (const fn of Object.values(task))
        fn.mockRejectedValue(new Error('private SQL details'));
      let response;
      if (method === 'list')
        response = await request(app.getHttpServer())
          .get('/tasks')
          .query(range)
          .expect(503);
      if (method === 'put')
        response = await request(app.getHttpServer())
          .put('/tasks/' + id)
          .send(content)
          .expect(503);
      if (method === 'patch')
        response = await request(app.getHttpServer())
          .patch('/tasks/' + id + '/status')
          .send({ status: 'pending' })
          .expect(503);
      if (method === 'delete')
        response = await request(app.getHttpServer())
          .delete('/tasks/' + id)
          .expect(503);
      expect(JSON.stringify(response?.body)).not.toContain(
        'private SQL details',
      );
    },
  );
});
