import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:finai/core/cache/cache_entry.dart';
import 'package:finai/core/cache/response_cache.dart';
import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';

Map<String, Object?> fixture({String title = 'Công việc đã tải'}) => {
  'id': 'cache-task',
  'title': title,
  'description': 'Mô tả thử',
  'categoryId': null,
  'startAt': '2026-11-23T02:00:00.000Z',
  'endAt': '2026-11-23T03:00:00.000Z',
  'priority': 'high',
  'status': 'pending',
  'createdAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': '2026-11-23T01:00:00.000Z',
};
http.Response response(Object? data, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  code,
  headers: {'content-type': 'application/json'},
);
TaskQuery query({
  TaskStatus? status,
  TaskPriority? priority,
  String search = '',
  int day = 23,
}) => TaskQuery(
  start: DateTime.utc(2026, 11, day),
  end: DateTime.utc(2026, 11, day + 1),
  status: status,
  priority: priority,
  searchText: search,
);
List<Task> tasks(Result<List<Task>> r) => (r as Success<List<Task>>).value;
const unavailable = AppFailure(
  code: AppFailureCode.unavailable,
  message: 'Cache test unavailable',
);

class MemoryCache implements ResponseCache {
  final entries = <String, CacheEntry>{};
  int reads = 0;
  int clears = 0;
  bool failWrites = false, failClears = false;
  Completer<void>? blockWrite;
  String token(CacheKey k) => jsonEncode([k.namespace, k.resource, k.queryKey]);
  @override
  Future<Result<CacheEntry?>> read(
    CacheKey k, {
    int expectedSchemaVersion = 1,
  }) async {
    reads++;
    final e = entries[token(k)];
    return Success(e?.schemaVersion == expectedSchemaVersion ? e : null);
  }

