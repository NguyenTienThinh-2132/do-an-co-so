import 'dart:async';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/dev/main_tasks_day_demo.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:finai/features/tasks/presentation/task_details_page.dart';
import 'package:finai/features/tasks/presentation/task_edit_page.dart';
import 'package:finai/features/tasks/presentation/task_create_page.dart';
import 'package:finai/features/tasks/presentation/task_overdue_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Task fixture({TaskStatus status = TaskStatus.completed, DateTime? end}) => Task(
  id: 'id-1',
  title: 'Bản ghi gốc',
  description: 'Mô tả thật',
  startAt: DateTime(2026, 11, 8, 9),
  endAt: end ?? DateTime(2026, 11, 8, 10),
  priority: TaskPriority.high,
  status: status,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 7),
);

class Records implements TaskRepository {
  final records = <String, Task>{'id-1': fixture()};
  final reads = <String>[];
  final queries = <TaskQuery>[];
  final _changes = StreamController<void>.broadcast();
  @override
  Stream<Result<List<Task>>> watch(TaskQuery query) => Stream.multi((c) {
    queries.add(query);
    void emit() {
      c.add(
        Success(
          records.values
              .where(
                (t) =>
                    t.startAt.isBefore(query.end) &&
                    t.endAt.isAfter(query.start) &&
                    (query.status == null || t.status == query.status) &&
                    (query.priority == null || t.priority == query.priority) &&
                    t.title.toLowerCase().contains(
                      query.searchText.toLowerCase(),
                    ),
              )
              .toList(),
        ),
      );
    }

    final subscription = _changes.stream.listen((_) => emit());
    c.onCancel = subscription.cancel;
    emit();
  });
  @override
  Future<Result<Task>> getById(String id) async {
    reads.add(id);
    if (id == 'bad') {
      return const Failure(
        AppFailure(code: AppFailureCode.validation, message: 'Invalid'),
      );
    }
    final task = records[id];
    return task == null
        ? const Failure(
            AppFailure(code: AppFailureCode.notFound, message: 'Missing'),
          )
        : Success(task);
  }

  @override
  Future<Result<Task>> update(String id, TaskDraft draft) async {
    final old = records[id]!;
    final task = Task(
      id: id,
      title: draft.title,
      description: draft.description,
      categoryId: draft.categoryId,
      startAt: draft.startAt,
      endAt: draft.endAt,
      priority: draft.priority,
      status: old.status,
      createdAt: old.createdAt,
      updatedAt: DateTime(2026, 11, 8),
    );
    records[id] = task;
    _changes.add(null);
    return Success(task);
  }

  Future<void> close() => _changes.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('quá hạn đúng biên và cập nhật khi vượt thời gian', (
    tester,
  ) async {
    final end = DateTime(2026, 11, 8, 10);
    var now = end;
    await tester.pumpWidget(
      MaterialApp(
        home: TaskOverdueBadge(
          task: fixture(status: TaskStatus.pending),
          now: () => now,
        ),
      ),
    );
    expect(find.text('Quá hạn'), findsNothing);
    now = end.add(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Quá hạn'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskOverdueBadge(
          task: fixture(status: TaskStatus.completed),
          now: () => now,
        ),
      ),
    );
    expect(find.text('Quá hạn'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quá hạn làm mới khi ứng dụng trở lại foreground', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 8, 9);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskOverdueBadge(
          task: fixture(status: TaskStatus.inProgress),
          now: () => now,
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 8, 11);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Quá hạn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('danh sách -> chi tiết -> sửa -> chi tiết tải lại đúng ID', (
    tester,
  ) async {
    final repo = Records();
    await tester.pumpWidget(
      TasksDemoApp(repository: repo, now: () => DateTime(2026, 11, 8)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bản ghi gốc'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Bản ghi gốc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bản ghi gốc'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsPage), findsOneWidget);
    expect(repo.reads.last, 'id-1');
    expect(
      ModalRoute.of(tester.element(find.byType(TaskDetailsPage)))!
          .settings
          .name,
      '/tasks/id-1',
    );
    await tester.tap(find.byTooltip('Sửa công việc'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(TaskEditPage)))!.settings.name,
      '/tasks/id-1/edit',
    );
    await tester.enterText(find.byKey(const Key('task-title')), 'Đã sửa');
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsPage), findsOneWidget);
    expect(find.text('Đã sửa'), findsOneWidget);
    expect(
      repo.reads.where((id) => id == 'id-1').length,
      greaterThanOrEqualTo(3),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.close();
  });

  for (final id in ['bad', 'missing']) {
    testWidgets('route ID $id báo lỗi rõ', (tester) async {
      final repo = Records();
      await tester.pumpWidget(
        TasksDemoApp(repository: repo, now: () => DateTime(2026, 11, 8)),
      );
      await tester.pumpAndSettle();
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/tasks/$id'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          id == 'bad'
              ? 'ID công việc không hợp lệ.'
              : 'Công việc không còn tồn tại hoặc đã bị xóa.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('task-title')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.close();
    });
  }

  testWidgets('route tạo và route không tồn tại', (tester) async {
    final repo = Records();
    await tester.pumpWidget(
      TasksDemoApp(repository: repo, now: () => DateTime(2026, 11, 8)),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/tasks/new'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCreatePage), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    unawaited(navigator.pushNamed('/unknown'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy màn hình'), findsOneWidget);
    await tester.tap(find.text('Trở về Công việc'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch trình Công việc'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.close();
  });
}
