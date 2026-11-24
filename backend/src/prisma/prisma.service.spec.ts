import type { PrismaClient } from '../generated/prisma/client.js';
import { PrismaService } from './prisma.service.js';

describe('PrismaService lifecycle', () => {
  function setup() {
    const client = {
      $connect: vi.fn().mockResolvedValue(undefined),
      $disconnect: vi.fn().mockResolvedValue(undefined),
    };
    const service = new PrismaService(client as unknown as PrismaClient);
    return { client, service };
  }

  it('opens on init and closes on module destroy', async () => {
    const { client, service } = setup();
    expect(client.$connect).not.toHaveBeenCalled();
    await service.onModuleInit();
    expect(client.$connect).toHaveBeenCalledOnce();
    expect(client.$disconnect).not.toHaveBeenCalled();
    await service.onModuleDestroy();
    expect(client.$disconnect).toHaveBeenCalledOnce();
  });

  it('cleans up failed connection without exposing raw error', async () => {
    const { client, service } = setup();
    client.$connect.mockRejectedValue(new Error('sensitive driver details'));
    await expect(service.onModuleInit()).rejects.toThrow(
      'Không kết nối được database demo TV3.',
    );
    expect(client.$disconnect).toHaveBeenCalledOnce();
  });

  it('reports disconnect failure without exposing raw error', async () => {
    const { client, service } = setup();
    client.$disconnect.mockRejectedValue(new Error('sensitive driver details'));
    await expect(service.onModuleDestroy()).rejects.toThrow(
      'Không đóng được kết nối database demo TV3.',
    );
  });
});
