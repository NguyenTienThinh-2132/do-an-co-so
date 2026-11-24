import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_draft.dart';
import '../domain/repositories/task_repository.dart';

abstract class TaskFormController extends ChangeNotifier {
  TaskFormController({required this.repository});
  final TaskRepository repository;
  bool _saving = false;
  bool _disposed = false;
  AppFailure? _failure;
  bool get saving => _saving;
  AppFailure? get failure => _failure;

  void reset() {
    if (_disposed || _saving) return;
    _failure = null;
    notifyListeners();
  }

  bool get isDisposed => _disposed;
  Future<Result<Task>> persist(TaskDraft draft);
  Future<Task?> submit(TaskDraft draft) async {
    if (_disposed || _saving) return null;
    _saving = true;
    _failure = null;
    notifyListeners();
    Task? created;
    try {
      final result = await persist(draft);
      switch (result) {
        case Success<Task>(:final value):
          created = value;
        case Failure<Task>(:final failure):
          _failure = failure;
      }
    } catch (_) {
      _failure = const AppFailure(
        code: AppFailureCode.unavailable,
        message: 'Không thể lưu công việc.',
      );
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
    return _disposed ? null : created;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
