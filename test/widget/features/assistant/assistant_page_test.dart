import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/assistant/application/assistant_controller.dart';
import 'package:finai/features/assistant/data/fake_assistant_service.dart';
import 'package:finai/features/assistant/domain/assistant_models.dart';
import 'package:finai/features/assistant/presentation/assistant_page.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/ports/task_reader.dart';
import 'package:finai/features/tasks/domain/ports/task_dto.dart';

class EmptyReader implements TaskReader {
  int calls = 0;
  @override
  Future<Result<List<TaskDto>>> getTasks(TaskQuery query) async {
    calls++;
    return const Success([]);
  }
}

void main() {
  AssistantController controller(EmptyReader reader) => AssistantController(
    service: FakeAssistantService(tasks: reader),
    query: TaskQuery(
      start: DateTime(2026, 11, 13),
      end: DateTime(2026, 11, 14),
    ),
  );
  testWidgets('tin nhắn trắng không gửi, luôn có nhãn mô phỏng', (
    tester,
  ) async {
    final reader = EmptyReader();
    final c = controller(reader);
    await tester.pumpWidget(MaterialApp(home: AssistantPage(controller: c)));
    await tester.enterText(find.byKey(const Key('assistant-input')), '   ');
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('assistant-send')))
          .onPressed,
      isNull,
    );
    expect(find.text('Chế độ mô phỏng'), findsOneWidget);
    expect(c.messages, isEmpty);
    expect(reader.calls, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('kịch bản chậm có Dừng; hủy không hiện câu trả lời sau đó', (
    tester,
  ) async {
    final reader = EmptyReader();
    final c = controller(reader);
    await tester.pumpWidget(MaterialApp(home: AssistantPage(controller: c)));
    await tester.tap(find.byTooltip('Kịch bản mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chậm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Việc trong khoảng này'));
    await tester.pump();
    expect(find.text('Đang trả lời…'), findsOneWidget);
    expect(find.text('Dừng'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-input')))
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('Dừng'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(c.replying, isFalse);
    expect(reader.calls, 0);
    expect(c.messages.where((m) => m.role == ChatRole.assistant), isEmpty);
    expect(find.text('Đang trả lời…'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'kịch bản lỗi hiện Thử lại; thành công không thêm trùng câu hỏi',
    (tester) async {
      final reader = EmptyReader();
      final c = controller(reader);
      await tester.pumpWidget(MaterialApp(home: AssistantPage(controller: c)));
      await tester.tap(find.byTooltip('Kịch bản mẫu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lỗi thử nghiệm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Tiến độ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(c.failure, isNotNull);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(reader.calls, 0);
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(c.failure, isNull);
      expect(c.replying, isFalse);
      expect(reader.calls, 1);
      expect(c.messages.where((m) => m.role == ChatRole.user), hasLength(1));
      expect(
        c.messages.where((m) => m.role == ChatRole.assistant).single.text,
        contains('0/0 công việc'),
      );
      expect(find.text('Thử lại'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
