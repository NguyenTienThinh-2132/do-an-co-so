import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
import { PrismaService } from '../dist/prisma/prisma.service.js';

async function checkTasksCrud() {
  const marker = 'TV3 CRUD ' + randomUUID() + ' ';
  let app;
  let prisma;
  let base;
  const startApp = async () => {
    app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    await app.listen(0, '127.0.0.1');
    prisma = app.get(PrismaService).client;
    base = (await app.getUrl()) + '/tasks';
  };
  const http = (method, path = '', body) =>
    fetch(base + path, {
      method,
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(10000),
    });
  const expectJson = async (responsePromise, status) => {
    const response = await responsePromise;
    assert.equal(response.status, status);
    return response.json();
  };
  const range = { start: '2040-01-02T00:00:00Z', end: '2040-01-03T00:00:00Z' };
  const list = (extra = {}) =>
    expectJson(
      http(
        'GET',
        '?' + new URLSearchParams({ ...range, searchText: marker, ...extra }),
      ),
      200,
    );

  try {
    await startApp();
    const specs = [
      ['Báo cáo %_\\', '2040-01-01T23:00:00Z', '2040-01-02T01:00:00Z', 'high'],
      ['BÁO CÁO', '2040-01-02T09:00:00Z', '2040-01-02T10:00:00Z', 'high'],
      ['Học Flutter', '2040-01-02T09:00:00Z', '2040-01-02T10:00:00Z', 'low'],
      [
        'Trước khoảng',
        '2040-01-01T23:00:00Z',
        '2040-01-02T00:00:00Z',
        'medium',
      ],
      ['Sau khoảng', '2040-01-03T00:00:00Z', '2040-01-03T01:00:00Z', 'medium'],
      ['Tối', '2040-01-02T23:00:00Z', '2040-01-03T01:00:00Z', 'medium'],
    ];
    const tasks = [];
    for (const [title, startAt, endAt, priority] of specs) {
      tasks.push(
        await expectJson(
          http('POST', '', {
            title: marker + title,
            startAt,
            endAt,
            priority,
          }),
          201,
        ),
      );
    }
    await expectJson(
      http('PATCH', '/' + tasks[2].id + '/status', { status: 'inProgress' }),
      200,
    );

    const expectedOrder = [tasks[0], tasks[1], tasks[2], tasks[5]]
      .sort(
        (a, b) =>
          a.startAt.localeCompare(b.startAt) || a.id.localeCompare(b.id),
      )
      .map((task) => task.id);
    assert.deepEqual(
      (await list()).map((task) => task.id),
      expectedOrder,
    );
    assert.deepEqual(
      (await list()).map((task) => task.id),
      expectedOrder,
    );
    assert.deepEqual(
      (
        await list({
          status: 'pending',
          priority: 'high',
          searchText: marker + 'báo cáo',
        })
      ).map((task) => task.id),
      [tasks[0].id, tasks[1].id],
    );
    assert.deepEqual(
      (await list({ status: 'inProgress' })).map((task) => task.id),
      [tasks[2].id],
    );
    assert.deepEqual(
      (await list({ priority: 'low' })).map((task) => task.id),
      [tasks[2].id],
    );
    assert.deepEqual(
      (await list({ searchText: marker + 'BÁO CÁO %_\\' })).map(
        (task) => task.id,
      ),
      [tasks[0].id],
    );
    assert.deepEqual(await list({ searchText: marker + 'bao cao' }), []);
    assert.deepEqual(
      await list({
        start: '2042-01-01T00:00:00Z',
        end: '2042-01-02T00:00:00Z',
      }),
      [],
    );
    console.log(
      'PASS: lọc giao ngày, ranh giới, AND, trạng thái, ưu tiên, tìm tên có dấu/ký tự đặc biệt và sắp xếp.',
    );

    for (const changes of [
      { end: range.start },
      { start: '2040-01-02T00:00:00' },
      { status: 'overdue' },
      { priority: 'urgent' },
      { extra: 'x' },
    ]) {
      const response = await http(
        'GET',
        '?' + new URLSearchParams({ ...range, ...changes }),
      );
      assert.equal(response.status, 400);
    }

    const original = tasks[0];
    await expectJson(
      http('PATCH', '/' + original.id + '/status', { status: 'completed' }),
      200,
    );
    const content = {
      title: '  ' + marker + 'Đã sửa  ',
      description: 'TV3 test',
      categoryId: 'demo-category',
      startAt: '2040-01-02T19:00:00+07:00',
      endAt: '2040-01-02T20:00:00+07:00',
      priority: 'low',
    };
    const updated = await expectJson(
      http('PUT', '/' + original.id, content),
      200,
    );
    assert.equal(updated.id, original.id);
    assert.equal(updated.createdAt, original.createdAt);
    assert.equal(updated.status, 'completed');
    assert.equal(updated.title, content.title.trim());
    assert.equal(updated.priority, 'low');
    assert.equal(updated.description, content.description);
    assert.equal(updated.categoryId, content.categoryId);
    assert.equal(updated.startAt, '2040-01-02T12:00:00.000Z');
    assert.ok(Date.parse(updated.updatedAt) >= Date.parse(original.updatedAt));
    const replacement = await expectJson(
      http('PUT', '/' + original.id, {
        title: marker + 'Đã sửa',
        startAt: content.startAt,
        endAt: content.endAt,
      }),
      200,
    );
    assert.equal(replacement.description, null);
    assert.equal(replacement.categoryId, null);
    assert.equal(replacement.priority, 'medium');
    assert.equal(replacement.status, 'completed');
    assert.equal(replacement.createdAt, original.createdAt);
    console.log(
      'PASS: PUT thay nội dung, giữ ID/status/createdAt, cập nhật thời gian và mặc định.',
    );

    for (const status of ['inProgress', 'completed', 'pending']) {
      const changed = await expectJson(
        http('PATCH', '/' + tasks[1].id + '/status', { status }),
        200,
      );
      assert.equal(changed.status, status);
      assert.equal(changed.title, tasks[1].title);
      assert.equal(changed.createdAt, tasks[1].createdAt);
    }
    assert.equal(
      (
        await http('PATCH', '/' + original.id + '/status', {
          status: 'overdue',
        })
      ).status,
      400,
    );
    assert.equal(
      (await http('PUT', '/' + original.id, { ...content, title: ' ' })).status,
      400,
    );
    console.log(
      'PASS: đổi trạng thái độc lập; dữ liệu sửa/trạng thái sai bị chặn.',
    );

    const deleted = await http('DELETE', '/' + tasks[5].id);
    assert.equal(deleted.status, 204);
    assert.equal(await deleted.text(), '');
    assert.equal((await http('GET', '/' + tasks[5].id)).status, 404);
    assert.equal((await http('DELETE', '/' + tasks[5].id)).status, 404);
    const missingId = randomUUID();
    assert.equal((await http('PUT', '/' + missingId, content)).status, 404);
    assert.equal(
      (await http('PATCH', '/' + missingId + '/status', { status: 'pending' }))
        .status,
      404,
    );
    assert.equal((await http('PUT', '/bad-id', content)).status, 400);
    assert.equal(
      (await http('PATCH', '/bad-id/status', { status: 'pending' })).status,
      400,
    );
    assert.equal((await http('DELETE', '/bad-id')).status, 400);
    console.log('PASS: DELETE 204; bản ghi mất 404; ID sai 400.');

    await app.close();
    await startApp();
    const reopened = await expectJson(http('GET', '/' + original.id), 200);
    assert.deepEqual(reopened, replacement);
    console.log(
      'PASS: khởi động lại app NestJS, dữ liệu đã sửa vẫn còn và đúng.',
    );
  } finally {
    try {
      if (prisma) {
        await prisma.task.deleteMany({
          where: { title: { startsWith: marker } },
        });
        assert.equal(
          await prisma.task.count({ where: { title: { startsWith: marker } } }),
          0,
        );
        console.log('Đã dọn toàn bộ fixture của riêng lần thử này.');
      }
    } finally {
      if (prisma) await prisma.$disconnect();
      if (app) await app.close();
    }
  }
}

checkTasksCrud().catch(() => {
  console.error(
    'FAIL: kiểm tra CRUD Tasks chưa đạt; không in dữ liệu hoặc lỗi SQL thô.',
  );
  process.exitCode = 1;
});
