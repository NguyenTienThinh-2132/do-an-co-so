import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/task_create_controller.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:finai/features/tasks/presentation/task_create_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CreateStub implements TaskRepository {
  final drafts = <TaskDraft>[];
  final pending = <Completer<Result<Task>>>[];
  @override
  Future<Result<Task>> create(TaskDraft draft) {
    drafts.add(draft);
    final result = Completer<Result<Task>>();
    pending.add(result);
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Task saved(TaskDraft d) => Task(
  id: 'created',
  title: d.title,
  description: d.description,
  startAt: d.startAt,
  endAt: d.endAt,
  priority: d.priority,
  status: TaskStatus.pending,
  createdAt: DateTime.utc(2026, 11, 8),
  updatedAt: DateTime.utc(2026, 11, 8),
);

void main() {
  late CreateStub repo;
  late TaskCreateController controller;
  setUp(() {
    repo = CreateStub();
    controller = TaskCreateController(repository: repo);
  });
  tearDown(() {
    controller.dispose();
  });
  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: TaskCreatePage(
            controller: controller,
            initialDay: DateTime(2026, 11, 8),
          ),
        ),
      ),
    );
  }

  testWidgets('tên rỗng không gửi; lưu đúng draft, chặn lưu trùng', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên công việc.'), findsOneWidget);
    expect(repo.drafts, isEmpty);
    await tester.enterText(
      find.byKey(const Key('task-title')),
      '  Học Flutter  ',
    );
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pump();
    expect(repo.drafts, hasLength(1));
    expect(repo.drafts.single.title, 'Học Flutter');
    expect(repo.drafts.single.startAt, DateTime(2026, 11, 8, 9).toUtc());
    expect(repo.drafts.single.endAt, DateTime(2026, 11, 8, 10).toUtc());
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('task-save'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('task-save')));
    expect(repo.drafts, hasLength(1));
    repo.pending.single.complete(Success(saved(repo.drafts.single)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lưu lỗi giữ dữ liệu và có thể gửi lại', (tester) async {
    await mount(tester);
    await tester.enterText(
      find.byKey(const Key('task-title')),
      'Công việc test',
    );
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pump();
    repo.pending.single.complete(
      const Failure(
        AppFailure(code: AppFailureCode.unavailable, message: 'private'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.failure, isNotNull);
    expect(find.text('Công việc test'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pump();
    expect(repo.drafts, hasLength(2));
    repo.pending.last.complete(Success(saved(repo.drafts.last)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('form không tràn ở 320px, chữ 1.3', (tester) async {
    await mount(tester, width: 320, scale: 1.3);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('kết thúc trước bắt đầu không gửi repository', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(const Key('task-title')), 'Kiểm tra giờ');
    await tester.ensureVisible(find.text('8/11/2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('8/11/2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('7').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();
    expect(repo.drafts, isEmpty);
    await tester.scrollUntilVisible(
      find.text('Kết thúc phải sau thời điểm bắt đầu.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Kết thúc phải sau thời điểm bắt đầu.'), findsOneWidget);
  });

  testWidgets('xuất ảnh form xem thử', (tester) async {
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        await (FontLoader('PreviewSans')..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'PreviewSans',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
        ),
        home: RepaintBoundary(
          key: const Key('form-preview'),
          child: TaskCreatePage(
            controller: controller,
            initialDay: DateTime(2026, 11, 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('form-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/task-create-preview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