  @override
  Future<Result<void>> write(
    CacheKey k, {
    required String payloadJson,
    int schemaVersion = 1,
  }) async {
    await blockWrite?.future;
    if (failWrites) throw StateError('Test storage failure');
    entries[token(k)] = CacheEntry(
      key: k,
      payloadJson: payloadJson,
      savedAt: DateTime.utc(2026, 11, 23),
      schemaVersion: schemaVersion,
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> clearNamespace(String namespace) async {
    clears++;
    if (failClears) return const Failure(unavailable);
    entries.removeWhere((_, e) => e.key.namespace == namespace);
    return const Success(null);
  }

  @override
  Future<Result<void>> remove(CacheKey k) async {
    entries.remove(token(k));
    return const Success(null);
  }
}

HttpTaskRepository repository(
  MemoryCache cache,
  Future<http.Response> Function(http.Request) handler, {
  String scope = 'native|server-a|tasks-v1',
  Duration timeout = const Duration(seconds: 2),
}) {
  final client = MockClient(handler);
  final repo = HttpTaskRepository(
    datasource: TaskRemoteDatasource(
      client: client,
      baseUrl: Uri.parse('http://example.test'),
      timeout: timeout,
    ),
    cache: cache,
    cacheNamespace: scope,
  );
  addTearDown(() async {
    repo.dispose();
    await repo.cacheSettled;
    client.close();
  });
  return repo;
}

Future<void> seed(HttpTaskRepository repo) async {
  await repo.watch(query()).first;
  await repo.cacheSettled;
}

Future<http.Response> offline(http.Request r) async =>
    throw http.ClientException('offline');
void main() {
  test(
    'online snapshot survives a new offline repository including UTC/enums',
    () async {
      final cache = MemoryCache();
      final online = repository(cache, (_) async => response([fixture()]));
      await seed(online);
      final offlineRepo = repository(cache, offline);
      final restored = tasks(await offlineRepo.watch(query()).first).single;
      expect(restored.title, 'Công việc đã tải');
      expect(restored.priority, TaskPriority.high);
      expect(restored.startAt.isUtc, isTrue);
      expect(restored.description, 'Mô tả thử');
    },
  );
  test('successful empty API result replaces old cache', () async {
    final cache = MemoryCache();
    bool empty = false;
    final repo = repository(
      cache,
      (_) async => response(empty ? [] : [fixture()]),
    );
    await seed(repo);
    empty = true;
    await seed(repo);
    expect(
      tasks(await repository(cache, offline).watch(query()).first),
      isEmpty,
    );
  });
  test('no cache remains an error, never a fake empty list', () async {
    expect(
      await repository(MemoryCache(), offline).watch(query()).first,
      isA<Failure<List<Task>>>(),
    );
  });
  test(
    'different server/day/status/priority/search cannot reuse a snapshot',
    () async {
      final cache = MemoryCache();
      await seed(repository(cache, (_) async => response([fixture()])));
      expect(
        await repository(
          cache,
          offline,
          scope: 'native|server-b|tasks-v1',
        ).watch(query()).first,
        isA<Failure<List<Task>>>(),
      );
      final repo = repository(cache, offline);
      for (final q in [
        query(day: 24),
        query(status: TaskStatus.completed),
        query(priority: TaskPriority.low),
        query(search: 'khác'),
      ]) {
        expect(await repo.watch(q).first, isA<Failure<List<Task>>>());
      }
      final equivalent = TaskQuery(
        start: DateTime.parse('2026-11-23T07:00:00+07:00'),
        end: DateTime.parse('2026-11-24T07:00:00+07:00'),
      );
      expect(tasks(await repo.watch(equivalent).first), hasLength(1));
    },
  );
  for (final code in [500, 502, 503, 504]) {
    test('HTTP $code can read the last saved snapshot', () async {
      final cache = MemoryCache();
      await seed(repository(cache, (_) async => response([fixture()])));
      expect(
        tasks(
          await repository(
            cache,
            (_) async => http.Response('', code),
          ).watch(query()).first,
        ),
        hasLength(1),
      );
    });
  }
  for (final code in [400, 401, 403, 404, 409, 422, 429]) {
    test('HTTP $code does not fall back to a saved snapshot', () async {
      final cache = MemoryCache();
      await seed(repository(cache, (_) async => response([fixture()])));
      final before = cache.reads;
      expect(
        await repository(
          cache,
          (_) async => http.Response('', code),
        ).watch(query()).first,
        isA<Failure<List<Task>>>(),
      );
      expect(cache.reads, before);
    });
  }
  test('malformed 200 does not mask the server error with cache', () async {
    final cache = MemoryCache();
    await seed(repository(cache, (_) async => response([fixture()])));
    final before = cache.reads;
    expect(
      await repository(
        cache,
        (_) async => http.Response('{', 200),
      ).watch(query()).first,
      isA<Failure<List<Task>>>(),
    );
    expect(cache.reads, before);
  });
  test('timeout can read cache', () async {
    final cache = MemoryCache();
    await seed(repository(cache, (_) async => response([fixture()])));
    final pending = Completer<http.Response>();
    final result = await repository(
      cache,
      (_) => pending.future,
      timeout: const Duration(milliseconds: 15),
    ).watch(query()).first;
    expect(tasks(result), hasLength(1));
    pending.complete(response([]));
  });
  test('disk write failure does not fail a successful API read', () async {
    final cache = MemoryCache()..failWrites = true;
    final repo = repository(cache, (_) async => response([fixture()]));
    expect(tasks(await repo.watch(query()).first), hasLength(1));
    await repo.cacheSettled;
  });
  for (final operation in ['create', 'update', 'status', 'delete']) {
    test('$operation success invalidates inactive saved queries', () async {
      final cache = MemoryCache();
      final repo = repository(
        cache,
        (r) async => r.method == 'GET'
            ? response([fixture()])
            : r.method == 'DELETE'
            ? http.Response('', 204)
            : response(fixture(), r.method == 'POST' ? 201 : 200),
      );
      await seed(repo);
      await repo.watch(query(day: 24)).first;
      await repo.cacheSettled;
      final draft = TaskDraft(
        title: 'Thay đổi',
        startAt: DateTime.utc(2026, 11, 23, 2),
        endAt: DateTime.utc(2026, 11, 23, 3),
      );
      switch (operation) {
        case 'create':
          await repo.create(draft);
        case 'update':
          await repo.update('cache-task', draft);
        case 'status':
          await repo.setStatus('cache-task', TaskStatus.completed);
        case 'delete':
          await repo.delete('cache-task');
      }
      await repo.cacheSettled;
      final later = repository(cache, offline);
      expect(await later.watch(query()).first, isA<Failure<List<Task>>>());
      expect(
        await later.watch(query(day: 24)).first,
        isA<Failure<List<Task>>>(),
      );
    });
  }
  test('failed mutation preserves the last saved list', () async {
    final cache = MemoryCache();
    final repo = repository(
      cache,
      (r) async =>
          r.method == 'GET' ? response([fixture()]) : http.Response('', 503),
    );
    await seed(repo);
    expect(await repo.delete('cache-task'), isA<Failure<void>>());
    await repo.cacheSettled;
    expect(
      tasks(await repository(cache, offline).watch(query()).first),
      hasLength(1),
    );
  });
  test(
    'permission denial clears saved lists and blocks fallback for this owner',
    () async {
      final cache = MemoryCache();
      int status = 200;
      final repo = repository(
        cache,
        (_) async =>
            status == 200 ? response([fixture()]) : http.Response('', status),
      );
      await seed(repo);
      status = 403;
      expect(await repo.watch(query()).first, isA<Failure<List<Task>>>());
      await repo.cacheSettled;
      expect(cache.entries, isEmpty);
      status = 503;
      expect(await repo.watch(query()).first, isA<Failure<List<Task>>>());
    },
  );
  test(
    'older response from a second watcher cannot overwrite newer cache',
    () async {
      final cache = MemoryCache();
      final old = Completer<http.Response>(),
          fresh = Completer<http.Response>();
      int calls = 0;
      final repo = repository(
        cache,
        (_) => ++calls == 1 ? old.future : fresh.future,
      );
      final first = repo.watch(query()).first,
          second = repo.watch(query()).first;
      await Future<void>.delayed(Duration.zero);
      fresh.complete(response([fixture(title: 'Mới')]));
      await second;
      await repo.cacheSettled;
      old.complete(response([fixture(title: 'Cũ')]));
      await first;
      await repo.cacheSettled;
      expect(
        tasks(await repository(cache, offline).watch(query()).first)
            .single
            .title,
        'Mới',
      );
    },
  );
  test('mutation clears an older write already in progress', () async {
    final cache = MemoryCache()..blockWrite = Completer<void>();
    final repo = repository(
      cache,
      (r) async =>
          r.method == 'GET' ? response([fixture()]) : http.Response('', 204),
    );
    await repo.watch(query()).first;
    await repo.delete('cache-task');
    cache.blockWrite!.complete();
    await repo.cacheSettled;
    expect(
      await repository(cache, offline).watch(query()).first,
      isA<Failure<List<Task>>>(),
    );
  });
  test(
    'failed invalidation cannot resurrect deleted data in this session',
    () async {
      final cache = MemoryCache();
      bool empty = false;
      bool offlineMode = false;
      final repo = repository(cache, (r) async {
        if (offlineMode) throw http.ClientException('offline');
        return r.method == 'GET'
            ? response(empty ? [] : [fixture()])
            : http.Response('', 204);
      });
      await seed(repo);
      cache.failClears = true;
      await repo.delete('cache-task');
      await repo.cacheSettled;
      offlineMode = true;
      expect(await repo.watch(query()).first, isA<Failure<List<Task>>>());
      cache.failClears = false;
      offlineMode = false;
      empty = true;
      await seed(repo);
      offlineMode = true;
      expect(tasks(await repo.watch(query()).first), isEmpty);
    },
  );
  test('corrupt cached Task is not emitted as valid data', () async {
    final cache = MemoryCache();
    await seed(repository(cache, (_) async => response([fixture()])));
    final old = cache.entries.values.single;
    cache.entries[cache.token(old.key)] = CacheEntry(
      key: old.key,
      payloadJson: '[{"id":"broken"}]',
      savedAt: old.savedAt,
      schemaVersion: 1,
    );
    expect(
      await repository(cache, offline).watch(query()).first,
      isA<Failure<List<Task>>>(),
    );
  });
}
