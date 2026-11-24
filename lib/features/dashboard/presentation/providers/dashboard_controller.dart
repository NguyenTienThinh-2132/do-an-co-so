import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/dashboard_repository.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    required this.reader,
    required this.writer,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    final now = this.clock();
    month = DateTime(now.year, now.month);
    reload();
  }

  final DashboardReader reader;
  final ExpenseWriter writer;
  final DateTime Function() clock;
  StreamSubscription<DashboardOverview>? _subscription;
  late DateTime month;
  DashboardOverview? overview;
  bool loading = true;
  bool balanceVisible = true;
  String? error;

  void toggleBalance() {
    balanceVisible = !balanceVisible;
    notifyListeners();
  }

  void selectMonth(DateTime value) {
    month = DateTime(value.year, value.month);
    reload();
  }

  void reload() {
    _subscription?.cancel();
    loading = true;
    error = null;
    notifyListeners();
    _subscription = reader
        .watchOverview(month)
        .listen(
          (value) {
            overview = value;
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object failure) {
            loading = false;
            error = 'Chưa tải được tổng quan. Bạn thử lại nhé.';
            notifyListeners();
          },
        );
  }

  Future<void> addExpense(ExpenseDraft draft) async {
    await writer.recordExpense(draft);
    if (month.year != draft.occurredAt.year ||
        month.month != draft.occurredAt.month) {
      selectMonth(draft.occurredAt);
    }
  }

  Future<List<ExpenseSource>> getExpenseSources() => writer.getExpenseSources();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
