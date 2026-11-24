// Real local integration check; uses only owned fixtures, never logs task content.
import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { loadEnvFile } from 'node:process';
import { writeFileSync } from 'node:fs';
import pg from 'pg';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';

loadEnvFile('.env');
const target = new URL(process.env.DATABASE_URL);
if (
  target.hostname !== '127.0.0.1' ||
  !['5432', '5433'].includes(target.port) ||
  target.pathname !== '/finai_tv3_demo'
) {
  throw new Error('Check only supports the local FinAI demo database.');
}
let sql = new pg.Client({
  connectionString: target.toString(),
  connectionTimeoutMillis: 5000,
});
await sql.connect();
const tables = [
  'tasks',
  'task_tombstones',
  'finance_books',
  'finance_jars',
  'finance_transactions',
  'finance_allocations',
  'finance_allocation_items',
  'finance_requests',
];
async function snapshot() {
  const result = {};
  for (const table of tables) {
    const { rows } = await sql.query(
      `SELECT row_to_json(t) AS data FROM "${table}" t ORDER BY row_to_json(t)::text`,
    );
    result[table] = {
      count: rows.length,
      hash: createHash('sha256').update(JSON.stringify(rows)).digest('hex'),
    };
  }
  return result;
}
const initial = await snapshot();
const marker = '__tv3_tombstone_' + randomUUID();
const ownedIds = new Set();
let app;
let base;
let checks = 0;
let result;
const body = {
  title: marker,
  startAt: '2048-02-03T02:00:00Z',
  endAt: '2048-02-03T03:00:00Z',
  priority: 'high',
};
async function api(method, path, data, expected) {
  const response = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    ...(data ? { body: JSON.stringify(data) } : {}),
    signal: AbortSignal.timeout(10000),
  });
  const text = await response.text();
  const value = text ? JSON.parse(text) : null;
  if (
    value &&
    typeof value.id === 'string' &&
    typeof value.title === 'string' &&
    value.title.startsWith(marker)
  )
    ownedIds.add(value.id);
  if (expected !== undefined)
    assert.equal(response.status, expected, 'Unexpected HTTP status');
  checks++;
  return { status: response.status, value, text };
}
async function create() {
  return (await api('POST', '/tasks', body, 201)).value;
}
async function tombstone(id) {
  return (
    await sql.query('SELECT * FROM task_tombstones WHERE task_id=$1', [id])
  ).rows[0];
}
try {
  app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  await app.listen(0, '127.0.0.1');
  base = await app.getUrl();

  const first = await create();
  assert.equal(first.version, 1);
  assert.equal(await tombstone(first.id), undefined);
  await api(
    'PUT',
    '/tasks/' + first.id,
    { ...body, title: marker + ' edited' },
    200,
  );
  assert.equal(
    (
      await api(
        'PATCH',
        '/tasks/' + first.id + '/status',
        { status: 'completed' },
        200,
      )
    ).value.version,
    3,
  );
  const beforeDelete = (
    await sql.query('SELECT clock_timestamp() AS time')
  ).rows[0].time.getTime();
  const removed = await api('DELETE', '/tasks/' + first.id, undefined, 204);
  assert.equal(removed.text, '');
  const firstMarker = await tombstone(first.id);
  assert.equal(firstMarker.task_id, first.id);
  assert.equal(firstMarker.version, 4);
  assert.deepEqual(Object.keys(firstMarker).sort(), [
    'deleted_at',
    'task_id',
    'version',
  ]);
  assert(firstMarker.deleted_at instanceof Date);
  const afterDelete = (
    await sql.query('SELECT clock_timestamp() AS time')
  ).rows[0].time.getTime();
  // Compare server clocks; timestamptz(3) rounds to the nearest millisecond.
  assert(
    firstMarker.deleted_at.getTime() >= beforeDelete - 1 &&
      firstMarker.deleted_at.getTime() <= afterDelete + 1,
    `Deletion time mismatch: before=${beforeDelete}, marker=${firstMarker.deleted_at.getTime()}, after=${afterDelete}`,
  );
  await api('GET', '/tasks/' + first.id, undefined, 404);
  const list = await api(
    'GET',
    '/tasks?' +
      new URLSearchParams({
        start: '2048-02-03T00:00:00Z',
        end: '2048-02-04T00:00:00Z',
        searchText: marker,
      }),
    undefined,
    200,
  );
  assert.equal(list.value.length, 0);
  await api('DELETE', '/tasks/' + first.id, undefined, 404);
  await api('PUT', '/tasks/' + first.id, body, 404);
  await api(
    'PATCH',
    '/tasks/' + first.id + '/status',
    { status: 'pending' },
    404,
  );
  assert.deepEqual(await tombstone(first.id), firstMarker);
  const missingId = randomUUID();
  await api('DELETE', '/tasks/' + missingId, undefined, 404);
  assert.equal(await tombstone(missingId), undefined);

  // Persisted marker survives a fresh DB connection, independently of Flutter.
  await sql.end();
  sql = new pg.Client({
    connectionString: target.toString(),
    connectionTimeoutMillis: 5000,
  });
  await sql.connect();
  assert.deepEqual(await tombstone(first.id), firstMarker);

  // Deliberate invalid fixture: a marker already exists for this owned live task.
  // Unique violation must roll back the earlier DELETE, preserving both records.
  const rollbackTask = await create();
  await sql.query('INSERT INTO task_tombstones(task_id,version) VALUES($1,9)', [
    rollbackTask.id,
  ]);
  const originalMarker = await tombstone(rollbackTask.id);
  const failed = await api(
    'DELETE',
    '/tasks/' + rollbackTask.id,
    undefined,
    503,
  );
  assert.equal(
    failed.value.message,
    'Chưa thể thay đổi công việc. Vui lòng thử lại sau.',
  );
  assert(!failed.text.includes('SQL') && !failed.text.includes('Unique'));
  assert.deepEqual(
    (await api('GET', '/tasks/' + rollbackTask.id, undefined, 200)).value,
    rollbackTask,
  );
  assert.deepEqual(await tombstone(rollbackTask.id), originalMarker);
  await sql.query('DELETE FROM task_tombstones WHERE task_id=$1', [
    rollbackTask.id,
  ]);
  await api('DELETE', '/tasks/' + rollbackTask.id, undefined, 204);
  assert.equal((await tombstone(rollbackTask.id)).version, 2);

  const twice = await create();
  const deletions = await Promise.all([
    api('DELETE', '/tasks/' + twice.id),
    api('DELETE', '/tasks/' + twice.id),
  ]);
  assert.deepEqual(deletions.map((r) => r.status).sort(), [204, 404]);
  assert.equal((await tombstone(twice.id)).version, 2);
  assert.equal(
    (
      await sql.query(
        'SELECT count(*)::int AS n FROM task_tombstones WHERE task_id=$1',
        [twice.id],
      )
    ).rows[0].n,
    1,
  );

  const raceTask = await create();
  const [edit, deletion] = await Promise.all([
    api('PUT', '/tasks/' + raceTask.id, {
      ...body,
      title: marker + ' concurrent',
    }),
    api('DELETE', '/tasks/' + raceTask.id),
  ]);
  assert.equal(deletion.status, 204);
  assert([200, 404].includes(edit.status));
  const raceMarker = await tombstone(raceTask.id);
  assert.equal(
    raceMarker.version,
    edit.status === 200 ? edit.value.version + 1 : 2,
  );
  assert.equal(
    (
      await sql.query('SELECT count(*)::int AS n FROM tasks WHERE id=$1', [
        raceTask.id,
      ])
    ).rows[0].n,
    0,
  );
  const invalidMarkerId = randomUUID();
  ownedIds.add(invalidMarkerId);
  await assert.rejects(
    sql.query('INSERT INTO task_tombstones(task_id,version) VALUES($1,1)', [
      invalidMarkerId,
    ]),
    (e) => e?.code === '23514',
  );
  result = {
    checkedAt: new Date().toISOString(),
    httpChecks: checks,
    deletedTaskVersion: 3,
    tombstoneVersion: 4,
    rollbackPreservesTask: true,
    repeatDeletePreservesMarker: true,
    concurrentDeleteStatuses: [204, 404],
    concurrentUpdateStatus: edit.status,
    concurrentTombstoneVersion: raceMarker.version,
    freshConnectionReadsMarker: true,
    invalidVersionRejected: true,
  };
} finally {
  try {
    if (app) await app.close();
  } finally {
    try {
      for (const id of ownedIds) {
        await sql.query('DELETE FROM tasks WHERE id=$1 AND title LIKE $2', [
          id,
          marker + '%',
        ]);
        await sql.query('DELETE FROM task_tombstones WHERE task_id=$1', [id]);
      }
      assert.deepEqual(
        await snapshot(),
        initial,
        'All original task/marker/finance rows must stay unchanged',
      );
    } finally {
      await sql.end();
    }
  }
}
result.existingDataUnchanged = true;
result.fixturesCleaned = true;
writeFileSync(
  '../build/task-tombstone-http-result.json',
  JSON.stringify(result, null, 2),
);
console.log('PASS: Task tombstones (real NestJS + PostgreSQL)', result);
