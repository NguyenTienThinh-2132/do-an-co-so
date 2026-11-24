import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
import { PrismaService } from '../dist/prisma/prisma.service.js';

async function checkNestPrisma() {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  try {
    await app.listen(0, '127.0.0.1');
    const prisma = app.get(PrismaService);
    const count = await prisma.client.task.count();
    const response = await fetch(await app.getUrl(), {
      signal: AbortSignal.timeout(5000),
    });
    if (response.status !== 200 || (await response.text()) !== 'Hello World!') {
      throw new Error('Unexpected HTTP response');
    }
    console.log('PASS: NestJS khởi tạo PrismaService và đọc tasks: ' + count);
    console.log('PASS: GET / -> 200 Hello World!');
  } finally {
    await app.close();
    console.log('NestJS đã đóng app và kết nối database.');
  }
}

checkNestPrisma().catch(() => {
  console.error(
    'FAIL: Kiểm tra database demo, .env, migration và bản build. Không in lỗi thô.',
  );
  process.exitCode = 1;
});
