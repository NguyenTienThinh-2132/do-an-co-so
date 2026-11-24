import 'package:finai/dev/main_tasks_day_demo.dart';
import 'package:finai/features/tasks/domain/entities/task_calendar_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task_completion_test.dart' as fixtures;

void main() {
  test('tuần giao năm, tháng nhuận và chuyển tháng không mất ngày', () {
    final week = TaskCalendarRange(
      DateTime(2027, 1, 1),
      TasksCalendarMode.week,
    );
    expect(week.start, DateTime(2026, 12, 28));
    expect(week.end, DateTime(2027, 1, 4));
    expect(week.days, hasLength(7));
    final month = TaskCalendarRange(
      DateTime(2028, 2, 29),
      TasksCalendarMode.month,
    );
    expect(month.start, DateTime(2028, 2, 1));
    expect(month.end, DateTime(2028, 3, 1));
    expect(month.days, hasLength(29));
    expect(
      TaskCalendarRange.shift(
        DateTime(2027, 1, 31),
        TasksCalendarMode.month,
        1,
      ),
      DateTime(2027, 2, 28),
    );
  });

  testWidgets('tháng tải cả tháng, chọn ngày không đổi tổng tháng', (
    tester,
  ) async {
    final repo = fixtures.Records();
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TasksDemoApp(repository: repo, now: () => DateTime(2026, 11, 8)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tasks-view-month')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.start, DateTime(2026, 11, 1).toUtc());
    expect(repo.queries.last.end, DateTime(2026, 12, 1).toUtc());
    final cell = find.byKey(const ValueKey('tasks-month-2026-11-9'));
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(repo.queries.last.start, DateTime(2026, 11, 1).toUtc());
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('1 / 1 công việc'), findsOneWidget);
    final next = find.byKey(const Key('tasks-period-next'));
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(repo.queries.last.start, DateTime(2026, 12, 1).toUtc());
    expect(repo.queries.last.end, DateTime(2027, 1, 1).toUtc());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.close();
  });

  testWidgets('tuần tải thứ Hai đến đầu tuần sau và chọn ngày trong tuần', (
    tester,
  ) async {
    final repo = fixtures.Records();
    await tester.pumpWidget(
      TasksDemoApp(repository: repo, now: () => DateTime(2026, 11, 8)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tasks-view-week')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.start, DateTime(2026, 11, 2).toUtc());
    expect(repo.queries.last.end, DateTime(2026, 11, 9).toUtc());
    final day = find.byKey(const ValueKey('task-day-2026-11-3'));
    await tester.ensureVisible(day);
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.text('Xem cả tuần'), findsOneWidget);
    await tester.tap(find.text('Xem cả tuần'));
    await tester.pumpAndSettle();
    expect(find.text('Xem cả tuần'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.close();
  });
}
