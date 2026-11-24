import 'dart:async';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/task_status_controller.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class StatusStub implements TaskRepository {
  final calls = <(String, TaskStatus)>[];
  final pending = <Completer<Result<Task>>>[];
  bool throwOnCall = false;
  @override
  Future<Result<Task>> setStatus(String id, TaskStatus status) {
    calls.add((id, status));
    if (throwOnCall) throw StateError('private details');
    final completer = Completer<Result<Task>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Task task(String id) => Task(
  id: id,
  title: 'Test',
  startAt: DateTime.utc(2026, 11, 8, 9),
  endAt: DateTime.utc(2026, 11, 8, 10),
  priority: TaskPriority.medium,
  status: TaskStatus.completed,
  createdAt: DateTime.utc(2026, 11, 8),
  updatedAt: DateTime.utc(2026, 11, 8),
);
void main() {
  late StatusStub repo;
  late TaskStatusController controller;
  setUp(() {
    repo = StatusStub();
    controller = TaskStatusController(repository: repo);
  });
  tearDown(() {
    controller.dispose();
  });

  test('khóa cùng ID khi đang ghi, trả Success rồi mở khóa', () async {
    final pending = controller.setStatus('one', TaskStatus.completed);
    expect(controller.isSaving('one'), isTrue);
    expect(await controller.setStatus('one', TaskStatus.pending), isFalse);
    expect(repo.calls, [('one', TaskStatus.completed)]);
    repo.pending.single.complete(Success(task('one')));
    expect(await pending, isTrue);
    expect(controller.isSaving('one'), isFalse);
    expect(controller.failureFor('one'), isNull);
    expect(await controller.retry('one'), isFalse);
  });

  test('Failure giữ nguyên, retry đúng ID và trạng thái đã yêu cầu', () async {
    const failure = AppFailure(
      code: AppFailureCode.notFound,
      message: 'Missing',
    );
    final pending = controller.setStatus('one', TaskStatus.inProgress);
    repo.pending.single.complete(const Failure(failure));
    expect(await pending, isFalse);
    expect(controller.failureFor('one'), same(failure));
    final retry = controller.retry('one');
    expect(repo.calls.last, ('one', TaskStatus.inProgress));
    expect(controller.failureFor('one'), isNull);
    repo.pending.last.complete(Success(task('one')));
    expect(await retry, isTrue);
  });

  test('công việc khác nhau có trạng thái ghi độc lập', () async {
    final a = controller.setStatus('a', TaskStatus.completed);
    final b = controller.setStatus('b', TaskStatus.pending);
    expect(controller.isSaving('a') && controller.isSaving('b'), isTrue);
    repo.pending[0].complete(Success(task('a')));
    await a;
    expect(controller.isSaving('a'), isFalse);
    expect(controller.isSaving('b'), isTrue);
    repo.pending[1].complete(Success(task('b')));
    await b;
  });

  test('exception thành unavailable không lộ nội dung', () async {
    repo.throwOnCall = true;
    expect(await controller.setStatus('one', TaskStatus.completed), isFalse);
    expect(controller.failureFor('one')!.code, AppFailureCode.unavailable);
    expect(controller.failureFor('one')!.message, isNot(contains('private')));
  });

  test('dispose bỏ notify muộn và không nhận thao tác mới', () async {
    var count = 0;
    controller.addListener(() {
      count++;
    });
    final pending = controller.setStatus('one', TaskStatus.completed);
    controller.dispose();
    repo.pending.single.complete(Success(task('one')));
    expect(await pending, isFalse);
    expect(count, 1);
    expect(await controller.setStatus('two', TaskStatus.pending), isFalse);
    expect(repo.calls, hasLength(1));
  });
}
