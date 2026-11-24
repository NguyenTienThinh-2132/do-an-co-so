import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
import { PrismaService } from '../dist/prisma/prisma.service.js';

async function checkReadTask() {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  const runTitle = 'TV3 read smoke ' + randomUUID();
  let prisma;
  try {
    await app.listen(0, '127.0.0.1');
    prisma = app.get(PrismaService).client;
    const base = (await app.getUrl()) + '/tasks';
    const response = await fetch(base, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: runTitle,
        startAt: '2026-11-07T02:00:00Z',
        endAt: '2026-11-07T03:00:00Z',
      }),
      signal: AbortSignal.timeout(10000),
    });
    assert.equal(response.status, 201);
    const created = await response.json();
    const get = (id) =>
      fetch(base + '/' + id, { signal: AbortSignal.timeout(10000) });
    const read = await get(created.id);
    assert.equal(read.status, 200);
    assert.deepEqual(await read.json(), created);
    console.log('PASS: GET theo ID -> 200 và đúng bản ghi đã lưu.');

    assert.equal((await get('not-a-uuid')).status, 400);
    const missingId = randomUUID();
    assert.equal(
      await prisma.task.findUnique({ where: { id: missingId } }),
      null,
    );
    assert.equal((await get(missingId)).status, 404);
    console.log('PASS: ID sai -> 400; UUID không tồn tại -> 404.');

    await prisma.task.deleteMany({
      where: { id: created.id, title: runTitle },
    });
    assert.equal((await get(created.id)).status, 404);
    console.log('PASS: bản ghi thử đã xóa -> 404.');
  } finally {
    try {
      if (prisma) {
        await prisma.task.deleteMany({ where: { title: runTitle } });
        assert.equal(
          await prisma.task.count({ where: { title: runTitle } }),
          0,
        );
        console.log('Đã dọn đúng dữ liệu thử của lần chạy này.');
      }
    } finally {
      await app.close();
    }
  }
}
checkReadTask().catch(() => {
  console.error(
    'FAIL: kiểm tra API đọc Task chưa đạt; không in dữ liệu hoặc lỗi thô.',
  );
  process.exitCode = 1;
});
