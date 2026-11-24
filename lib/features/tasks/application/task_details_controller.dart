import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/repositories/task_repository.dart';

class TaskDetailsController extends ChangeNotifier {
  TaskDetailsController({required this.repository, required this.taskId});
  final TaskRepository repository;
  final String taskId;
  Task? _task;
  Task? get task => _task;
  bool _loading = false;
  bool get loading => _loading;
  AppFailure? _failure;
  AppFailure? get failure => _failure;
  bool _disposed = false;
  int _generation = 0;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _task = null;
    _failure = null;
    notifyListeners();
    try {
      final result = await repository.getById(taskId);
      if (_disposed || generation != _generation) return;
      switch (result) {
        case Success<Task>(:final value):
          _task = value;
        case Failure<Task>(:final failure):
          _failure = failure;
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _failure = const AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Không thể tải chi tiết công việc.',
        );
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
