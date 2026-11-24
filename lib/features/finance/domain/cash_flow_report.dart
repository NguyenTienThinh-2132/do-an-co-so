import '../../dashboard/domain/dashboard_repository.dart';

enum CashFlowType { expense, income }

class CashFlowGroup {
  const CashFlowGroup({
    required this.category,
    required this.amount,
    required this.count,
    required this.percentTenths,
  });
  final FinanceCategory category;
  final int amount;
  final int count;

  /// Rounded shares use largest remainders so displayed percentages total 100%.
  final int percentTenths;
  String get percentLabel => '${percentTenths ~/ 10},${percentTenths % 10}%';
}

class CashFlowReport {
  CashFlowReport._(
    this.type,
    List<DashboardTransaction> transactions,
    List<CashFlowGroup> groups,
    this.total,
  ) : transactions = List.unmodifiable(transactions),
      groups = List.unmodifiable(groups);
  final CashFlowType type;
  final List<DashboardTransaction> transactions;
  final List<CashFlowGroup> groups;
  final int total;

  factory CashFlowReport.fromTransactions({
    required Iterable<DashboardTransaction> transactions,
    required DateTime month,
    required CashFlowType type,
  }) {
    final matching =
        transactions.where((t) {
          final date = t.occurredAt.toLocal();
          return date.year == month.year &&
              date.month == month.month &&
              (type == CashFlowType.income ? t.amount > 0 : t.amount < 0);
        }).toList()..sort((a, b) {
          final time = b.occurredAt.compareTo(a.occurredAt);
          return time == 0 ? b.id.compareTo(a.id) : time;
        });
    final amounts = <FinanceCategory, int>{};
    final counts = <FinanceCategory, int>{};
    for (final t in matching) {
      amounts.update(
        t.category,
        (value) => value + t.amount.abs(),
        ifAbsent: () => t.amount.abs(),
      );
      counts.update(t.category, (value) => value + 1, ifAbsent: () => 1);
    }
    final total = amounts.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return CashFlowReport._(type, matching, [], 0);
    final shares = {
      for (final entry in amounts.entries)
        entry.key: entry.value * 1000 ~/ total,
    };
    final remainders = amounts.keys.toList()
      ..sort((a, b) {
        final order = (amounts[b]! * 1000 % total).compareTo(
          amounts[a]! * 1000 % total,
        );
        return order == 0 ? a.index.compareTo(b.index) : order;
      });
    final extra =
        1000 - shares.values.fold<int>(0, (sum, value) => sum + value);
    for (var i = 0; i < extra; i++) {
      shares[remainders[i]] = shares[remainders[i]]! + 1;
    }
    final groups =
        [
          for (final entry in amounts.entries)
            CashFlowGroup(
              category: entry.key,
              amount: entry.value,
              count: counts[entry.key]!,
              percentTenths: shares[entry.key]!,
            ),
        ]..sort((a, b) {
          final amount = b.amount.compareTo(a.amount);
          return amount == 0
              ? a.category.index.compareTo(b.category.index)
              : amount;
        });
    return CashFlowReport._(type, matching, groups, total);
  }
}
