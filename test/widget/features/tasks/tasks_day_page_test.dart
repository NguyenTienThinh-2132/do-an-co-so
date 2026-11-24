import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/tasks_list_controller.dart';
import 'package:finai/features/tasks/application/task_status_controller.dart';
import 'package:finai/features/tasks/application/task_delete_controller.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:finai/features/tasks/presentation/tasks_day_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositoryStub implements TaskRepository {
  final streams = <StreamController<Result<List<Task>>>>[];
  final queries = <TaskQuery>[];
  final deleteCalls = <String>[];
  final deleteResults = <Completer<Result<void>>>[];
  @override
  Future<Result<void>> delete(String id) {
    deleteCalls.add(id);
    final completer = Completer<Result<void>>();
    deleteResults.add(completer);
    return completer.future;
  }

  final statusCalls = <(String, TaskStatus)>[];
  final statusResults = <Completer<Result<Task>>>[];
  @override
  Future<Result<Task>> setStatus(String id, TaskStatus status) {
    statusCalls.add((id, status));
    final completer = Completer<Result<Task>>();
    statusResults.add(completer);
    return completer.future;
  }

  @override
  Stream<Result<List<Task>>> watch(TaskQuery query) {
    queries.add(query);
    final source = StreamController<Result<List<Task>>>();
    streams.add(source);
    return source.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Task fixture(String id, TaskStatus status) => Task(
  id: id,
  title: 'Công việc kiểm tra $id',
  startAt: DateTime(2026, 11, 7, 9),
  endAt: DateTime(2026, 11, 7, 10),
  priority: TaskPriority.high,
  status: status,
  createdAt: DateTime(2026, 11, 7),
  updatedAt: DateTime(2026, 11, 7),
);

void main() {
  late RepositoryStub repository;
  late TasksListController controller;
  setUp(() {
    repository = RepositoryStub();
    controller = TasksListController(
      repository: repository,
      query: TaskQuery(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
      ),
    );
  });
  tearDown(() async {
    controller.dispose();
    for (final source in repository.streams) {
      await source.close();
    }
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    DateTime Function()? now,
    TasksListController? dailyController,
    TaskStatusController? statusController,
    TaskDeleteController? deleteController,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'PreviewSans',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: const Key('preview'),
            child: TasksDayPage(
              controller: controller,
              now: now,
              dailyController: dailyController,
              statusController: statusController,
              deleteController: deleteController,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('loading không hiển thị số 0 như dữ liệu đã tải', (tester) async {
    controller.load();
    await mount(tester);
    await tester.scrollUntilVisible(
      find.text('Đang tải công việc…'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0 / 0 công việc'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty hiển thị 0 công việc và 0%, không chia cho 0', (
    tester,
  ) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('0 / 0 công việc'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0);
    await tester.scrollUntilVisible(
      find.text('Không có công việc nào!'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Không có công việc nào!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error và Thử lại gọi controller, sau đó tải thành công', (
    tester,
  ) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(
      const Failure(
        AppFailure(
          code: AppFailureCode.unavailable,
          message: 'private details',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thử lại'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('private details'), findsNothing);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.streams, hasLength(2));
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('Không có công việc nào!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dữ liệu thật từ controller và tỷ lệ tiến độ', (tester) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(
      Success([
        fixture('1', TaskStatus.completed),
        fixture('2', TaskStatus.inProgress),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 công việc'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Công việc kiểm tra 2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Công việc kiểm tra 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('không overflow rộng $width, cỡ chữ 1.3', (tester) async {
      controller.load();
      await mount(tester, width: width, scale: 1.3);
      repository.streams.single.add(
        Success([fixture('1', TaskStatus.completed)]),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bấm ngày đổi query, tiêu đề và dữ liệu', (tester) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(Success([fixture('cũ', TaskStatus.pending)]));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('task-day-2026-11-3'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
    final query = repository.queries.last;
    expect(query.start, DateTime(2026, 11, 3).toUtc());
    expect(query.end, DateTime(2026, 11, 4).toUtc());
    expect(controller.state.tasks, isEmpty);
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dòng thời gian ngày 3/11'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dòng thời gian ngày 3/11'), findsOneWidget);
    expect(find.text('Công việc kiểm tra cũ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('đổi ngày giữ nguyên trạng thái, ưu tiên và từ khóa', (
    tester,
  ) async {
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
        status: TaskStatus.completed,
        priority: TaskPriority.high,
        searchText: 'Flutter',
      ),
    );
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('task-day-2026-11-2'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
    final query = repository.queries.last;
    expect(query.status, TaskStatus.completed);
    expect(query.priority, TaskPriority.high);
    expect(query.searchText, 'Flutter');
    expect(query.start.isUtc && query.end.isUtc, isTrue);
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
  });

  testWidgets('dải ngày chọn qua ranh giới tháng', (tester) async {
    controller.setQuery(
      TaskQuery(start: DateTime(2026, 11, 30), end: DateTime(2026, 12, 1)),
    );
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('task-day-2026-12-1'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
    expect(repository.queries.last.start, DateTime(2026, 12, 1).toUtc());
    expect(repository.queries.last.end, DateTime(2026, 12, 2).toUtc());
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 12, 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hôm nay lấy đồng hồ lúc bấm, qua năm và bấm lại tải mới', (
    tester,
  ) async {
    var now = DateTime(2026, 12, 31, 23, 59);
    controller.load();
    await mount(tester, now: () => now);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    now = DateTime(2027, 1, 1, 0, 1);
    final today = find.byKey(const Key('tasks-today'));
    await tester.ensureVisible(today);
    await tester.pumpAndSettle();
    await tester.tap(today);
    await tester.pump();
    expect(repository.queries.last.start, DateTime(2027, 1, 1).toUtc());
    expect(repository.queries.last.end, DateTime(2027, 1, 2).toUtc());
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 1, 2027'), findsOneWidget);
    final count = repository.queries.length;
    await tester.tap(today);
    await tester.pump();
    expect(repository.queries, hasLength(count + 1));
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('status chips đổi query và giữ các điều kiện còn lại', (
    tester,
  ) async {
    final original = TaskQuery(
      start: DateTime(2026, 11, 7),
      end: DateTime(2026, 11, 8),
      priority: TaskPriority.high,
      searchText: 'Công việc',
    );
    controller.setQuery(original);
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    for (final status in [TaskStatus.inProgress, TaskStatus.completed, null]) {
      final key = ValueKey('task-status-${status?.name ?? 'all'}');
      final chip = find.byKey(key);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump();
      final query = repository.queries.last;
      expect(query.start, original.start);
      expect(query.end, original.end);
      expect(query.priority, original.priority);
      expect(query.searchText, original.searchText);
      expect(query.status, status);
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      repository.streams.last.add(const Success([]));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('lọc danh sách không đổi tiến độ toàn ngày', (tester) async {
    final daily = TasksListController(
      repository: repository,
      query: controller.state.query,
    )..load();
    addTearDown(daily.dispose);
    controller.load();
    await mount(tester, dailyController: daily);
    final tasks = [
      fixture('1', TaskStatus.completed),
      fixture('2', TaskStatus.inProgress),
    ];
    repository.streams[0].add(Success(tasks));
    repository.streams[1].add(Success(tasks));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 công việc'), findsOneWidget);
    final chip = find.byKey(const ValueKey('task-status-completed'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    // Summary vẫn có dữ liệu trong lúc danh sách đang tải theo bộ lọc.
    expect(find.text('1 / 2 công việc'), findsOneWidget);
    repository.streams.last.add(Success([tasks.first]));
    await tester.pumpAndSettle();
    expect(controller.state.tasks, hasLength(1));
    expect(find.text('1 / 2 công việc'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('100.0%'), findsNothing);
    expect(
      repository.queries,
      hasLength(3),
    ); // đổi status không tải lại tổng ngày
  });

  testWidgets('không dùng tổng ngày cũ hoặc danh sách lọc làm tổng ngày mới', (
    tester,
  ) async {
    final daily = TasksListController(
      repository: repository,
      query: controller.state.query,
    )..load();
    addTearDown(daily.dispose);
    controller.load();
    await mount(tester, dailyController: daily);
    repository.streams[0].add(Success([fixture('1', TaskStatus.completed)]));
    repository.streams[1].add(const Success([]));
    await tester.pumpAndSettle();
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 8),
        end: DateTime(2026, 11, 9),
        status: TaskStatus.completed,
      ),
    );
    await tester.pump();
    repository.streams.last.add(Success([fixture('2', TaskStatus.completed)]));
    await tester.pumpAndSettle();
    expect(find.text('— / — công việc'), findsOneWidget);
    expect(find.text('100.0%'), findsNothing);
  });
  testWidgets('tìm tên debounce, trim và xóa ngay, giữ bộ lọc', (tester) async {
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
        status: TaskStatus.completed,
        priority: TaskPriority.high,
      ),
    );
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('tasks-search'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    final count = repository.queries.length;
    await tester.enterText(field, ' Flut');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(field, ' Flutter ');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.queries, hasLength(count));
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.queries, hasLength(count + 1));
    final query = repository.queries.last;
    expect(query.searchText, 'Flutter');
    expect(query.status, TaskStatus.completed);
    expect(query.priority, TaskPriority.high);
    expect(query.start, DateTime(2026, 11, 7).toUtc());
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tasks-search-clear')));
    await tester.pump();
    expect(repository.queries.last.searchText, isEmpty);
    expect(repository.queries.last.status, TaskStatus.completed);
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    final afterClear = repository.queries.length;
    await tester.pump(const Duration(seconds: 1));
    expect(repository.queries, hasLength(afterClear));
  });

  testWidgets('debounce dùng ngày và trạng thái mới nhất', (tester) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('tasks-search'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Báo cáo');
    await tester.pump(const Duration(milliseconds: 100));
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 8),
        end: DateTime(2026, 11, 9),
        status: TaskStatus.inProgress,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(repository.queries.last.searchText, 'Báo cáo');
    expect(repository.queries.last.start, DateTime(2026, 11, 8).toUtc());
    expect(repository.queries.last.status, TaskStatus.inProgress);
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
  });

  testWidgets('tìm kiếm không thay đổi tiến độ toàn ngày', (tester) async {
    final daily = TasksListController(
      repository: repository,
      query: controller.state.query,
    )..load();
    addTearDown(daily.dispose);
    controller.load();
    await mount(tester, dailyController: daily);
    final tasks = [
      fixture('1', TaskStatus.completed),
      fixture('2', TaskStatus.pending),
    ];
    repository.streams[0].add(Success(tasks));
    repository.streams[1].add(Success(tasks));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('tasks-search'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Công việc kiểm tra 1');
    await tester.pump(const Duration(milliseconds: 350));
    repository.streams.last.add(Success([tasks.first]));
    await tester.pumpAndSettle();
    // Đóng bàn phím rồi quay về thẻ tiến độ.
    tester.testTextInput.hide();
    await tester.pump();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 công việc'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(repository.queries, hasLength(3));
  });

  testWidgets('đóng màn hủy debounce, không query sau dispose', (tester) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('tasks-search'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Chưa gửi');
    final count = repository.queries.length;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(repository.queries, hasLength(count));
    expect(tester.takeException(), isNull);
  });
  testWidgets('menu trạng thái gửi đúng ID, giữ dữ liệu khi lỗi và thử lại', (
    tester,
  ) async {
    final status = TaskStatusController(repository: repository);
    addTearDown(status.dispose);
    controller.load();
    await mount(tester, statusController: status);
    repository.streams.single.add(
      Success([fixture('one', TaskStatus.pending)]),
    );
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('task-status-menu-one'));
    await tester.scrollUntilVisible(
      menu,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<TaskStatus>, 'Đang làm'),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.statusCalls, [('one', TaskStatus.inProgress)]);
    expect(status.isSaving('one'), isTrue);
    expect(controller.state.tasks.single.status, TaskStatus.pending);
    repository.statusResults.single.complete(
      const Failure(
        AppFailure(code: AppFailureCode.unavailable, message: 'private'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.state.tasks.single.status, TaskStatus.pending);
    await tester.scrollUntilVisible(
      find.text('Thử lại'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(repository.statusCalls, hasLength(2));
    repository.statusResults.last.complete(
      Success(fixture('one', TaskStatus.inProgress)),
    );
    repository.streams.single.add(
      Success([fixture('one', TaskStatus.inProgress)]),
    );
    await tester.pumpAndSettle();
    expect(status.failureFor('one'), isNull);
    expect(controller.state.tasks.single.status, TaskStatus.inProgress);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'xác nhận xóa: Hủy không gọi API, Xóa chờ phản hồi mới cập nhật',
    (tester) async {
      final deletion = TaskDeleteController(repository: repository);
      addTearDown(deletion.dispose);
      controller.load();
      await mount(tester, deleteController: deletion, width: 320, scale: 1.3);
      repository.streams.single.add(
        Success([fixture('one', TaskStatus.pending)]),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('task-delete-one'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Xóa công việc?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Công việc kiểm tra one'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, isEmpty);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-delete-confirm')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.deleteCalls, ['one']);
      expect(controller.state.tasks, hasLength(1));
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      repository.deleteResults.single.complete(const Success<void>(null));
      repository.streams.single.add(const Success([]));
      await tester.pumpAndSettle();
      expect(controller.state.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('xóa lỗi giữ task, thử lại phải xác nhận và notFound rõ ràng', (
    tester,
  ) async {
    final deletion = TaskDeleteController(repository: repository);
    addTearDown(deletion.dispose);
    controller.load();
    await mount(tester, deleteController: deletion);
    repository.streams.single.add(
      Success([fixture('one', TaskStatus.pending)]),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('task-delete-one'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-delete-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    repository.deleteResults.single.complete(
      const Failure(
        AppFailure(code: AppFailureCode.unavailable, message: 'private'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.state.tasks, hasLength(1));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, hasLength(1));
    expect(find.text('Xóa công việc?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-delete-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    repository.deleteResults.last.complete(
      const Failure(
        AppFailure(code: AppFailureCode.notFound, message: 'Missing'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Công việc đã bị xóa trước đó. Hãy tải lại danh sách.'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Công việc đã bị xóa trước đó. Hãy tải lại danh sách.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('popup Hủy giữ nguyên ngày và không tải lại', (tester) async {
    controller.load();
    await mount(tester, width: 320, scale: 1.3);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final before = controller.state.query;
    final count = repository.queries.length;
    final picker = find.byKey(const Key('tasks-date-picker'));
    await tester.scrollUntilVisible(
      picker,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Chọn ngày công việc'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(controller.state.query, same(before));
    expect(repository.queries, hasLength(count));
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup chọn ngày ở năm khác, giữ bộ lọc và đổi tuần hiển thị', (
    tester,
  ) async {
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
        status: TaskStatus.completed,
        priority: TaskPriority.high,
        searchText: 'Flutter',
      ),
    );
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final picker = find.byKey(const Key('tasks-date-picker'));
    await tester.scrollUntilVisible(
      picker,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(input, '12/25/2027');
    await tester.tap(find.text('Chọn'));
    await tester.pump(const Duration(milliseconds: 400));
    final query = repository.queries.last;
    expect(query.start, DateTime(2027, 12, 25).toUtc());
    expect(query.end, DateTime(2027, 12, 26).toUtc());
    expect(query.status, TaskStatus.completed);
    expect(query.priority, TaskPriority.high);
    expect(query.searchText, 'Flutter');
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 12, 2027'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-day-2027-12-25')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup không áp dụng ngày nhập sai', (tester) async {
    controller.load();
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final count = repository.queries.length;
    final picker = find.byKey(const Key('tasks-date-picker'));
    await tester.scrollUntilVisible(
      picker,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(input, 'not-a-date');
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(repository.queries, hasLength(count));
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('lọc đủ mức ưu tiên, xóa riêng ưu tiên và kết hợp Chờ xử lý', (
    tester,
  ) async {
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
        status: TaskStatus.completed,
        searchText: 'Flutter',
      ),
    );
    await mount(tester);
    repository.streams.single.add(const Success([]));
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('tasks-priority-filter'));
    for (final option in <(String, TaskPriority?)>[
      ('high', TaskPriority.high),
      ('medium', TaskPriority.medium),
      ('low', TaskPriority.low),
      ('all', null),
    ]) {
      await tester.scrollUntilVisible(
        menu,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final item = find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<String> && widget.value == option.$1,
      );
      await tester.tap(item);
      await tester.pump(const Duration(milliseconds: 400));
      final query = repository.queries.last;
      expect(query.priority, option.$2);
      expect(query.status, TaskStatus.completed);
      expect(query.searchText, 'Flutter');
      expect(query.start, DateTime(2026, 11, 7).toUtc());
      expect(query.end, DateTime(2026, 11, 8).toUtc());
      repository.streams.last.add(const Success([]));
      await tester.pumpAndSettle();
    }
    controller.setQuery(
      TaskQuery(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
        status: TaskStatus.completed,
        priority: TaskPriority.high,
        searchText: 'Flutter',
      ),
    );
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    final pending = find.byKey(const ValueKey('task-status-pending'));
    await tester.ensureVisible(pending);
    await tester.pumpAndSettle();
    await tester.tap(pending);
    await tester.pump();
    expect(repository.queries.last.status, TaskStatus.pending);
    expect(repository.queries.last.priority, TaskPriority.high);
    expect(repository.queries.last.searchText, 'Flutter');
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lọc ưu tiên không thay tiến độ toàn ngày', (tester) async {
    final daily = TasksListController(
      repository: repository,
      query: controller.state.query,
    )..load();
    addTearDown(daily.dispose);
    controller.load();
    await mount(tester, dailyController: daily, width: 320, scale: 1.3);
    final high = fixture('high', TaskStatus.completed);
    final low = Task(
      id: 'low',
      title: 'Ưu tiên thấp',
      startAt: high.startAt,
      endAt: high.endAt,
      priority: TaskPriority.low,
      status: TaskStatus.pending,
      createdAt: high.createdAt,
      updatedAt: high.updatedAt,
    );
    repository.streams[0].add(Success([high, low]));
    repository.streams[1].add(Success([high, low]));
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('tasks-priority-filter'));
    await tester.scrollUntilVisible(
      menu,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<String> && widget.value == 'high',
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    repository.streams.last.add(Success([high]));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 công việc'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(controller.state.tasks, hasLength(1));
    expect(repository.queries, hasLength(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('retry tiến độ độc lập khi danh sách tải thành công', (
    tester,
  ) async {
    final daily = TasksListController(
      repository: repository,
      query: controller.state.query,
    )..load();
    addTearDown(daily.dispose);
    controller.load();
    await mount(tester, dailyController: daily);
    repository.streams[0].add(
      const Failure(
        AppFailure(code: AppFailureCode.unavailable, message: 'Network'),
      ),
    );
    repository.streams[1].add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại tiến độ'), findsOneWidget);
    await tester.tap(find.text('Thử lại tiến độ'));
    await tester.pump();
    expect(repository.streams, hasLength(3));
    repository.streams.last.add(const Success([]));
    await tester.pumpAndSettle();
    expect(find.text('0 / 0 công việc'), findsOneWidget);
    expect(find.text('Thử lại tiến độ'), findsNothing);
  });
  testWidgets('xuất preview màn khung để kiểm tra hình ảnh', (tester) async {
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('PreviewSans')
          ..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    controller.load();
    await mount(tester);
    repository.streams.single.add(
      Success([
        fixture('1', TaskStatus.completed),
        fixture('2', TaskStatus.inProgress),
      ]),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/tasks-day-preview.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
