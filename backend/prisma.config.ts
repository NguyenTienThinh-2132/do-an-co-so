import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';
import { fileURLToPath } from 'node:url';
import { defineConfig, env } from 'prisma/config';

const envPath = fileURLToPath(new URL('./.env', import.meta.url));
if (existsSync(envPath)) {
  loadEnvFile(envPath);
}

const databaseUrl = env('DATABASE_URL');
const target = new URL(databaseUrl);

// PostgreSQL local trực tiếp dùng 5432; giữ 5433 cho cấu hình local cũ.
// Vẫn giới hạn đúng database demo, không tự kết nối server khác.
if (
  target.protocol !== 'postgresql:' ||
  target.hostname !== '127.0.0.1' ||
  !['5432', '5433'].includes(target.port) ||
  target.pathname !== '/finai_tv3_demo'
) {
  throw new Error(
    'Prisma chỉ được phép dùng database local finai_tv3_demo trên cổng 5432 hoặc 5433.',
  );
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: { url: databaseUrl },
});
