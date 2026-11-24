import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/core/types/app_failure.dart';
import 'package:finai/features/tasks/application/task_reminder_editor_controller.dart';
import 'package:finai/features/tasks/integration/reminder_task_repository.dart';
import 'package:finai/features/tasks/domain/ports/task_reminder_port.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';

class Reminders implements TaskReminderPort {
  TaskReminder? row;
  final scheduled = <TaskReminder>[];
  final cancelled = <String>[];
  bool fail = false;
  Completer<Result<void>>? gate;
  @override
  Future<Result<bool>> canNotify() async => const Success(true);
  @override
  Future<Result<bool>> requestNotifications() async => const Success(false);
  @override
  Future<Result<bool>> canScheduleExact() async => const Success(true);
  @override
  Future<Result<void>> openExactAlarmSettings() async => const Success(null);
  @override
  Future<Result<TaskReminder?>> getReminder(String id) async => Success(row);
  @override
  Future<Result<void>> schedule(TaskReminder r) async {
    scheduled.add(r);
    if (gate != null) return gate!.future;
    if (fail) {
      return const Failure(
        AppFailure(
          code: AppFailureCode.permissionDenied,
          message: 'No permission',
        ),
      );
    }
    row = r;
    return const Success(null);
  }

  @override
  Future<Result<void>> cancel(String id) async {
    cancelled.add(id);
    if (fail) {
      return const Failure(
        AppFailure(code: AppFailureCode.unavailable, message: 'Disconnected'),
      );
    }
    row = null;
    return const Success(null);
  }
}

Task task({int hour = 9, TaskStatus status = TaskStatus.pending}) => Task(
  id: 't1',
  title: 'Test',
  startAt: DateTime.utc(2099, 1, 1, hour),
  endAt: DateTime.utc(2099, 1, 1, hour + 1),
  priority: TaskPriority.medium,
  status: status,
  createdAt: DateTime.utc(2098),
  updatedAt: DateTime.utc(2098),
);
void main() {
  test(
    'chặn thời điểm quá khứ và task hoàn thành trước khi gọi Native',
    () async {
      final port = Reminders();
      final now = DateTime.utc(2099, 1, 1, 8);
      final c = TaskReminderEditorController(
        port: port,
        initialAt: now,
        now: () => now,
      )..setEnabled(true);
      expect(await c.apply(task()), isA<Failure<void>>());
      c.setAt(now.add(const Duration(minutes: 10)));
      expect(
        await c.apply(task(status: TaskStatus.completed)),
        isA<Failure<void>>(),
      );
      expect(port.scheduled, isEmpty);
      c.dispose();
    },
  );
  test(
    'lỗi Native thử lại được; giữ ID và mốc startAt; từ chối lưu đồng thời',
    () async {
      final port = Reminders()..fail = true;
      final c = TaskReminderEditorController(
        port: port,
        initialAt: DateTime.utc(2099, 1, 1, 8),
        now: () => DateTime.utc(2098),
      )..setEnabled(true);
      expect(await c.apply(task()), isA<Failure<void>>());
      expect(c.saved, isFalse);
      port.fail = false;
      port.gate = Completer<Result<void>>();
      final saving = c.apply(task());
      expect(await c.apply(task()), isA<Failure<void>>());
      port.gate!.complete(const Success(null));
      await saving;
      expect(c.saved, isTrue);
      expect(port.scheduled, hasLength(2));
      expect(port.scheduled.last.taskStartAt, task().startAt);
      c.dispose();
    },
  );
  test('tắt nhắc gọi cancel và từ chối quyền hiển thị lỗi rõ ràng', () async {
    final port = Reminders();
    final c = TaskReminderEditorController(
      port: port,
      initialAt: DateTime.utc(2099),
    );
    expect(await c.apply(task()), isA<Success<void>>());
    expect(port.cancelled, ['t1']);
    await c.notificationPermission();
    expect(c.failure!.code, AppFailureCode.permissionDenied);
    c.dispose();
  });
  test('sửa nhiều lần giữ khoảng nhắc trước startAt', () async {
    final port = Reminders()
      ..row = TaskReminder(
        taskId: 't1',
        title: 'Test',
        triggerAt: DateTime.utc(2099, 1, 1, 8, 45),
        taskStartAt: task().startAt,
      );
    final c = TaskReminderCoordinator(port: port);
    await c.update(task(), task(hour: 10));
    await c.update(task(hour: 10), task(hour: 11));
    expect(port.row!.triggerAt, DateTime.utc(2099, 1, 1, 10, 45));
    expect(port.row!.taskStartAt, task(hour: 11).startAt);
    c.dispose();
  });
  test('đồng bộ lỗi chỉ retry Native và dùng mốc gốc khi sửa tiếp', () async {
    final port = Reminders()
      ..row = TaskReminder(
        taskId: 't1',
        title: 'Test',
        triggerAt: DateTime.utc(2099, 1, 1, 8, 45),
        taskStartAt: task().startAt,
      )
      ..fail = true;
    final c = TaskReminderCoordinator(port: port);
    await c.update(task(), task(hour: 10));
    expect(c.hasWarnings, isTrue);
    port.fail = false;
    await c.update(task(hour: 10), task(hour: 11));
    expect(port.row!.triggerAt, DateTime.utc(2099, 1, 1, 10, 45));
    expect(c.hasWarnings, isFalse);
    port.fail = true;
    await c.cancel('t1');
    expect(c.hasWarnings, isTrue);
    port.fail = false;
    await c.retryAll();
    expect(c.hasWarnings, isFalse);
    expect(port.row, isNull);
    c.dispose();
  });
}
