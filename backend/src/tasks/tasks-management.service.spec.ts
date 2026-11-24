import { NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { CreateTaskDto } from './dto/create-task.dto.js';
import { ListTasksQueryDto } from './dto/list-tasks-query.dto.js';
import { TasksService } from './tasks.service.js';

describe('TasksService management', () => {
  const id = '850ca704-a7e5-437e-a206-0c42af3bf22d';
  function setup() {
    const task = { findMany: vi.fn(), update: vi.fn(), delete: vi.fn() };
    const taskTombstone = { create: vi.fn() };
    const executeRaw = vi.fn().mockResolvedValue(0);
    const transaction = vi.fn(async (action) =>
      action({ task, taskTombstone, $executeRaw: executeRaw }),
    );
    const service = new TasksService({
      client: { task, $transaction: transaction },
    } as unknown as PrismaService);
    return { service, task, taskTombstone, transaction, executeRaw };
  }
  const query = Object.assign(new ListTasksQueryDto(), {
    start: '2040-01-02T00:00:00Z',
    end: '2040-01-03T00:00:00Z',
  });

  it('combines overlap, status, priority and literal title search with stable sorting', async () => {
    const { service, task } = setup();
    task.findMany.mockResolvedValue([]);
    const filtered = Object.assign(new ListTasksQueryDto(), query, {
      status: 'pending',
      priority: 'high',
      searchText: 'Báo %_\\',
    });
    expect(await service.list(filtered)).toEqual([]);
    expect(task.findMany).toHaveBeenCalledExactlyOnceWith({
      where: {
        startAt: { lt: new Date(query.end) },
        endAt: { gt: new Date(query.start) },
        status: 'pending',
        priority: 'high',
        title: { contains: 'Báo \\%\\_\\\\', mode: 'insensitive' },
      },
      orderBy: [{ startAt: 'asc' }, { id: 'asc' }],
    });
  });

  it('does not add optional filters when omitted', async () => {
    const { service, task } = setup();
    task.findMany.mockResolvedValue([]);
    await service.list(query);
    expect(task.findMany.mock.calls[0][0].where).toEqual({
      startAt: { lt: new Date(query.end) },
      endAt: { gt: new Date(query.start) },
    });
  });

  it('PUT preserves identity/status while atomically incrementing the server version', async () => {
    const { service, task } = setup();
    const dto = Object.assign(new CreateTaskDto(), {
      title: 'Updated',
      startAt: query.start,
      endAt: query.end,
      priority: 'high',
    });
    const saved = { id, status: 'completed' };
    task.update.mockResolvedValue(saved);
    expect(await service.update(id, dto)).toBe(saved);
    expect(task.update).toHaveBeenCalledExactlyOnceWith({
      where: { id },
      data: {
        title: 'Updated',
        description: null,
        categoryId: null,
        startAt: new Date(query.start),
        endAt: new Date(query.end),
        priority: 'high',
        version: { increment: 1 },
      },
    });
  });

  it('status change cannot alter content', async () => {
    const { service, task } = setup();
    task.update.mockResolvedValue({ id, status: 'completed' });
    await service.setStatus(id, 'completed');
    expect(task.update).toHaveBeenCalledExactlyOnceWith({
      where: { id },
      data: { status: 'completed', version: { increment: 1 } },
    });
  });

  it('deletes and stores the next version within one transaction', async () => {
    const { service, task, taskTombstone, transaction, executeRaw } = setup();
    task.delete.mockResolvedValue({ id, version: 7 });
    expect(await service.delete(id)).toBeUndefined();
    expect(transaction).toHaveBeenCalledTimes(1);
    expect(executeRaw).toHaveBeenCalledTimes(1);
    expect(task.delete).toHaveBeenCalledExactlyOnceWith({ where: { id } });
    expect(taskTombstone.create).toHaveBeenCalledExactlyOnceWith({
      data: { taskId: id, version: 8 },
    });
  });

  it('does not create a tombstone if deleting the task fails', async () => {
    const { service, task, taskTombstone } = setup();
    task.delete.mockRejectedValue(new Error('private SQL details'));
    await expect(service.delete(id)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(taskTombstone.create).not.toHaveBeenCalled();
  });

  it('propagates tombstone failure out of the transaction as a safe 503', async () => {
    const { service, task, taskTombstone } = setup();
    task.delete.mockResolvedValue({ id, version: 3 });
    taskTombstone.create.mockRejectedValue(new Error('private SQL details'));
    await expect(service.delete(id)).rejects.toThrow(
      'Chưa thể thay đổi công việc.',
    );
  });

  it.each(['update', 'status', 'delete'])(
    'maps atomic missing-record error to 404 for %s',
    async (operation) => {
      const { service, task } = setup();
      const missing = new Prisma.PrismaClientKnownRequestError('not found', {
        code: 'P2025',
        clientVersion: '7.10.1',
      });
      task.update.mockRejectedValue(missing);
      task.delete.mockRejectedValue(missing);
      const call =
        operation === 'delete'
          ? service.delete(id)
          : operation === 'status'
            ? service.setStatus(id, 'completed')
            : service.update(
                id,
                Object.assign(new CreateTaskDto(), {
                  title: 'x',
                  startAt: query.start,
                  endAt: query.end,
                }),
              );
      await expect(call).rejects.toBeInstanceOf(NotFoundException);
    },
  );

  it.each(['list', 'update', 'status', 'delete'])(
    'sanitizes storage errors for %s',
    async (operation) => {
      const { service, task } = setup();
      for (const fn of Object.values(task))
        fn.mockRejectedValue(new Error('private SQL details'));
      const call =
        operation === 'list'
          ? service.list(query)
          : operation === 'delete'
            ? service.delete(id)
            : operation === 'status'
              ? service.setStatus(id, 'completed')
              : service.update(
                  id,
                  Object.assign(new CreateTaskDto(), {
                    title: 'x',
                    startAt: query.start,
                    endAt: query.end,
                  }),
                );
      try {
        await call;
        throw new Error('Expected failure');
      } catch (error) {
        expect(error).toBeInstanceOf(ServiceUnavailableException);
        expect(
          JSON.stringify((error as ServiceUnavailableException).getResponse()),
        ).not.toContain('private SQL details');
      }
    },
  );
});
