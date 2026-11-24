enum FinanceCategory { food, transport, shopping, education, housing, other }

class DashboardTransaction {
  const DashboardTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.occurredAt,
    required this.category,
    this.jarId,
    this.note,
  });

  final String id;
  final String title;

  /// Signed integer VND: income is positive, expense is negative.
  final int amount;
  final DateTime occurredAt;
  final FinanceCategory category;
  final String? jarId;
  final String? note;
}

class UpcomingEntry {
  const UpcomingEntry({
    required this.title,
    required this.amount,
    required this.dueAt,
  });
  final String title;
  final int amount;
  final DateTime dueAt;
}

class DashboardOverview {
  const DashboardOverview({
    required this.balance,
    required this.income,
    required this.expense,
    required this.budget,
    required this.transactions,
    required this.upcoming,
    this.initialBalance,
    this.isDemo = false,
    this.isPersistent = false,
  });

  final int balance;

  /// Funds available before all recorded transactions, independent of month.
  /// Null when the data source does not provide this information.
  final int? initialBalance;
  final int income;
  final int expense;
  final int budget;
  final List<DashboardTransaction> transactions;
  final List<UpcomingEntry> upcoming;
  final bool isDemo;
  final bool isPersistent;

  /// The selected month's income minus expense, not the current account balance.
  int get monthlyNetChange => income - expense;

  /// Change from every recorded transaction, across all months.
  int? get recordedNetChange =>
      initialBalance == null ? null : balance - initialBalance!;
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.title,
    required this.amount,
    required this.category,
    required this.occurredAt,
    this.jarId,
    this.note,
    this.requestId,
  });
  final String? requestId;
  final String title;

  /// Positive integer VND.
  final int amount;
  final FinanceCategory category;
  final DateTime occurredAt;
  final String? jarId;
  final String? note;
}

class ExpenseSource {
  const ExpenseSource({
    required this.title,
    required this.availableAmount,
    this.jarId,
  });
  final String title;
  final int availableAmount;
  final String? jarId;
}

/// A read model for the home screen. An adapter can implement this using TV2's
/// repositories without making the dashboard own a second transaction ledger.
abstract interface class DashboardReader {
  Stream<DashboardOverview> watchOverview(DateTime month);
}

abstract interface class ExpenseWriter {
  Future<void> recordExpense(ExpenseDraft draft);
  Future<List<ExpenseSource>> getExpenseSources();
}
