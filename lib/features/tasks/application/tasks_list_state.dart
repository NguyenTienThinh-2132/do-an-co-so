import '../../../core/types/app_failure.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_query.dart';

enum TasksListPhase { initial, loading, ready, error }

/// Một snapshot bất biến. Empty là ready với danh sách rỗng.
final class TasksListState {
  TasksListState.initial(this.query)
    : phase = TasksListPhase.initial,
      tasks = const [],
      failure = null;

  TasksListState.loading(this.query)
    : phase = TasksListPhase.loading,
      tasks = const [],
      failure = null;

  TasksListState.ready(this.query, Iterable<Task> tasks)
    : phase = TasksListPhase.ready,
      tasks = List<Task>.unmodifiable(tasks),
      failure = null;

  TasksListState.error(this.query, this.failure)
    : phase = TasksListPhase.error,
      tasks = const [];

  final TaskQuery query;
  final TasksListPhase phase;
  final List<Task> tasks;
  final AppFailure? failure;

  bool get isEmpty => phase == TasksListPhase.ready && tasks.isEmpty;
}
