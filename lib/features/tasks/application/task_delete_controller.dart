import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/repositories/task_repository.dart';

class TaskDeleteController extends ChangeNotifier {
  TaskDeleteController({required this.repository});
  final TaskRepository repository;
  final Set<String> _busy = {};
  final Map<String, AppFailure> _failures = {};
  bool _disposed = false;
  bool isDeleting(String id) => _busy.contains(id);
  AppFailure? failureFor(String id) => _failures[id];

  /// Bên gọi nhận xác nhận người dùng trước khi gọi.
  Future<bool> delete(String id) async {
    if (_disposed || !_busy.add(id)) return false;
    _failures.remove(id);
    notifyListeners();
    var success = false;
    try {
      final result = await repository.delete(id);
      if (_disposed) return false;
      switch (result) {
        case Success<void>():
          success = true;
        case Failure<void>(:final failure):
          _failures[id] = failure;
      }
    } catch (_) {
      if (!_disposed) {
        _failures[id] = const AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Không thể xóa công việc.',
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
