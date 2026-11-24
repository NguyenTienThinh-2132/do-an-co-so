import 'dart:async';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/tasks_list_controller.dart';
import 'package:finai/features/tasks/application/tasks_list_state.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositoryStub implements TaskRepository {
  final queries = <TaskQuery>[];
  final streams = <StreamController<Result<List<Task>>>>[];
  var cancellations = 0;
  bool throwOnWatch = false;
  @override
  Stream<Result<List<Task>>> watch(TaskQuery query) {
    queries.add(query);
    if (throwOnWatch) throw StateError('private details');
    final stream = StreamController<Result<List<Task>>>(
      onCancel: () {
        cancellations++;
      },
    );
    streams.add(stream);
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  Future<void> close() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}

TaskQuery day(int value) => TaskQuery(
  start: DateTime.utc(2026, 11, value),
  end: DateTime.utc(2026, 11, value + 1),
);
Task fixture() => Task(
  id: 'one',
  title: 'Công việc',
  startAt: DateTime.utc(2026, 11, 7, 9),
  endAt: DateTime.utc(2026, 11, 7, 10),
  priority: TaskPriority.high,
  status: TaskStatus.pending,
  createdAt: DateTime.utc(2026, 11, 7),
  updatedAt: DateTime.utc(2026, 11, 7),
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late RepositoryStub repository;
  late TasksListController controller;
  setUp(() {
    repository = RepositoryStub();
    controller = TasksListController(repository: repository, query: day(7));
  });
  tearDown(() async {
    controller.dispose();
    await repository.close();
  });

  test('khởi tạo chưa tự truy vấn, load phát loading rồi ready', () async {
    expect(controller.state.phase, TasksListPhase.initial);
    expect(repository.queries, isEmpty);
    final phases = <TasksListPhase>[];
    controller.addListener(() {
      phases.add(controller.state.phase);
    });
    controller.load();
    expect(controller.state.phase, TasksListPhase.loading);
    repository.streams.single.add(Success([fixture()]));
    await flush();
    expect(phases, [TasksListPhase.loading, TasksListPhase.ready]);
    expect(controller.state.tasks.single.id, 'one');
    expect(controller.state.failure, isNull);
  });

  test('empty chỉ đúng sau Success rỗng, snapshot bất biến', () async {
    expect(controller.state.isEmpty, isFalse);
    controller.load();
    expect(controller.state.isEmpty, isFalse);
    final input = <Task>[];
    repository.streams.single.add(Success(input));
    await flush();
    expect(controller.state.isEmpty, isTrue);
    input.add(fixture());
    expect(controller.state.tasks, isEmpty);
    expect(() => controller.state.tasks.add(fixture()), throwsUnsupportedError);
  });

  test('stream phát tiếp thì dữ liệu cập nhật', () async {
    controller.load();
    repository.streams.single.add(Success([fixture()]));
    await flush();
    repository.streams.single.add(const Success([]));
    await flush();
    expect(controller.state.isEmpty, isTrue);
  });

  test('Failure giữ nguyên và retry tạo subscription mới', () async {
    const failure = AppFailure(
      code: AppFailureCode.permissionDenied,
      message: 'Từ chối',
    );
    controller.load();
    final query = repository.queries.single;
    repository.streams.single.add(const Failure(failure));
    await flush();
    expect(controller.state.failure, same(failure));
    expect(controller.state.phase, TasksListPhase.error);
    controller.retry();
    expect(controller.state.phase, TasksListPhase.loading);
    expect(controller.state.failure, isNull);
    expect(repository.queries.last, same(query));
    expect(repository.cancellations, 1);
    repository.streams.last.add(Success([fixture()]));
    await flush();
    expect(controller.state.phase, TasksListPhase.ready);
  });

  test('đổi ngày hủy lượt cũ và bỏ response đã xếp hàng', () async {
    controller.load();
    repository.streams.single.add(Success([fixture()]));
    final next = day(8);
    controller.setQuery(next);
    await flush();
    expect(controller.state.query, same(next));
    expect(controller.state.phase, TasksListPhase.loading);
    expect(controller.state.tasks, isEmpty);
    expect(repository.cancellations, 1);
    repository.streams.last.add(const Success([]));
    await flush();
    expect(controller.state.isEmpty, isTrue);
  });

  test('giữ nguyên query với bộ lọc và ranh giới offset', () {
    final query = TaskQuery(
      start: DateTime.parse('2026-11-07T00:00:00+07:00'),
      end: DateTime.parse('2026-11-08T00:00:00+07:00'),
      status: TaskStatus.completed,
      priority: TaskPriority.low,
      searchText: ' Flutter ',
    );
    controller.setQuery(query);
    expect(repository.queries.single, same(query));
    expect(controller.state.query.start, DateTime.utc(2026, 11, 6, 17));
  });

  test('exception từ stream thành unavailable không lộ chi tiết', () async {
    controller.load();
    repository.streams.single.addError(StateError('private details'));
    await flush();
    expect(controller.state.failure!.code, AppFailureCode.unavailable);
    expect(controller.state.failure!.message, isNot(contains('private')));
  });

  test('watch ném đồng bộ thành error và retry phục hồi', () async {
    repository.throwOnWatch = true;
    controller.load();
    expect(controller.state.phase, TasksListPhase.error);
    repository.throwOnWatch = false;
    controller.retry();
    repository.streams.single.add(const Success([]));
    await flush();
    expect(controller.state.isEmpty, isTrue);
  });

  test('stream đóng trước dữ liệu không treo loading', () async {
    controller.load();
    await repository.streams.single.close();
    expect(controller.state.failure!.code, AppFailureCode.unavailable);
  });

  test('stream đóng sau Success giữ snapshot cuối', () async {
    controller.load();
    repository.streams.single.add(Success([fixture()]));
    await repository.streams.single.close();
    expect(controller.state.phase, TasksListPhase.ready);
    expect(controller.state.tasks.single.id, 'one');
  });

  test('dispose hủy, không notify hoặc truy vấn sau dispose', () async {
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });
    controller.load();
    repository.streams.single.add(Success([fixture()]));
    controller.dispose();
    await flush();
    controller.load();
    controller.retry();
    controller.setQuery(day(8));
    controller.dispose();
    expect(notifications, 1);
    expect(repository.queries, hasLength(1));
    expect(repository.cancellations, 1);
  });

  test('listener đổi query khi loading chỉ mở lượt mới nhất', () {
    var changed = false;
    final next = day(8);
    controller.addListener(() {
      if (!changed) {
        changed = true;
        controller.setQuery(next);
      }
    });
    controller.load();
    expect(repository.queries, [next]);
    expect(controller.state.query, same(next));
  });
}
