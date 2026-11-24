import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_draft.dart';
import '../domain/entities/task_query.dart';
import '../domain/entities/task_status.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/ports/task_reminder_port.dart';

/// Sau khi HTTP ghi thành công, lỗi Native chỉ là warning, không biến thành
/// lỗi ghi Task để tránh retry tạo/sửa dữ liệu đã được server chấp nhận.
class TaskReminderCoordinator extends ChangeNotifier {
  TaskReminderCoordinator({required this.port});
  final TaskReminderPort port;
  final Map<String, AppFailure> _warnings = {};
  bool _disposed = false;
  final Map<String, Future<void> Function()> _retry = {};
  bool _retrying = false;
  bool get hasWarnings => _warnings.isNotEmpty;
  Future<void> retryAll() async {
    if (_retrying || _disposed) return;
    _retrying = true;
    try {
      for (final action in _retry.values.toList()) {
        await action();
      }
    } finally {
      _retrying = false;
    }
  }

  AppFailure? warningFor(String id) => _warnings[id];
  void _record(String id, Result<void> result) {
    if (_disposed) return;
    switch (result) {
      case Success<void>():
        _retry.remove(id);
        _warnings.remove(id);
      case Failure<void>(:final failure):
        _warnings[id] = failure;
    }
    notifyListeners();
  }

  Future<void> cancel(String id) async {
    _retry[id] = () => cancel(id);
    try {
      _record(id, await port.cancel(id));
    } catch (_) {
      _record(
        id,
        const Failure(
          AppFailure(
            code: AppFailureCode.unavailable,
            message: 'Chưa hủy được nhắc việc cục bộ.',
          ),
        ),
      );
    }
  }

  Future<void> update(Task old, Task task) async {
    _retry[task.id] = () => update(old, task);
    if (task.status == TaskStatus.completed) {
      await cancel(task.id);
      return;
    }
    try {
      final result = await port.getReminder(task.id);
      switch (result) {
        case Failure<TaskReminder?>(:final failure):
          _record(task.id, Failure(failure));
        case Success<TaskReminder?>(:final value):
          if (value == null || value.fired) {
            _record(task.id, const Success<void>(null));
            return;
          }
          final at = value.triggerAt.add(
            task.startAt.difference(value.taskStartAt ?? old.startAt),
          );
          if (!at.isAfter(DateTime.now())) {
            await cancel(task.id);
            return;
          }
          _record(
            task.id,
            await port.schedule(
              TaskReminder(
                taskId: task.id,
                title: task.title,
                triggerAt: at,
                taskStartAt: task.startAt,
              ),
            ),
          );
      }
    } catch (_) {
      _record(
        task.id,
        const Failure(
          AppFailure(
            code: AppFailureCode.unavailable,
            message: 'Chưa cập nhật được nhắc việc cục bộ.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ReminderTaskRepository implements TaskRepository {
  ReminderTaskRepository({required this.delegate, required this.reminders});
  final TaskRepository delegate;
  final TaskReminderCoordinator reminders;
  @override
  Stream<Result<List<Task>>> watch(TaskQuery query) => delegate.watch(query);
  @override
  Future<Result<Task>> getById(String id) => delegate.getById(id);
  @override
  Future<Result<Task>> create(TaskDraft draft) => delegate.create(draft);
  @override
  Future<Result<Task>> update(String id, TaskDraft draft) async {
    final old = await delegate.getById(id);
    if (old case Failure<Task>()) return old;
    final result = await delegate.update(id, draft);
    if (result case Success<Task>(:final value)) {
      await reminders.update((old as Success<Task>).value, value);
    }
    return result;
  }

  @override
  Future<Result<Task>> setStatus(String id, TaskStatus status) async {
    final result = await delegate.setStatus(id, status);
    if (result is Success<Task> && status == TaskStatus.completed) {
      await reminders.cancel(id);
    }
    return result;
  }

  @override
  Future<Result<void>> delete(String id) async {
    final result = await delegate.delete(id);
    if (result is Success<void> ||
        result is Failure<void> &&
            result.failure.code == AppFailureCode.notFound) {
      await reminders.cancel(id);
    }
    return result;
  }
}
