import 'dart:async';
import 'dart:convert';

import '../../../../core/cache/cache_entry.dart';
import '../../../../core/cache/response_cache.dart';
import '../datasources/task_availability_failure.dart';
import '../mappers/task_api_mapper.dart';

import '../../../../core/types/app_failure.dart';
import '../../../../core/types/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_remote_datasource.dart';

/// API is authoritative. Optional injected cache stores exact list queries.
/// List reads try API first, then cache only on connection/timeout/5xx failures.
///
/// Stream tải lần đầu và sau các thao tác ghi thành công qua instance này.
/// Không nhận push đa thiết bị. Gọi [refresh] hoặc subscribe lại để tải thủ công.
/// Bên khởi tạo đóng HTTP client sau khi không còn dùng datasource.
class HttpTaskRepository implements TaskRepository {
  HttpTaskRepository({
    required this.datasource,
    this.cache,
    String? cacheNamespace,
  }) : _cacheNamespace = cacheNamespace {
    if (cache != null &&
        (cacheNamespace == null || cacheNamespace.trim().isEmpty)) {
      throw ArgumentError(
        'Cache requires an explicit server/account namespace.',
      );
    }
  }

  final TaskRemoteDatasource datasource;
  final ResponseCache? cache;
  final String? _cacheNamespace;
  Future<void> _cacheQueue = Future<void>.value();
  int _changeEpoch = 0;
  int _requestSequence = 0;
  final Map<String, int> _acceptedCacheSequence = {};
  bool _cacheInvalid = false;
  bool _permissionBlocked = false;

  /// Owner waits for accepted cache jobs before closing its SQLite connection.
  Future<void> get cacheSettled => _cacheQueue;

  CacheKey _key(TaskQuery query) {
    final parameters = TaskApiMapper.queryToParameters(query);
    final keys = parameters.keys.toList()..sort();
    return CacheKey(
      namespace: _cacheNamespace!,
      resource: 'tasks.list.v1',
      queryKey: jsonEncode({for (final key in keys) key: parameters[key]}),
    );
  }

  Future<void> _enqueueCache(Future<void> Function() action) {
    final next = _cacheQueue.then((_) async {
      try {
        await action();
      } catch (_) {
        /* Cache must not fail a successful API operation. */
      }
    });
    _cacheQueue = next;
    return next;
  }

  void _invalidateCache() {
    if (cache == null) return;
    _cacheInvalid = true;
    unawaited(
      _enqueueCache(() async {
        final result = await cache!.clearNamespace(_cacheNamespace!);
        if (result is Success<void>) _cacheInvalid = false;
      }),
    );
  }

  void _saveList(TaskQuery query, List<Task> tasks, int epoch, int sequence) {
    if (cache == null || _permissionBlocked) return;
    final key = _key(query);
    if (sequence < (_acceptedCacheSequence[key.queryKey] ?? 0)) return;
    _acceptedCacheSequence[key.queryKey] = sequence;
    final payload = jsonEncode(tasks.map(TaskApiMapper.toJson).toList());
    unawaited(
      _enqueueCache(() async {
        // A later successful mutation makes this accepted response stale.
        if (epoch != _changeEpoch ||
            _permissionBlocked ||
            _acceptedCacheSequence[key.queryKey] != sequence) {
          return;
        }
        if (_cacheInvalid) {
          final cleared = await cache!.clearNamespace(_cacheNamespace!);
          if (cleared is! Success<void>) return;
          _cacheInvalid = false;
        }
        await cache!.write(_key(query), payloadJson: payload);
      }),
    );
  }

  Future<List<Task>?> _readList(TaskQuery query) async {
    if (cache == null) return null;
    await _cacheQueue;
    if (_disposed || _permissionBlocked || _cacheInvalid) return null;
    try {
      final result = await cache!.read(_key(query));
      if (result is! Success<CacheEntry?> || result.value == null) return null;
      return TaskApiMapper.listFromJson(jsonDecode(result.value!.payloadJson));
    } catch (_) {
      return null;
    }
  }

