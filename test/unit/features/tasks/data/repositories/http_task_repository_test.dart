import 'dart:async';
import 'dart:convert';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _fixture(String id, {String status = 'pending'}) => {
  'id': id,
  'title': 'Task $id',
  'description': null,
  'categoryId': null,
  'startAt': '2026-11-07T02:00:00.000Z',
  'endAt': '2026-11-07T03:00:00.000Z',
  'priority': 'medium',
  'status': status,
  'createdAt': '2026-11-07T01:00:00.000Z',
  'updatedAt': '2026-11-07T01:00:00.000Z',
};

// Fake HTTP server có ghi và đọc; không dùng database thật.
class _Backend {
  final records = <String, Map<String, Object?>>{};
  final calls = <http.Request>[];
  bool failWrites = false;
  bool failLists = false;
  int counter = 0;

  int get listCalls => calls
      .where((r) => r.method == 'GET' && r.url.pathSegments.length == 1)
      .length;

  Future<http.Response> handle(http.Request request) async {
    calls.add(request);
    final segments = request.url.pathSegments;
    if (request.method == 'GET' && segments.length == 1) {
      if (failLists) return http.Response('', 503);
      final q = request.url.queryParameters;
      final list =
          records.values.where((task) {
            return DateTime.parse(task['startAt'] as String)
                    .isBefore(DateTime.parse(q['end']!)) &&
                DateTime.parse(task['endAt'] as String)
                    .isAfter(DateTime.parse(q['start']!)) &&
                (q['status'] == null || task['status'] == q['status']) &&
                (q['priority'] == null || task['priority'] == q['priority']) &&
                (q['searchText'] == null ||
                    (task['title'] as String).toLowerCase().contains(
                      q['searchText']!.toLowerCase(),
                    ));
          }).toList()..sort((a, b) {
            final byTime = (a['startAt'] as String).compareTo(
              b['startAt'] as String,
            );
            return byTime != 0
                ? byTime
                : (a['id'] as String).compareTo(b['id'] as String);
          });
      return _json(list);
    }
    if (request.method == 'GET') {
      final task = records[segments[1]];
      return task == null ? http.Response('', 404) : _json(task);
    }
    if (failWrites) return http.Response('', 503);
    if (request.method == 'POST') {
      counter++;
      final id = 'task-$counter';
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final saved = {..._fixture(id), ...body, 'id': id, 'status': 'pending'};
      records[id] = saved;
      return _json(saved, 201);
    }
    final id = segments[1];
    final existing = records[id];
    if (existing == null) return http.Response('', 404);
    if (request.method == 'DELETE') {
      records.remove(id);
      return http.Response('', 204);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    records[id] = {
      ...existing,
      ...body,
      'updatedAt': '2026-11-07T01:01:00.000Z',
    };
    return _json(records[id]);
  }
}

void main() {
  final start = DateTime.utc(2026, 11, 7);
  final end = DateTime.utc(2026, 11, 8);
  TaskQuery query({TaskStatus? status}) =>
      TaskQuery(start: start, end: end, status: status);
  TaskDraft draft({String title = 'New task'}) => TaskDraft(
    title: title,
    startAt: start.add(const Duration(hours: 2)),
    endAt: start.add(const Duration(hours: 3)),
  );

  ({HttpTaskRepository repo, http.Client client}) setup(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = MockClient(handler);
    final repo = HttpTaskRepository(
      datasource: TaskRemoteDatasource(
        client: client,
        baseUrl: Uri.parse('https://example.test'),
        timeout: const Duration(seconds: 2),
      ),
    );
    addTearDown(() {
      repo.dispose();
      client.close();
    });
    return (repo: repo, client: client);
  }

  Future<List<Task>> next(StreamIterator<Result<List<Task>>> iterator) async {
    expect(
      await iterator.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    return (iterator.current as Success<List<Task>>).value;
  }

  test(
    'Thực thi TaskRepository, chỉ tải khi có listener và lấy dữ liệu đầu',
    () async {
      final backend = _Backend();
      final harness = setup(backend.handle);
      final TaskRepository repository = harness.repo;
      final stream = repository.watch(query());
      expect(backend.listCalls, 0);
      await repository.create(draft());
      expect(backend.listCalls, 0);
      final snapshot = await stream.first;
      expect((snapshot as Success<List<Task>>).value.single.title, 'New task');
      expect(backend.listCalls, 1);
    },
  );

  test('CRUD thành công tự phát lại list sau mỗi thao tác', () async {
    final backend = _Backend();
    final repo = setup(backend.handle).repo;
    final iterator = StreamIterator(repo.watch(query()));
    addTearDown(iterator.cancel);
    expect(await next(iterator), isEmpty);

    final created = (await repo.create(draft()) as Success<Task>).value;
    expect((await next(iterator)).single.id, created.id);
    expect(
      (await repo.getById(created.id) as Success<Task>).value.title,
      'New task',
    );
    expect(backend.listCalls, 2); // getById không invalidation.

    await repo.update(created.id, draft(title: 'Edited'));
    expect((await next(iterator)).single.title, 'Edited');
    await repo.setStatus(created.id, TaskStatus.completed);
    expect((await next(iterator)).single.status, TaskStatus.completed);
    expect(await repo.delete(created.id), isA<Success<void>>());
    expect(await next(iterator), isEmpty);
    expect(backend.listCalls, 5);
  });

  test('Hai bộ lọc cập nhật độc lập khi task đổi trạng thái', () async {
    final backend = _Backend()..records['one'] = _fixture('one');
    final repo = setup(backend.handle).repo;
    final pending = StreamIterator(
      repo.watch(query(status: TaskStatus.pending)),
    );
    final completed = StreamIterator(
      repo.watch(query(status: TaskStatus.completed)),
    );
    addTearDown(pending.cancel);
    addTearDown(completed.cancel);
    expect((await next(pending)).single.id, 'one');
    expect(await next(completed), isEmpty);
    await repo.setStatus('one', TaskStatus.completed);
    expect(await next(pending), isEmpty);
    expect((await next(completed)).single.id, 'one');
  });

  test(
    'Cùng một stream hỗ trợ nhiều listener với dữ liệu ban đầu riêng',
    () async {
      final backend = _Backend();
      final repo = setup(backend.handle).repo;
      final stream = repo.watch(query());
      final first = StreamIterator(stream);
      final second = StreamIterator(stream);
      addTearDown(first.cancel);
      addTearDown(second.cancel);
      expect(await next(first), isEmpty);
      expect(await next(second), isEmpty);
      await repo.create(draft());
      expect((await next(first)).length, 1);
      expect((await next(second)).length, 1);
      await first.cancel();
      final before = backend.listCalls;
      await repo.create(draft());
      expect((await next(second)).length, 2);
      expect(backend.listCalls, before + 1);
    },
  );

  test('Ghi thất bại giữ nguyên Failure và không tải lại list', () async {
    final backend = _Backend();
    final repo = setup(backend.handle).repo;
    final iterator = StreamIterator(repo.watch(query()));
    addTearDown(iterator.cancel);
    await next(iterator);
    backend.failWrites = true;
    final result = await repo.create(draft()) as Failure<Task>;
    expect(result.failure.code, AppFailureCode.unavailable);
    await Future<void>.delayed(Duration.zero);
    expect(backend.listCalls, 1);
    backend.failWrites = false;
    await repo.create(draft());
    expect((await next(iterator)).length, 1);
  });

  test('404 khi đọc/sửa/trạng thái/xóa không kích hoạt refresh', () async {
    final backend = _Backend();
    final repo = setup(backend.handle).repo;
    final iterator = StreamIterator(repo.watch(query()));
    addTearDown(iterator.cancel);
    await next(iterator);
    expect(
      (await repo.getById('missing') as Failure<Task>).failure.code,
      AppFailureCode.notFound,
    );
    expect(
      (await repo.update('missing', draft()) as Failure<Task>).failure.code,
      AppFailureCode.notFound,
    );
    expect(
      (await repo.setStatus(
        'missing',
        TaskStatus.completed,
      ) as Failure<Task>).failure.code,
      AppFailureCode.notFound,
    );
    expect(
      (await repo.delete('missing') as Failure<void>).failure.code,
      AppFailureCode.notFound,
    );
    await Future<void>.delayed(Duration.zero);
    expect(backend.listCalls, 1);
  });

  test(
    'List lỗi phát Failure, refresh thủ công phục hồi cùng subscription',
    () async {
      final backend = _Backend()..failLists = true;
      final repo = setup(backend.handle).repo;
      final iterator = StreamIterator(repo.watch(query()));
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isA<Failure<List<Task>>>());
      backend.failLists = false;
      repo.refresh();
      expect(await next(iterator), isEmpty);
    },
  );

  test(
    'Ghi thành công nhưng refresh lỗi vẫn trả Success cho thao tác ghi',
    () async {
      final backend = _Backend();
      final repo = setup(backend.handle).repo;
      final iterator = StreamIterator(repo.watch(query()));
      addTearDown(iterator.cancel);
      await next(iterator);
      backend.failLists = true;
      expect(await repo.create(draft()), isA<Success<Task>>());
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isA<Failure<List<Task>>>());
      backend.failLists = false;
      repo.refresh();
      expect((await next(iterator)).length, 1);
    },
  );

