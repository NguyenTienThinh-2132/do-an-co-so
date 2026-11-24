import { Injectable } from '@nestjs/common';
import type { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import type { PrismaClient } from '../generated/prisma/client.js';

@Injectable()
export class PrismaService implements OnModuleInit, OnModuleDestroy {
  constructor(readonly client: PrismaClient) {}

  async onModuleInit(): Promise<void> {
    try {
      await this.client.$connect();
    } catch {
      // Dọn client kể cả khi kết nối thất bại, không lộ lỗi chứa credentials.
      await this.client.$disconnect().catch(() => undefined);
      throw new Error('Không kết nối được database demo TV3.');
    }
  }

  async onModuleDestroy(): Promise<void> {
    try {
      await this.client.$disconnect();
    } catch {
      throw new Error('Không đóng được kết nối database demo TV3.');
    }
  }
}
