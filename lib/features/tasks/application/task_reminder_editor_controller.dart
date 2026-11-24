import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_status.dart';
import '../domain/ports/task_reminder_port.dart';

class TaskReminderEditorController extends ChangeNotifier {
  TaskReminderEditorController({
    required this.port,
    required DateTime initialAt,
    DateTime Function()? now,
  }) : at = initialAt.toLocal(),
       _now = now ?? DateTime.now;
  final TaskReminderPort? port;
  final DateTime Function() _now;
  bool enabled = false;
  DateTime at;
  bool loading = false;
  bool saving = false;
  bool saved = false;
  AppFailure? failure;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setEnabled(bool value) {
    enabled = value;
    saved = false;
    failure = null;
    _notify();
  }

  void setAt(DateTime value) {
    at = value.toLocal();
    saved = false;
    failure = null;
    _notify();
  }

  Future<void> load(String id, DateTime fallback) async {
    if (port == null || _disposed) return;
    loading = true;
    _notify();
    final result = await port!.getReminder(id);
    if (_disposed) return;
    switch (result) {
      case Success<TaskReminder?>(:final value):
        enabled = value != null && !value.fired;
        at = (value?.triggerAt ?? fallback).toLocal();
      case Failure<TaskReminder?>(:final failure):
        this.failure = failure;
    }
    loading = false;
    _notify();
  }

  Future<void> notificationPermission() async {
    if (port == null) return;
    final result = await port!.requestNotifications();
    if (result case Failure<bool>(failure: final error)) {
      failure = error;
    }
    if (result is Success<bool>) {
      failure = result.value
          ? null
          : const AppFailure(
              code: AppFailureCode.permissionDenied,
              message: 'Chưa cấp quyền thông báo.',
            );
    }
    _notify();
  }

  Future<void> exactSettings() async {
    if (port == null) return;
    final result = await port!.openExactAlarmSettings();
    if (result case Failure<void>(failure: final error)) {
      failure = error;
    }
    _notify();
  }

  Future<Result<void>> apply(Task task) async {
    if (saving || _disposed) {
      return const Failure(
        AppFailure(
          code: AppFailureCode.conflict,
          message: 'Đang lưu nhắc việc.',
        ),
      );
    }
    if (!enabled && port == null) return const Success<void>(null);
    if (port == null) {
      return const Failure(
        AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Nhắc việc cần Android.',
        ),
      );
    }
    if (enabled &&
        (task.status == TaskStatus.completed || !at.isAfter(_now()))) {
      failure = const AppFailure(
        code: AppFailureCode.validation,
        message:
            'Chọn thời điểm trong tương lai cho công việc chưa hoàn thành.',
      );
      _notify();
      return Failure(failure!);
    }
    saving = true;
    saved = false;
    failure = null;
    _notify();
    Result<void> result;
    try {
      result = enabled
          ? await port!.schedule(
              TaskReminder(
                taskId: task.id,
                title: task.title,
                triggerAt: at,
                taskStartAt: task.startAt,
              ),
            )
          : await port!.cancel(task.id);
    } catch (_) {
      result = const Failure(
        AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Chưa lưu được nhắc việc.',
        ),
      );
    }
    if (!_disposed) {
      saving = false;
      if (result case Failure<void>(:final failure)) {
        this.failure = failure;
      }
      saved = result is Success<void>;
      _notify();
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
