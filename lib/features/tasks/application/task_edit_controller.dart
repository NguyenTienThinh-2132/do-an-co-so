import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_draft.dart';
import 'task_form_controller.dart';

class TaskEditController extends TaskFormController {
  TaskEditController({required super.repository, required this.taskId});
  final String taskId;
  Task? _task;
  Task? get task => _task;
  bool _loading = false;
  bool get loading => _loading;
  AppFailure? _loadFailure;
  AppFailure? get loadFailure => _loadFailure;
  int _generation = 0;

  Future<void> load() async {
    if (isDisposed || saving) return;
    final generation = ++_generation;
    _loading = true;
    _task = null;
    _loadFailure = null;
    notifyListeners();
    try {
      final result = await repository.getById(taskId);
      if (isDisposed || generation != _generation) return;
      switch (result) {
        case Success<Task>(:final value):
          _task = value;
        case Failure<Task>(:final failure):
          _loadFailure = failure;
      }
    } catch (_) {
      if (isDisposed || generation != _generation) return;
      _loadFailure = const AppFailure(
        code: AppFailureCode.unavailable,
        message: 'Không thể tải công việc.',
      );
    } finally {
      if (!isDisposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  Future<Result<Task>> persist(TaskDraft draft) async {
    if (_task == null || loading) {
      return const Failure(
        AppFailure(
          code: AppFailureCode.validation,
          message: 'Cần tải công việc trước khi sửa.',
        ),
      );
    }
    final result = await repository.update(taskId, draft);
    if (result case Success<Task>(:final value)) _task = value;
    return result;
  }
}
