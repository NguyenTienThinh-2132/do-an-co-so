import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_query.dart';
import '../domain/repositories/task_repository.dart';
import 'tasks_list_state.dart';

/// Chủ sở hữu gọi load khi bắt đầu và dispose khi không dùng.
/// Không sở hữu/đóng repository hoặc HTTP client.
final class TasksListController extends ChangeNotifier {
  TasksListController({required this.repository, required TaskQuery query})
    : _state = TasksListState.initial(query);

  final TaskRepository repository;
  TasksListState _state;
  TasksListState get state => _state;
  StreamSubscription<Result<List<Task>>>? _subscription;
  int _generation = 0;
  bool _disposed = false;

  void load() => _subscribe(_state.query);
  void retry() => load();

  /// Bên gọi tính ranh giới ngày theo múi giờ đã chọn trước khi tạo query.
  void setQuery(TaskQuery query) => _subscribe(query);

  void _subscribe(TaskQuery query) {
    if (_disposed) return;
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    _cancel(previous);
    _state = TasksListState.loading(query);
    notifyListeners();
    // Listener có thể đổi query ngay trong notifyListeners.
    if (!_isCurrent(generation)) return;
    try {
      final subscription = repository
          .watch(query)
          .listen(
            (result) {
              if (!_isCurrent(generation)) return;
              _state = switch (result) {
                Success<List<Task>>(:final value) => TasksListState.ready(
                  query,
                  value,
                ),
                Failure<List<Task>>(:final failure) => TasksListState.error(
                  query,
                  failure,
                ),
              };
              notifyListeners();
            },
            onError: (Object error, StackTrace stack) {
              _fail(generation, query);
            },
            onDone: () {
              if (_isCurrent(generation) &&
                  _state.phase == TasksListPhase.loading) {
                _fail(generation, query);
              }
            },
          );
      // Bảo vệ cả stream tùy chỉnh phát đồng bộ trong listen.
      if (_isCurrent(generation)) {
        _subscription = subscription;
      } else {
        _cancel(subscription);
      }
    } catch (_) {
      _fail(generation, query);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _fail(int generation, TaskQuery query) {
    if (!_isCurrent(generation)) return;
    _state = TasksListState.error(
      query,
      const AppFailure(
        code: AppFailureCode.unavailable,
        message: 'Không thể tải danh sách công việc.',
      ),
    );
    notifyListeners();
  }

  void _cancel(StreamSubscription<Result<List<Task>>>? subscription) {
    if (subscription == null) return;
    // Cancellation không được làm lỗi thoát khỏi vòng đời widget/controller.
    unawaited(subscription.cancel().catchError((Object _) {}));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _cancel(_subscription);
    _subscription = null;
    super.dispose();
  }
}
