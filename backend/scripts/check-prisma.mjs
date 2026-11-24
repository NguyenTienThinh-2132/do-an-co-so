import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';
import { fileURLToPath } from 'node:url';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../dist/generated/prisma/client.js';

// Chạy sau prisma generate và npm run build; chỉ đọc database demo TV3.
async function checkConnection() {
  const envPath = fileURLToPath(new URL('../.env', import.meta.url));
  if (existsSync(envPath)) {
    loadEnvFile(envPath);
  }

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('Thiếu DATABASE_URL.');
  }

  const target = new URL(connectionString);
  if (
    target.protocol !== 'postgresql:' ||
    target.hostname !== '127.0.0.1' ||
    !['5432', '5433'].includes(target.port) ||
    target.pathname !== '/finai_tv3_demo'
  ) {
    throw new Error('Script chỉ dành cho database demo TV3 local.');
  }

  const adapter = new PrismaPg({
    connectionString,
    connectionTimeoutMillis: 5000,
    max: 1,
  });
  const prisma = new PrismaClient({ adapter });

  try {
    await prisma.$connect();
    const count = await prisma.task.count();
    console.log('PASS: Prisma đã đọc bảng tasks trong finai_tv3_demo.');
    console.log('Số công việc: ' + count);
  } finally {
    await prisma.$disconnect();
  }
}

checkConnection().catch(() => {
  // Không in lỗi thô để tránh lộ URL kết nối hoặc thông tin nhạy cảm.
  console.error(
    'FAIL: Chưa đọc được tasks. Kiểm tra .env, database demo, migration và bản build.',
  );
  process.exitCode = 1;
});
