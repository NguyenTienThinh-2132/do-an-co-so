import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
import { PrismaService } from '../dist/prisma/prisma.service.js';

async function checkCreateTask() {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  const runTitle = 'TV3 create smoke ' + randomUUID();
  let prisma;
  try {
    await app.listen(0, '127.0.0.1');
    prisma = app.get(PrismaService).client;
    const endpoint = (await app.getUrl()) + '/tasks';
    const post = (payload) =>
      fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(10000),
      });
    const payload = {
      title: '  ' + runTitle + '  ',
      startAt: '2026-11-07T09:00:00+07:00',
      endAt: '2026-11-07T10:00:00+07:00',
    };

    const response = await post(payload);
    assert.equal(response.status, 201);
    const task = await response.json();
    assert.equal(typeof task.id, 'string');
    assert.ok(task.id.length > 0);
    assert.equal(task.title, runTitle);
    assert.equal(task.priority, 'medium');
    assert.equal(task.status, 'pending');
    assert.equal(task.startAt, '2026-11-07T02:00:00.000Z');
    assert.ok(Number.isFinite(Date.parse(task.createdAt)));
    assert.ok(Number.isFinite(Date.parse(task.updatedAt)));

    const saved = await prisma.task.findUnique({ where: { id: task.id } });
    assert.equal(saved?.title, runTitle);
    console.log(
      'PASS: POST /tasks -> 201; bản ghi đã lưu thật với ID và thời điểm backend.',
    );

    for (const changes of [
      { title: ' ' },
      { endAt: payload.startAt },
      { priority: 'urgent' },
      { status: 'completed' },
    ]) {
      const invalid = await post({ ...payload, ...changes });
      assert.equal(invalid.status, 400);
    }
    assert.equal(await prisma.task.count({ where: { title: runTitle } }), 1);
    console.log('PASS: đầu vào sai -> 400, không thêm bản ghi thử khác.');
  } finally {
    try {
      if (prisma) {
        // Chỉ xóa bản ghi của lần thử này, nhận diện bằng title có UUID ngẫu nhiên.
        await prisma.task.deleteMany({ where: { title: runTitle } });
        assert.equal(
          await prisma.task.count({ where: { title: runTitle } }),
          0,
        );
        console.log('Đã xóa đúng dữ liệu thử của lần chạy này.');
      }
    } finally {
      await app.close();
    }
  }
}

checkCreateTask().catch(() => {
  console.error(
    'FAIL: kiểm tra API tạo Task chưa đạt; không in dữ liệu hoặc lỗi thô.',
  );
  process.exitCode = 1;
});