  test(
    'Không tự polling thay đổi ngoài repository; refresh thủ công lấy lại',
    () async {
      final backend = _Backend();
      final repo = setup(backend.handle).repo;
      final iterator = StreamIterator(repo.watch(query()));
      addTearDown(iterator.cancel);
      await next(iterator);
      backend.records['external'] = _fixture('external');
      await Future<void>.delayed(Duration.zero);
      expect(backend.listCalls, 1);
      repo.refresh();
      expect((await next(iterator)).single.id, 'external');
    },
  );

  test(
    'Response list cũ bị bỏ và nhiều invalidation đang chờ được gộp',
    () async {
      final backend = _Backend();
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      var getCount = 0;
      final repo = setup((request) {
        if (request.method == 'GET' && request.url.path == '/tasks') {
          getCount++;
          if (getCount == 1) {
            started.complete();
            return gate.future;
          }
        }
        return backend.handle(request);
      }).repo;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete(_json([]));
      });
      final events = <Result<List<Task>>>[];
      final received = Completer<void>();
      final subscription = repo.watch(query()).listen((event) {
        events.add(event);
        if (!received.isCompleted) received.complete();
      });
      addTearDown(subscription.cancel);
      await started.future;
      await Future.wait([
        repo.create(draft()),
        repo.create(draft()),
        repo.create(draft()),
      ]);
      gate.complete(_json([])); // snapshot từ trước khi ghi
      await received.future.timeout(const Duration(seconds: 3));
      expect(events.length, 1);
      expect((events.single as Success<List<Task>>).value.length, 3);
      expect(getCount, 2);
    },
  );

  test('Hủy subscriber trong lúc GET chờ bỏ response đến muộn và không refresh tiếp', () async {
    final backend = _Backend();
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    var gets = 0;
    final repo = setup((request) {
      if (request.method == 'GET' && request.url.path == '/tasks') {
        gets++;
        if (!started.isCompleted) started.complete();
        return gate.future;
      }
      return backend.handle(request);
    }).repo;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(_json([]));
    });
    final events = <Result<List<Task>>>[];
    final subscription = repo.watch(query()).listen(events.add);
    await started.future;
    await subscription.cancel();
    await repo.create(draft());
    repo.refresh();
    gate.complete(_json([]));
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    expect(gets, 1);
  });

  test(
    'Dispose đóng watcher đang chờ, bỏ response muộn và không đóng client',
    () async {
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      final harness = setup((request) {
        if (request.url.path == '/probe') {
          return Future.value(http.Response('', 200));
        }
        if (!started.isCompleted) started.complete();
        return gate.future;
      });
      addTearDown(() {
        if (!gate.isCompleted) gate.complete(_json([]));
      });
      final done = Completer<void>();
      final events = <Result<List<Task>>>[];
      harness.repo.watch(query()).listen(events.add, onDone: done.complete);
      await started.future;
      harness.repo.dispose();
      harness.repo.dispose();
      await done.future.timeout(const Duration(seconds: 1));
      gate.complete(_json([]));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      expect(
        (await harness.client.get(Uri.parse('https://example.test/probe')))
            .statusCode,
        200,
      );
    },
  );

  test('Dispose không chờ listener đang pause', () async {
    final backend = _Backend();
    final repo = setup(backend.handle).repo;
    final done = Completer<void>();
    final subscription = repo
        .watch(query())
        .listen((_) {}, onDone: done.complete);
    subscription.pause();
    repo.dispose();
    subscription.resume();
    await done.future.timeout(const Duration(seconds: 1));
    await subscription.cancel();
  });

  test(
    'Sau dispose mọi thao tác mới trả unavailable mà không gọi HTTP',
    () async {
      final backend = _Backend();
      final repo = setup(backend.handle).repo;
      final streamCreatedEarlier = repo.watch(query());
      repo.dispose();
      expect(
        (await repo.getById('id') as Failure<Task>).failure.code,
        AppFailureCode.unavailable,
      );
      expect(await repo.create(draft()), isA<Failure<Task>>());
      expect(await repo.update('id', draft()), isA<Failure<Task>>());
      expect(
        await repo.setStatus('id', TaskStatus.pending),
        isA<Failure<Task>>(),
      );
      expect(await repo.delete('id'), isA<Failure<void>>());
      expect(await repo.watch(query()).first, isA<Failure<List<Task>>>());
      expect(await streamCreatedEarlier.first, isA<Failure<List<Task>>>());
      repo.refresh();
      expect(backend.calls, isEmpty);
    },
  );

  test('Không gửi GET nếu tất cả subscription đã hủy', () async {
    final backend = _Backend();
    final repo = setup(backend.handle).repo;
    await repo.watch(query()).first;
    final count = backend.listCalls;
    await repo.create(draft());
    repo.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(backend.listCalls, count);
  });
}
