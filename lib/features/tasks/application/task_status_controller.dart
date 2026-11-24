import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_status.dart';
import '../domain/repositories/task_repository.dart';

/// Chỉ điều phối ghi trạng thái; dữ liệu hiển thị vẫn từ repository.watch.
class TaskStatusController extends ChangeNotifier {
  TaskStatusController({required this.repository});
  final TaskRepository repository;
  final Set<String> _busy = {};
  final Map<String, AppFailure> _failures = {};
  final Map<String, TaskStatus> _targets = {};
  bool _disposed = false;

  bool isSaving(String id) => _busy.contains(id);
  AppFailure? failureFor(String id) => _failures[id];

  Future<bool> retry(String id) {
    final target = _targets[id];
    return target == null ? Future.value(false) : setStatus(id, target);
  }

  Future<bool> setStatus(String id, TaskStatus status) async {
    if (_disposed || !_busy.add(id)) return false;
    _targets[id] = status;
    _failures.remove(id);
    notifyListeners();
    var success = false;
    try {
      final result = await repository.setStatus(id, status);
      if (_disposed) return false;
      switch (result) {
        case Success<Task>():
          success = true;
          _targets.remove(id);
        case Failure<Task>(:final failure):
          _failures[id] = failure;
      }
    } catch (_) {
      if (!_disposed) {
        _failures[id] = const AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Không thể cập nhật trạng thái.',
        );
      }
    } finally {
      _busy.remove(id);
      if (!_disposed) notifyListeners();
    }
    return !_disposed && success;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
