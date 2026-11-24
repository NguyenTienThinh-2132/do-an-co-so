import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:finai/features/finance/data/remote_finance_repository.dart';

const url = String.fromEnvironment('TV3_FINANCE_API_BASE_URL');
void main() {
  test(
    'three finance views read one real PostgreSQL ledger',
    () async {
      final base = Uri.parse(url);
      expect(base.host, '127.0.0.1');
      expect(base.userInfo, isEmpty);
      final client = http.Client();
      final repo = RemoteFinanceRepository(client: client, baseUrl: base);
      try {
        final home = await repo.watchOverview(DateTime.now()).first;
        final jars = await repo.watchJars().first;
        final sources = await repo.getExpenseSources();
        expect(home.isPersistent, isTrue);
        expect(jars.isPersistent, isTrue);
        expect(home.balance, jars.accountBalance);
        expect(
          sources.fold<int>(0, (sum, s) => sum + s.availableAmount),
          home.balance,
        );
        expect(sources.first.availableAmount, jars.unallocated);
        expect(jars.totalBps, 10000);
        expect(
          home.income,
          home.transactions
              .where((t) => t.amount > 0)
              .fold<int>(0, (sum, t) => sum + t.amount),
        );
        expect(
          home.expense,
          home.transactions
              .where((t) => t.amount < 0)
              .fold<int>(0, (sum, t) => sum - t.amount),
        );
      } finally {
        await repo.dispose();
        client.close();
      }
    },
    skip: url.isEmpty
        ? 'Pass TV3_FINANCE_API_BASE_URL for the local report server.'
        : false,
  );
}
