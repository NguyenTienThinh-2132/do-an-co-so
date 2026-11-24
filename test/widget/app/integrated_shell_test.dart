import 'dart:convert';

import 'package:finai/app/integration/finance_bindings.dart';
import 'package:finai/dev/main_tasks_day_demo.dart';
import 'package:finai/features/finance/data/remote_finance_repository.dart';
import 'package:finai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:finai/features/jars/presentation/screens/jars_screen.dart';
import 'package:finai/features/finance/presentation/screens/cash_flow_screen.dart';
import 'package:finai/features/tasks/presentation/tasks_day_page.dart';
import 'package:finai/features/assistant/presentation/assistant_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../features/tasks/task_completion_test.dart' as tasks;
import '../../unit/features/finance/remote_finance_repository_test.dart'
    as finance;

void main() {
  testWidgets(
    'five tabs keep TV3 Tasks, chat, routes and shared finance controller',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = tasks.Records();
      final client = MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path.endsWith('jars') ? finance.jars() : finance.overview(),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final repo = RemoteFinanceRepository(
        client: client,
        baseUrl: Uri.parse('http://localhost'),
      );
      await tester.pumpWidget(
        TasksDemoApp(
          repository: records,
          now: () => DateTime(2026, 11, 8),
          finance: FinanceBindings(
            dashboardReader: repo,
            expenseWriter: repo,
            jars: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await tester.pumpAndSettle();
      expect(find.byType(JarsScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPage), findsOneWidget);
      expect(find.text('Chế độ mô phỏng'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-3')));
      await tester.pumpAndSettle();
      expect(find.byType(TasksDayPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tasks-view-month')));
      await tester.pumpAndSettle();
      expect(records.queries.last.end, DateTime(2026, 12).toUtc());
      await tester.tap(find.byKey(const ValueKey('tab-4')));
      await tester.pumpAndSettle();
      expect(find.byType(CashFlowScreen), findsOneWidget);
      final cash = tester.widget<CashFlowScreen>(find.byType(CashFlowScreen));
      final home = tester.widget<DashboardScreen>(
        find.byType(DashboardScreen, skipOffstage: false),
      );
      expect(identical(cash.controller, home.controller), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await records.close();
      await repo.dispose();
      client.close();
    },
  );
}
