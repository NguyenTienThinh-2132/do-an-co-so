import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('POST /tasks with fake database', () => {
  let app: INestApplication;
  const create = vi.fn();
  const valid = {
    title: '  Viết báo cáo  ',
    startAt: '2026-11-07T09:00:00+07:00',
    endAt: '2026-11-07T10:00:00+07:00',
  };

  beforeEach(async () => {
    create.mockReset();
    create.mockImplementation(async ({ data }) => ({
      ...data,
      id: 'server-id',
      version: 1,
      createdAt: new Date('2026-11-06T10:00:00Z'),
      updatedAt: new Date('2026-11-06T10:00:00Z'),
    }));
    const fixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ client: { task: { create } } })
      .compile();
    app = fixture.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('returns 201 with normalized fields and server-managed properties', async () => {
    const response = await request(app.getHttpServer())
      .post('/tasks')
      .send(valid)
      .expect(201);
    expect(response.body).toMatchObject({
      id: 'server-id',
      title: 'Viết báo cáo',
      description: null,
      categoryId: null,
      startAt: '2026-11-07T02:00:00.000Z',
      endAt: '2026-11-07T03:00:00.000Z',
      priority: 'medium',
      status: 'pending',
      version: 1,
    });
    expect(create).toHaveBeenCalledOnce();
  });

  it.each([
    { title: '   ' },
    { endAt: valid.startAt },
    { startAt: '2026-11-07T09:00:00' },
    { priority: 'urgent' },
    { id: 'client-id' },
    { status: 'completed' },
    { version: 99 },
  ])('returns 400 and does not write for invalid input %j', async (changes) => {
    await request(app.getHttpServer())
      .post('/tasks')
      .send({ ...valid, ...changes })
      .expect(400);
    expect(create).not.toHaveBeenCalled();
  });

  it('returns 503 for database failure without leaking driver details', async () => {
    create.mockRejectedValue(new Error('private database details'));
    const response = await request(app.getHttpServer())
      .post('/tasks')
      .send(valid)
      .expect(503);
    expect(JSON.stringify(response.body)).not.toContain(
      'private database details',
    );
  });
});
