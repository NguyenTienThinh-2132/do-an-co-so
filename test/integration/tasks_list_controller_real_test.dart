import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/tasks_list_controller.dart';
import 'package:finai/features/tasks/application/tasks_list_state.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const baseUrl = String.fromEnvironment('TV3_TASKS_API_BASE_URL');

T success<T>(Result<T> result) => switch (result) {
  Success<T>(:final value) => value,
  Failure<T>(:final failure) => throw StateError(failure.code.name),
};

Future<TasksListState> waitFor(
  TasksListController controller,
  bool Function(TasksListState) predicate,
  FutureOr<void> Function() action,
) async {
  final completer = Completer<TasksListState>();
  void listener() {
    if (completer.isCompleted) return;
    final state = controller.state;
    if (state.phase == TasksListPhase.error) {
      completer.completeError(StateError('Controller returned Failure'));
    } else if (predicate(state)) {
      completer.complete(state);
    }
  }

  controller.addListener(listener);
  try {
    // Lỗi action phải được chuyển vào cùng Future để không bỏ sót async error.
    unawaited(
      Future<void>.sync(action).catchError((Object error, StackTrace stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      }),
    );
    return await completer.future.timeout(const Duration(seconds: 25));
  } finally {
    controller.removeListener(listener);
  }
}

void main() {
  test(
    'controller -> NestJS -> PostgreSQL thật, tự dọn fixture',
    () async {
      final base = Uri.parse(baseUrl);
      expect(base.scheme, 'http');
      expect(base.host, '127.0.0.1');
      expect(base.userInfo, isEmpty);
      expect(base.hasQuery || base.hasFragment, isFalse);
      expect(['', '/', '/api'].contains(base.path), isTrue);

      final random = Random.secure();
      final nonce = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final marker = 'TV3 Controller probe $nonce ';
      final start = DateTime.utc(2045, 1, 2);
      final end = DateTime.utc(2045, 1, 3);
      final query = TaskQuery(start: start, end: end, searchText: marker);
      final client = http.Client();
      final source = TaskRemoteDatasource(client: client, baseUrl: base);
      final repository = HttpTaskRepository(datasource: source);
      final controller = TasksListController(
        repository: repository,
        query: query,
      );
      final phases = <TasksListPhase>[];
      controller.addListener(() {
        phases.add(controller.state.phase);
      });
      try {
        expect(controller.state.phase, TasksListPhase.initial);
        await waitFor(controller, (s) => s.isEmpty, controller.load);
        expect(phases.take(2), [TasksListPhase.loading, TasksListPhase.ready]);
        debugPrint('PASS: initial loading -> ready empty');

        final draft = TaskDraft(
          title: '${marker}Tạo mới',
          startAt: start.add(const Duration(hours: 9)),
          endAt: start.add(const Duration(hours: 10)),
        );
        String? id;
        final created = await waitFor(
          controller,
          (s) => s.phase == TasksListPhase.ready && s.tasks.length == 1,
          () async {
            id = success(await repository.create(draft)).id;
          },
        );
        expect(created.tasks.single.id, id);
        expect(created.tasks.single.status, TaskStatus.pending);
        debugPrint('PASS: repository create -> controller updated');

        final edited = await waitFor(
          controller,
          (s) =>
              s.tasks.length == 1 &&
              s.tasks.single.priority == TaskPriority.high,
          () async {
            success(
              await repository.update(
                id!,
                TaskDraft(
                  title: '$marker Đã sửa',
                  startAt: draft.startAt,
                  endAt: draft.endAt,
                  priority: TaskPriority.high,
                ),
              ),
            );
          },
        );
        expect(edited.tasks.single.title, '$marker Đã sửa');
        debugPrint('PASS: repository update -> controller updated');

        await waitFor(
          controller,
          (s) =>
              s.tasks.length == 1 &&
              s.tasks.single.status == TaskStatus.completed,
          () async {
            success(await repository.setStatus(id!, TaskStatus.completed));
          },
        );
        debugPrint('PASS: status change -> controller updated');

        final filtered = TaskQuery(
          start: start,
          end: end,
          searchText: marker,
          status: TaskStatus.pending,
        );
        await waitFor(
          controller,
          (s) => identical(s.query, filtered) && s.isEmpty,
          () => controller.setQuery(filtered),
        );
        debugPrint('PASS: status query -> empty');

        final tomorrow = TaskQuery(
          start: end,
          end: end.add(const Duration(days: 1)),
          searchText: marker,
        );
        await waitFor(
          controller,
          (s) => identical(s.query, tomorrow) && s.isEmpty,
          () => controller.setQuery(tomorrow),
        );
        await waitFor(
          controller,
          (s) =>
              identical(s.query, query) &&
              s.phase == TasksListPhase.ready &&
              s.tasks.length == 1,
          () => controller.setQuery(query),
        );
        debugPrint('PASS: switch day and return');

        final notificationsBeforeRetry = phases.length;
        await waitFor(
          controller,
          (s) => s.phase == TasksListPhase.ready && s.tasks.length == 1,
          controller.retry,
        );
        expect(phases.skip(notificationsBeforeRetry), [
          TasksListPhase.loading,
          TasksListPhase.ready,
        ]);
        debugPrint('PASS: retry resubscribes and reloads real data');

        await waitFor(controller, (s) => s.isEmpty, () async {
          success(await repository.delete(id!));
        });
        debugPrint('PASS: delete -> controller empty');
      } finally {
        controller.dispose();
        repository.dispose();
        try {
          final leftovers = success(await source.list(query));
          for (final task in leftovers.where(
            (t) => t.title.startsWith(marker),
          )) {
            success(await source.delete(task.id));
          }
          expect(success(await source.list(query)), isEmpty);
          debugPrint('PASS: fixture cleanup verified');
        } finally {
          client.close();
        }
      }
    },
    skip: baseUrl.isEmpty
        ? 'Cần --dart-define=TV3_TASKS_API_BASE_URL=http://127.0.0.1:PORT'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
