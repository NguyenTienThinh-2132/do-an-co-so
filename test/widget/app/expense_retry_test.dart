import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/dashboard/domain/dashboard_repository.dart';
import 'package:finai/features/dashboard/presentation/widgets/expense_sheet.dart';
import 'package:finai/features/jars/domain/jar_repository.dart';

void main() {
  testWidgets('retry keeps timestamp and request key when parent rebuilds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = ValueNotifier(DateTime(2026, 11, 13, 9));
    final writes = <ExpenseDraft>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: date,
            builder: (_, time, _) => ExpenseSheet(
              date: time,
              isDemo: true,
              loadSources: () async => [
                const ExpenseSource(title: 'Pool', availableAmount: 100000),
              ],
              onSave: (draft) async {
                writes.add(draft);
                throw const FinanceRuleException('Retry');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-title')),
      'Chi test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '50000',
    );
    final save = find.byKey(const ValueKey('save-expense'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    date.value = DateTime(2026, 11, 14, 10);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(writes, hasLength(2));
    expect(writes[0].requestId, writes[1].requestId);
    expect(writes[0].occurredAt, writes[1].occurredAt);
    expect(writes[1].occurredAt, DateTime(2026, 11, 13, 9));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    date.dispose();
  });
}
