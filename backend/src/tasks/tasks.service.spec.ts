import { ServiceUnavailableException } from '@nestjs/common';
import type { PrismaService } from '../prisma/prisma.service.js';
import { CreateTaskDto } from './dto/create-task.dto.js';
import { TasksService } from './tasks.service.js';

describe('TasksService.create', () => {
  const dto = Object.assign(new CreateTaskDto(), {
    title: 'Viết báo cáo',
    startAt: '2026-11-07T09:00:00+07:00',
    endAt: '2026-11-07T03:00:00Z',
  });

  function setup() {
    const create = vi.fn();
    const prisma = { client: { task: { create } } };
    const service = new TasksService(prisma as unknown as PrismaService);
    return { create, service };
  }

  it('maps approved input fields and lets Prisma generate ID/timestamps', async () => {
    const { create, service } = setup();
    const saved = { id: 'server-id', title: dto.title };
    create.mockResolvedValue(saved);
    expect(await service.create(dto)).toBe(saved);
    expect(create).toHaveBeenCalledExactlyOnceWith({
      data: {
        title: dto.title,
        description: null,
        categoryId: null,
        startAt: new Date('2026-11-07T02:00:00Z'),
        endAt: new Date('2026-11-07T03:00:00Z'),
        priority: 'medium',
        status: 'pending',
      },
    });
  });

  it('preserves optional fields and selected priority', async () => {
    const { create, service } = setup();
    create.mockResolvedValue({});
    await service.create(
      Object.assign(new CreateTaskDto(), dto, {
        description: 'Báo cáo tuần',
        categoryId: 'study',
        priority: 'high',
      }),
    );
    expect(create.mock.calls[0][0].data).toMatchObject({
      description: 'Báo cáo tuần',
      categoryId: 'study',
      priority: 'high',
      status: 'pending',
    });
  });

  it('returns 503 without leaking raw database errors', async () => {
    const { create, service } = setup();
    create.mockRejectedValue(new Error('private database details'));
    try {
      await service.create(dto);
      throw new Error('Expected failure');
    } catch (error) {
      expect(error).toBeInstanceOf(ServiceUnavailableException);
      const failure = error as ServiceUnavailableException;
      expect(failure.getStatus()).toBe(503);
      expect(JSON.stringify(failure.getResponse())).not.toContain(
        'private database details',
      );
    }
  });
});
