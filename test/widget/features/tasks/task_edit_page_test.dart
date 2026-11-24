import 'dart:async';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/task_edit_controller.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:finai/features/tasks/presentation/task_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Task fixture() => Task(
  id: 'task-id',
  title: 'Tên cũ',
  description: 'Mô tả cũ',
  categoryId: 'keep-category',
  startAt: DateTime(2026, 11, 8, 9),
  endAt: DateTime(2026, 11, 8, 10),
  priority: TaskPriority.high,
  status: TaskStatus.completed,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 7),
);

class EditStub implements TaskRepository {
  late Completer<Result<Task>> get;
  late Completer<Result<Task>> updateResult;
  final ids = <String>[];
  final drafts = <TaskDraft>[];
  final updatedIds = <String>[];
  @override
  Future<Result<Task>> getById(String id) {
    get = Completer<Result<Task>>();
    ids.add(id);
    return get.future;
  }

  @override
  Future<Result<Task>> update(String id, TaskDraft draft) {
    updateResult = Completer<Result<Task>>();
    updatedIds.add(id);
    drafts.add(draft);
    return updateResult.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late EditStub repo;
  late TaskEditController controller;
  setUp(() {
    repo = EditStub();
    controller = TaskEditController(repository: repo, taskId: 'task-id');
  });
  tearDown(() {
    controller.dispose();
  });
  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: TaskEditPage(controller: controller)),
    );
  }

  testWidgets('tải bằng ID, điền form và update đúng bản ghi', (tester) async {
    unawaited(controller.load());
    await mount(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repo.ids, ['task-id']);
    repo.get.complete(Success(fixture()));
    await tester.pumpAndSettle();
    expect(find.text('Sửa công việc'), findsOneWidget);
    expect(find.text('Tên cũ'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('task-title')), 'Tên mới');
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pump();
    expect(repo.updatedIds, ['task-id']);
    expect(repo.drafts.single.title, 'Tên mới');
    expect(repo.drafts.single.description, 'Mô tả cũ');
    expect(repo.drafts.single.categoryId, 'keep-category');
    expect(repo.drafts.single.priority, TaskPriority.high);
    expect(repo.drafts.single.startAt, fixture().startAt);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('task-save'))).onPressed,
      isNull,
    );
    repo.updateResult.complete(Success(fixture()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final code in [AppFailureCode.validation, AppFailureCode.notFound]) {
    testWidgets('load lỗi $code không mở form ghi', (tester) async {
      unawaited(controller.load());
      await mount(tester);
      repo.get.complete(Failure(AppFailure(code: code, message: 'private')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-title')), findsNothing);
      expect(
        find.text(
          code == AppFailureCode.notFound
              ? 'Công việc không còn tồn tại hoặc đã bị xóa.'
              : 'ID công việc không hợp lệ.',
        ),
        findsOneWidget,
      );
      expect(find.text('private'), findsNothing);
      expect(repo.drafts, isEmpty);
    });
  }

  testWidgets('bản ghi bị xóa lúc lưu giữ nội dung và báo lỗi rõ', (
    tester,
  ) async {
    unawaited(controller.load());
    await mount(tester);
    repo.get.complete(Success(fixture()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title')), 'Chưa lưu');
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pump();
    repo.updateResult.complete(
      const Failure(
        AppFailure(code: AppFailureCode.notFound, message: 'Missing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Công việc đã bị xóa. Đóng form để quay lại danh sách.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Công việc đã bị xóa. Đóng form để quay lại danh sách.'),
      findsOneWidget,
    );
  });

  test('dispose bỏ qua kết quả load đến muộn', () async {
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });
    final pending = controller.load();
    controller.dispose();
    repo.get.complete(Success(fixture()));
    await pending;
    expect(notifications, 1);
    expect(controller.task, isNull);
  });

  test('chưa load không được update', () async {
    final t = fixture();
    final result = await controller.submit(
      TaskDraft(title: 'Tên mới', startAt: t.startAt, endAt: t.endAt),
    );
    expect(result, isNull);
    expect(controller.failure!.code, AppFailureCode.validation);
    expect(repo.updatedIds, isEmpty);
  });
}
