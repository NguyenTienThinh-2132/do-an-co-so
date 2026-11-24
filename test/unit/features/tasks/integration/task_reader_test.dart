import 'dart:async';
import 'dart:convert';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/ports/task_dto.dart';
import 'package:finai/features/tasks/domain/ports/task_reader.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:finai/features/tasks/integration/fake_task_reader.dart';
import 'package:finai/features/tasks/integration/repository_task_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

DateTime time(int hour) => DateTime.utc(2026, 11, 7, hour);
Task task(
  String id,
  int start,
  int end, {
  String title = 'Học Flutter',
  TaskStatus status = TaskStatus.pending,
  TaskPriority priority = TaskPriority.medium,
}) => Task(
  id: id,
  title: title,
  description: 'Mô tả',
  categoryId: 'category',
  startAt: time(start),
  endAt: time(end),
  priority: priority,
  status: status,
  createdAt: time(0),
  updatedAt: time(1),
);
Map<String, Object?> json(Task t) => {
  'id': t.id,
  'title': t.title,
  'description': t.description,
  'categoryId': t.categoryId,
  'startAt': t.startAt.toIso8601String(),
  'endAt': t.endAt.toIso8601String(),
  'priority': t.priority.name,
  'status': t.status.name,
  'createdAt': t.createdAt.toIso8601String(),
  'updatedAt': t.updatedAt.toIso8601String(),
};