  final Set<_TaskWatch> _watches = {};
  bool _disposed = false;

  @override
  Stream<Result<List<Task>>> watch(TaskQuery query) =>
      Stream<Result<List<Task>>>.multi((controller) {
        if (_disposed) {
          controller.add(_closedFailure<List<Task>>());
          unawaited(controller.close());
          return;
        }
        final watcher = _TaskWatch(query, controller);
        _watches.add(watcher);
        controller.onCancel = () {
          watcher.active = false;
          _watches.remove(watcher);
        };
        _invalidate(watcher);
      });

  @override
  Future<Result<Task>> getById(String id) {
    if (_disposed) return Future.value(_closedFailure<Task>());
    return datasource.getById(id);
  }

  @override
  Future<Result<Task>> create(TaskDraft draft) =>
      _write(() => datasource.create(draft));

  @override
  Future<Result<Task>> update(String id, TaskDraft draft) =>
      _write(() => datasource.update(id, draft));

  @override
  Future<Result<Task>> setStatus(String id, TaskStatus status) =>
      _write(() => datasource.setStatus(id, status));

  @override
  Future<Result<void>> delete(String id) => _write(() => datasource.delete(id));

  Future<Result<T>> _write<T>(Future<Result<T>> Function() action) async {
    if (_disposed) return _closedFailure<T>();
    final result = await action();
    if (result is Success<T> && !_disposed) {
      _changeEpoch++;
      _invalidateCache();
      refresh();
    }
    return result;
  }

  /// Tải lại các subscription đang hoạt động, dùng cho retry/refresh thủ công.
  ///
  /// Không tự retry thao tác ghi. Không có subscription thì không gửi GET.
  void refresh() {
    if (_disposed) return;
    for (final watcher in _watches.toList()) {
      _invalidate(watcher);
    }
  }

  void _invalidate(_TaskWatch watcher) {
    if (_disposed || !watcher.active) return;
    watcher.revision++;
    if (watcher.loading) return;
    watcher.loading = true;
    unawaited(_load(watcher));
  }

  Future<void> _load(_TaskWatch watcher) async {
    try {
      while (!_disposed && watcher.active) {
        final revision = watcher.revision;
        final sequence = ++_requestSequence;
        final result = await datasource.list(watcher.query);
        if (_disposed || !watcher.active) return;
        // Nếu có ghi/refresh trong lúc chờ, response này đã cũ.
        if (revision != watcher.revision) continue;
        if (result is Success<List<Task>>) {
          _saveList(watcher.query, result.value, _changeEpoch, sequence);
          watcher.controller.add(result);
        } else {
          final failure = (result as Failure<List<Task>>).failure;
          if (failure.code == AppFailureCode.permissionDenied) {
            // No cached reads/writes for this owner after permission is denied.
            _permissionBlocked = true;
            _invalidateCache();
          }
          final cached = failure is TaskAvailabilityFailure
              ? await _readList(watcher.query)
              : null;
          if (_disposed || !watcher.active) return;
          if (revision != watcher.revision) continue;
          watcher.controller.add(cached == null ? result : Success(cached));
        }
        return;
      }
    } finally {
      watcher.loading = false;
    }
  }

  /// Đóng stream; không đóng client và không hủy thao tác ghi đã gửi đi.
  ///
  /// Response đang chờ của watcher bị bỏ qua; datasource có timeout riêng.
  /// Không chờ subscriber đang pause. Có thể gọi nhiều lần.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final watchers = _watches.toList();
    _watches.clear();
    for (final watcher in watchers) {
      watcher.active = false;
      unawaited(watcher.controller.close());
    }
  }

  static Failure<T> _closedFailure<T>() => Failure<T>(
    const AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Repository công việc đã đóng.',
    ),
  );
}

class _TaskWatch {
  _TaskWatch(this.query, this.controller);

  final TaskQuery query;
  final MultiStreamController<Result<List<Task>>> controller;
  bool active = true;
  bool loading = false;
  int revision = 0;
}
