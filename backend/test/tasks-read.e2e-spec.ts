import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('GET /tasks/:taskId with fake database', () => {
  let app: INestApplication;
  const findUnique = vi.fn();
  const id = '850ca704-a7e5-437e-a206-0c42af3bf22d';
  const saved = {
    id,
    title: 'Viết báo cáo',
    description: null,
    categoryId: null,
    startAt: new Date('2026-11-07T02:00:00Z'),
    endAt: new Date('2026-11-07T03:00:00Z'),
    priority: 'medium',
    status: 'pending',
    createdAt: new Date('2026-11-06T10:00:00Z'),
    version: 1,
    updatedAt: new Date('2026-11-06T10:00:00Z'),
  };

  beforeEach(async () => {
    findUnique.mockReset();
    findUnique.mockResolvedValue(saved);
    const fixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ client: { task: { findUnique } } })
      .compile();
    app = fixture.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('returns 200 with saved fields and ISO UTC timestamps', async () => {
    const response = await request(app.getHttpServer())
      .get('/tasks/' + id)
      .expect(200);
    expect(response.body).toEqual({
      ...saved,
      startAt: saved.startAt.toISOString(),
      endAt: saved.endAt.toISOString(),
      createdAt: saved.createdAt.toISOString(),
      updatedAt: saved.updatedAt.toISOString(),
    });
    expect(findUnique).toHaveBeenCalledExactlyOnceWith({ where: { id } });
  });

  it.each(['not-a-uuid', '123', 'new'])(
    'rejects malformed ID %s before querying',
    async (invalidId) => {
      await request(app.getHttpServer())
        .get('/tasks/' + invalidId)
        .expect(400);
      expect(findUnique).not.toHaveBeenCalled();
    },
  );

  it('returns 404 when the UUID is valid but record does not exist', async () => {
    findUnique.mockResolvedValue(null);
    await request(app.getHttpServer())
      .get('/tasks/' + id)
      .expect(404);
    expect(findUnique).toHaveBeenCalledOnce();
  });

  it('returns 503 on storage failure without leaking raw errors', async () => {
    findUnique.mockRejectedValue(new Error('private database details'));
    const response = await request(app.getHttpServer())
      .get('/tasks/' + id)
      .expect(503);
    expect(JSON.stringify(response.body)).not.toContain(
      'private database details',
    );
  });
});
