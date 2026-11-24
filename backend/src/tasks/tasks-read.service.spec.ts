import { NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import type { PrismaService } from '../prisma/prisma.service.js';
import { TasksService } from './tasks.service.js';

describe('TasksService.getById', () => {
  const id = '850ca704-a7e5-437e-a206-0c42af3bf22d';
  function setup() {
    const findUnique = vi.fn();
    const service = new TasksService({
      client: { task: { findUnique } },
    } as unknown as PrismaService);
    return { service, findUnique };
  }

  it('loads the exact ID and returns the saved task', async () => {
    const { service, findUnique } = setup();
    const task = { id, title: 'Viết báo cáo' };
    findUnique.mockResolvedValue(task);
    expect(await service.getById(id)).toBe(task);
    expect(findUnique).toHaveBeenCalledExactlyOnceWith({ where: { id } });
  });

  it('returns 404 for a missing or deleted task, not 503', async () => {
    const { service, findUnique } = setup();
    findUnique.mockResolvedValue(null);
    await expect(service.getById(id)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('returns 503 without exposing database details', async () => {
    const { service, findUnique } = setup();
    findUnique.mockRejectedValue(new Error('private database details'));
    try {
      await service.getById(id);
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
