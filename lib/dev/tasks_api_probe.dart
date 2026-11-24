import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';

T _success<T>(Result<T> result) => switch (result) {
  Success<T>(:final value) => value,
  Failure<T>(:final failure) => throw StateError(failure.code.name),
};

void _check(bool value) {
  if (!value) throw StateError('Contract assertion failed.');
}

Future<List<String>> runTasksApiProbe(Uri baseUrl) async {
  if (baseUrl.scheme != 'http' ||
      baseUrl.host != '127.0.0.1' ||
      baseUrl.userInfo.isNotEmpty ||
      baseUrl.hasQuery ||
      baseUrl.hasFragment ||
      (baseUrl.path.isNotEmpty && baseUrl.path != '/')) {
    throw ArgumentError('Probe chỉ dùng backend demo trên 127.0.0.1.');
  }
  final messages = <String>[];
  final random = Random.secure();
  final nonce = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final marker = 'TV3 API probe $nonce';
  final client = http.Client();
  final datasource = TaskRemoteDatasource(client: client, baseUrl: baseUrl);
  final repository = HttpTaskRepository(datasource: datasource);
  final start = DateTime.utc(2043, 1, 2, 2);
  final end = DateTime.utc(2043, 1, 2, 3);
  final query = TaskQuery(
    start: DateTime.utc(2043, 1, 2),
    end: DateTime.utc(2043, 1, 3),
    searchText: marker,
  );
  final iterator = StreamIterator(repository.watch(query));
  Future<List<Task>> snapshot() async {
    _check(await iterator.moveNext().timeout(const Duration(seconds: 20)));
    return _success(iterator.current);
  }

  try {
    _check((await snapshot()).isEmpty);
    final created = _success(
      await repository.create(
        TaskDraft(title: marker, startAt: start, endAt: end),
      ),
    );
    _check((await snapshot()).single.id == created.id);
    messages.add('PASS: tạo qua Dart repository, watch phát công việc mới.');

    final updated = _success(
      await repository.update(
        created.id,
        TaskDraft(
          title: '$marker updated',
          startAt: start,
          endAt: end,
          priority: TaskPriority.high,
        ),
      ),
    );
    _check(updated.id == created.id && updated.createdAt == created.createdAt);
    final editedList = await snapshot();
    _check(editedList.single.title == '$marker updated');
    _check(editedList.single.priority == TaskPriority.high);
    messages.add('PASS: sửa qua API, watch cập nhật đúng nội dung.');

    final completed = _success(
      await repository.setStatus(created.id, TaskStatus.completed),
    );
    _check(completed.status == TaskStatus.completed);
    _check((await snapshot()).single.status == TaskStatus.completed);
    final loaded = _success(await repository.getById(created.id));
    _check(
      loaded.title == updated.title && loaded.status == TaskStatus.completed,
    );
    messages.add('PASS: đọc và đổi trạng thái qua PostgreSQL thật.');

    _check(await repository.delete(created.id) is Success<void>);
    _check((await snapshot()).isEmpty);
    final missing = await repository.getById(created.id);
    _check(
      missing is Failure<Task> &&
          missing.failure.code == AppFailureCode.notFound,
    );
    messages.add('PASS: xóa, watch rỗng và 404 chuyển thành notFound.');
  } finally {
    await iterator.cancel();
    repository.dispose();
    try {
      // Chỉ dọn công việc có marker ngẫu nhiên riêng của lần thử.
      final tasks = _success(await datasource.list(query));
      for (final task in tasks.where((task) => task.title.startsWith(marker))) {
        _check(await datasource.delete(task.id) is Success<void>);
      }
      _check(
        _success(await datasource.list(query))
            .where((task) => task.title.startsWith(marker))
            .isEmpty,
      );
      messages.add('Đã dọn đúng fixture Dart của lần thử và đóng repository.');
    } finally {
      client.close();
    }
  }
  return List<String>.unmodifiable(messages);
}
