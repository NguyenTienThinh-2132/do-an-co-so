import 'package:flutter/services.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../../tasks/domain/ports/task_reminder_port.dart';
import '../domain/native_event.dart';
import '../domain/native_inbox_port.dart';

class AndroidTV3Bridge implements NativeInboxPort, TaskReminderPort {
  const AndroidTV3Bridge();
  static const method = MethodChannel('finai/tv3/native');
  static const events = EventChannel('finai/tv3/incoming');
  static final _incoming = events.receiveBroadcastStream().map(
    NativeEvent.fromPlatform,
  );

  Future<Result<T>> _call<T>(
    String name,
    Map<String, Object?>? args,
    T Function(Object?) decode,
  ) async {
    try {
      return Success(decode(await method.invokeMethod<Object?>(name, args)));
    } on PlatformException catch (e) {
      return Failure(
        AppFailure(
          code: e.code == 'permissionDenied'
              ? AppFailureCode.permissionDenied
              : e.code == 'validation'
              ? AppFailureCode.validation
              : AppFailureCode.unavailable,
          message: 'Chưa thực hiện được thao tác Native. Kiểm tra quyền và thiết bị.',
        ),
      );
    } catch (_) {
      return Failure(
        AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Chức năng này cần Android và kết nối Native.',
        ),
      );
    }
  }

  @override
  Future<Result<bool>> isAccessGranted() =>
      _call('isAccessGranted', null, (v) => v as bool);
  @override
  Future<Result<void>> openAccessSettings() =>
      _call<void>('openAccessSettings', null, (_) {});
  @override
  Stream<NativeEvent> watchIncoming() => _incoming;
  @override
  Future<Result<List<NativeEvent>>> getPending() => _call(
    'getPending',
    null,
    (v) => List<NativeEvent>.unmodifiable(
      (v as List).map(NativeEvent.fromPlatform),
    ),
  );
  @override
  Future<Result<void>> acknowledge(List<String> ids) =>
      _call<void>('acknowledge', {'ids': ids}, (_) {});
  @override
  Future<Result<void>> setAllowedPackages(List<String> packages) =>
      _call<void>('setAllowedPackages', {'packages': packages}, (_) {});
  @override
  Future<Result<bool>> canNotify() =>
      _call('canNotify', null, (v) => v as bool);
  @override
  Future<Result<bool>> requestNotifications() =>
      _call('requestNotifications', null, (v) => v as bool);
  @override
  Future<Result<bool>> canScheduleExact() =>
      _call('canScheduleExact', null, (v) => v as bool);
  @override
  Future<Result<void>> openExactAlarmSettings() =>
      _call<void>('openExactAlarmSettings', null, (_) {});
  @override
  Future<Result<void>> schedule(TaskReminder reminder) =>
      _call<void>('scheduleTaskReminder', {
        'taskId': reminder.taskId,
        'title': reminder.title,
        'triggerAt': reminder.triggerAt.millisecondsSinceEpoch,
        'taskStartAt': reminder.taskStartAt?.toUtc().millisecondsSinceEpoch,
      }, (_) {});
  @override
  Future<Result<void>> cancel(String taskId) =>
      _call<void>('cancelTaskReminder', {'taskId': taskId}, (_) {});
  @override
  Future<Result<TaskReminder?>> getReminder(String taskId) =>
      _call('getTaskReminder', {'taskId': taskId}, (v) {
        if (v == null) return null;
        final map = Map<String, Object?>.from(v as Map);
        return TaskReminder(
          taskId: map['taskId'] as String,
          title: map['title'] as String,
          triggerAt: DateTime.fromMillisecondsSinceEpoch(
            map['triggerAt'] as int,
            isUtc: true,
          ),
          fired: map['fired'] as bool,
          taskStartAt: map['taskStartAt'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  map['taskStartAt'] as int,
                  isUtc: true,
                ),
        );
      });
}
