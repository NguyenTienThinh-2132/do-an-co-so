import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:finai/features/finance/data/remote_finance_repository.dart';
import 'package:finai/features/dashboard/domain/dashboard_repository.dart';
import 'package:finai/features/jars/domain/jar_repository.dart';

Map<String, Object?> overview({String balance = '1000000'}) => {
  'balance': balance,
  'initialBalance': '1000000',
  'income': '0',
  'expense': '0',
  'budget': '500000',
  'transactions': [],
  'upcoming': [],
  'isDemo': true,
  'isPersistent': true,
};
Map<String, Object?> jars() => {
  'jars': [
    for (final j in defaultJars)
      {...j.toJson(), 'allocated': '0', 'spent': '0'},
  ],
  'deletedJars': [],
  'history': [],
  'accountBalance': '1000000',
  'revision': 0,
  'isPersistent': true,
};
void main() {
  test(
    'maps VND strings, UTC half-open month and injected API prefix',
    () async {
      late http.Request received;
      final client = MockClient((r) async {
        received = r;
        return http.Response(jsonEncode(overview()), 200);
      });
      final repo = RemoteFinanceRepository(
        client: client,
        baseUrl: Uri.parse('http://localhost/api/'),
      );
      final data = await repo.watchOverview(DateTime(2026, 11)).first;
      expect(data.balance, 1000000);
      expect(data.isDemo, isTrue);
      expect(received.url.path, '/api/finance/overview');
      expect(
        DateTime.parse(received.url.queryParameters['start']!),
        DateTime(2026, 11).toUtc(),
      );
      expect(
        DateTime.parse(received.url.queryParameters['end']!),
        DateTime(2026, 12).toUtc(),
      );
      await repo.dispose();
      client.close();
    },
  );
  test(
    'expense carries stable key and refreshes both finance subscriptions',
    () async {
      int overviewReads = 0, jarReads = 0;
      http.Request? write;
      final client = MockClient((r) async {
        if (r.method == 'POST') {
          write = r;
          return http.Response('{"id":"saved"}', 201);
        }
        if (r.url.path.endsWith('jars')) {
          jarReads++;
          return http.Response(
            jsonEncode(jars()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        overviewReads++;
        return http.Response(jsonEncode(overview()), 200);
      });
      final repo = RemoteFinanceRepository(
        client: client,
        baseUrl: Uri.parse('http://localhost'),
      );
      final a = repo.watchOverview(DateTime(2026, 11)).listen((_) {});
      final b = repo.watchJars().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await repo.recordExpense(
        ExpenseDraft(
          title: 'Chi test',
          amount: 25000,
          category: FinanceCategory.food,
          occurredAt: DateTime(2026, 11, 13),
          requestId: 'form-1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(write!.headers['Idempotency-Key'], 'form-1');
      expect(jsonDecode(write!.body)['amount'], '25000');
      expect(overviewReads, 2);
      expect(jarReads, 2);
      await a.cancel();
      await b.cancel();
      await repo.dispose();
      client.close();
    },
  );
  test(
    'conflict preserves server message and never reports a successful write',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"message":"Du lieu da thay doi"}', 409),
      );
      final repo = RemoteFinanceRepository(
        client: client,
        baseUrl: Uri.parse('http://localhost'),
      );
      await expectLater(
        repo.setAllocations({}, expectedRevision: 0, requestId: 'same-key'),
        throwsA(
          isA<FinanceRuleException>().having(
            (e) => e.message,
            'message',
            'Du lieu da thay doi',
          ),
        ),
      );
      await repo.dispose();
      client.close();
    },
  );
  test('rejects unsafe JSON money instead of silently rounding', () async {
    final client = MockClient(
      (_) async =>
          http.Response(jsonEncode(overview(balance: '9007199254740992')), 200),
    );
    final repo = RemoteFinanceRepository(
      client: client,
      baseUrl: Uri.parse('http://localhost'),
    );
    await expectLater(
      repo.watchOverview(DateTime(2026, 11)).first,
      throwsFormatException,
    );
    await repo.dispose();
    client.close();
  });
  test('large allocation preview uses exact integer arithmetic', () {
    final parts = splitAllocation(999999999999, defaultJars);
    expect(parts.values.reduce((a, b) => a + b), 999999999999);
    expect(parts['necessities'], 549999999999);
  });
}