class StreamRepository implements TaskRepository {
  StreamRepository(this.source);
  final Stream<Result<List<Task>>> Function(TaskQuery) source;
  @override
  Stream<Result<List<Task>>> watch(TaskQuery query) => source(query);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final fixtures = [
    task('b', 10, 11),
    task('after', 12, 13),
    task('a', 10, 12, priority: TaskPriority.high),
    task('span', 8, 13, title: 'HỌC kế hoạch', status: TaskStatus.completed),
    task('before', 8, 9),
    task('literal', 11, 12, title: 'Học 100%_Flutter'),
  ];
  final scenarios = <({String name, TaskQuery query, List<String> ids})>[
    (
      name: 'overlap và startAt/id',
      query: TaskQuery(start: time(9), end: time(12)),
      ids: ['span', 'a', 'b', 'literal'],
    ),
    (
      name: 'trạng thái',
      query: TaskQuery(
        start: time(9),
        end: time(12),
        status: TaskStatus.completed,
      ),
      ids: ['span'],
    ),
    (
      name: 'ưu tiên',
      query: TaskQuery(
        start: time(9),
        end: time(12),
        priority: TaskPriority.high,
      ),
      ids: ['a'],
    ),
    (
      name: 'trim và hoa thường',
      query: TaskQuery(start: time(9), end: time(12), searchText: '  hỌc  '),
      ids: ['span', 'a', 'b', 'literal'],
    ),
    (
      name: 'phân biệt dấu',
      query: TaskQuery(start: time(9), end: time(12), searchText: 'hoc'),
      ids: [],
    ),
    (
      name: 'ký tự literal',
      query: TaskQuery(start: time(9), end: time(12), searchText: '%_'),
      ids: ['literal'],
    ),
    (
      name: 'AND',
      query: TaskQuery(
        start: time(9),
        end: time(12),
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        searchText: 'Flutter',
      ),
      ids: ['a'],
    ),
    (name: 'rỗng', query: TaskQuery(start: time(15), end: time(16)), ids: []),
    (
      name: 'offset UTC',
      query: TaskQuery(
        start: DateTime.parse('2026-11-07T16:00:00+07:00'),
        end: DateTime.parse('2026-11-07T19:00:00+07:00'),
      ),
      ids: ['span', 'a', 'b', 'literal'],
    ),
  ];
  for (final scenario in scenarios) {
    test('fake/HTTP adapter: ${scenario.name}', () async {
      var requests = 0;
      // HTTP mock dùng đáp án kỳ vọng, không phải backend thật.
      final client = MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/tasks');
        expect(request.url.queryParameters, {
          'start': scenario.query.start.toIso8601String(),
          'end': scenario.query.end.toIso8601String(),
          if (scenario.query.status != null)
            'status': scenario.query.status!.name,
          if (scenario.query.priority != null)
            'priority': scenario.query.priority!.name,
          if (scenario.query.searchText.isNotEmpty)
            'searchText': scenario.query.searchText,
        });
        final response = scenario.ids
            .map((id) => json(fixtures.singleWhere((t) => t.id == id)))
            .toList();
        return http.Response.bytes(utf8.encode(jsonEncode(response)), 200);
      });
      final repository = HttpTaskRepository(
        datasource: TaskRemoteDatasource(
          client: client,
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
        ),
      );
      addTearDown(() {
        repository.dispose();
        client.close();
      });
      final readers = <TaskReader>[
        FakeTaskReader(fixtures: fixtures.map(TaskDto.fromTask)),
        RepositoryTaskReader(repository: repository),
      ];
      for (final reader in readers) {
        final result = await reader.getTasks(scenario.query);
        expect(result, isA<Success<List<TaskDto>>>());
        final values = (result as Success<List<TaskDto>>).value;
        expect(values.map((t) => t.id), scenario.ids);
        expect(() => values.clear(), throwsUnsupportedError);
        for (final dto in values) {
          final original = fixtures.singleWhere((t) => t.id == dto.id);
          expect({
            'id': dto.id,
            'title': dto.title,
            'description': dto.description,
            'categoryId': dto.categoryId,
            'startAt': dto.startAt.toIso8601String(),
            'endAt': dto.endAt.toIso8601String(),
            'priority': dto.priority.name,
            'status': dto.status.name,
            'createdAt': dto.createdAt.toIso8601String(),
            'updatedAt': dto.updatedAt.toIso8601String(),
          }, json(original));
          expect(dto.startAt.isUtc && dto.endAt.isUtc, isTrue);
        }
      }
      expect(requests, 1);
    });
  }
  final query = TaskQuery(start: time(9), end: time(12));
  test('chuyển nguyên Failure và hủy subscription', () async {
    const failure = AppFailure(
      code: AppFailureCode.permissionDenied,
      message: 'Từ chối',
    );
    var cancelled = false;
    final controller = StreamController<Result<List<Task>>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final reader = RepositoryTaskReader(
      repository: StreamRepository((received) {
        expect(identical(received, query), isTrue);
        return controller.stream;
      }),
    );
    final pending = reader.getTasks(query);
    controller.add(const Failure(failure));
    final result = await pending;
    expect((result as Failure<List<TaskDto>>).failure, same(failure));
    expect(cancelled, isTrue);
    await controller.close();
  });
  test('chỉ lấy sự kiện đầu và hủy subscription', () async {
    var cancelled = false;
    final controller = StreamController<Result<List<Task>>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final reader = RepositoryTaskReader(
      repository: StreamRepository((_) => controller.stream),
    );
    final pending = reader.getTasks(query);
    controller.add(Success([fixtures.first]));
    controller.add(const Success([]));
    final result = await pending as Success<List<TaskDto>>;
    expect(result.value.single.id, fixtures.first.id);
    expect(cancelled, isTrue);
    await controller.close();
  });
  test('stream đóng trước dữ liệu trả unavailable', () async {
    final reader = RepositoryTaskReader(
      repository: StreamRepository((_) => const Stream.empty()),
    );
    final result = await reader.getTasks(query) as Failure<List<TaskDto>>;
    expect(result.failure.code, AppFailureCode.unavailable);
  });
  test('stream exception không lộ nội dung lỗi', () async {
    final reader = RepositoryTaskReader(
      repository: StreamRepository(
        (_) => Stream.error(StateError('sensitive details')),
      ),
    );
    final result = await reader.getTasks(query) as Failure<List<TaskDto>>;
    expect(result.failure.code, AppFailureCode.unavailable);
    expect(result.failure.message, isNot(contains('sensitive')));
  });
  test('fake sao chép fixture và không thay đổi giữa các lần đọc', () async {
    final input = [TaskDto.fromTask(fixtures.first)];
    final reader = FakeTaskReader(fixtures: input);
    input.clear();
    for (var i = 0; i < 2; i++) {
      final result = await reader.getTasks(query) as Success<List<TaskDto>>;
      expect(result.value.single.id, 'b');
    }
  });
  test('fixture mặc định cố định và sắp xếp', () async {
    final result = await FakeTaskReader().getTasks(
      TaskQuery(start: time(0), end: DateTime.utc(2026, 11, 8)),
    ) as Success<List<TaskDto>>;
    expect(result.value.map((t) => t.id), [
      'demo-task-1',
      'demo-task-2',
      'demo-task-3',
    ]);
  });
}
