import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';
import { fileURLToPath } from 'node:url';
import { Module } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { PrismaService } from './prisma.service.js';

@Module({
  providers: [
    {
      provide: PrismaService,
      useFactory: () => {
        // Cùng độ sâu ở src/prisma và dist/prisma.
        const envPath = fileURLToPath(new URL('../../.env', import.meta.url));
        if (existsSync(envPath)) {
          loadEnvFile(envPath);
        }

        const connectionString = process.env.DATABASE_URL;
        let target: URL;
        try {
          if (!connectionString) {
            throw new Error();
          }
          target = new URL(connectionString);
        } catch {
          throw new Error('Thiếu hoặc sai DATABASE_URL của demo TV3.');
        }

        if (
          target.protocol !== 'postgresql:' ||
          target.hostname !== '127.0.0.1' ||
          !['5432', '5433'].includes(target.port) ||
          target.pathname !== '/finai_tv3_demo'
        ) {
          throw new Error('PrismaModule chỉ dùng database local demo TV3.');
        }

        const adapter = new PrismaPg({
          connectionString,
          connectionTimeoutMillis: 5000,
          max: 5,
        });
        return new PrismaService(new PrismaClient({ adapter }));
      },
    },
  ],
  exports: [PrismaService],
})
export class PrismaModule {}
