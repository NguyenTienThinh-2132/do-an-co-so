import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../dashboard/domain/dashboard_repository.dart';
import '../../jars/domain/jar_repository.dart';
import '../../../core/utils/request_id.dart';

/// One remote ledger for Home, Jars and Cash Flow. The client is owned by the root.
class RemoteFinanceRepository
    implements DashboardReader, ExpenseWriter, JarRepository {
  RemoteFinanceRepository({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;
  final _changes = StreamController<void>.broadcast(sync: true);
  bool _disposed = false;
  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '${baseUrl.toString().replaceFirst(RegExp(r'/$'), '')}/finance/$path',
  ).replace(queryParameters: query);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? key,
  }) async {
    try {
      final request = http.Request(method, _uri(path, query));
      request.headers['Content-Type'] = 'application/json';
      if (key != null) request.headers['Idempotency-Key'] = key;
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? message;
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] is String) {
            message = data['message'] as String;
          }
        } catch (_) {}
        throw FinanceRuleException(
          message ?? 'Chưa xử lý được yêu cầu. Bạn thử lại nhé.',
        );
      }
      return jsonDecode(response.body);
    } on FinanceRuleException {
      rethrow;
    } catch (_) {
      throw const FinanceRuleException(
        'Không kết nối được máy chủ. Kiểm tra backend và thử lại.',
      );
    }
  }

  Stream<T> _watch<T>(Future<T> Function() fetch) {
    late StreamController<T> output;
    StreamSubscription<void>? subscription;
    bool stopped = false, running = false, again = false;
    Future<void> refresh() async {
      if (stopped) return;
      if (running) {
        again = true;
        return;
      }
      running = true;
      do {
        again = false;
        try {
          final value = await fetch();
          if (!stopped) output.add(value);
        } catch (e, st) {
          if (!stopped) output.addError(e, st);
        }
      } while (again && !stopped);
      running = false;
    }

    output = StreamController<T>(
      onListen: () {
        subscription = _changes.stream.listen((_) => unawaited(refresh()));
        unawaited(refresh());
      },
      onCancel: () async {
        stopped = true;
        await subscription?.cancel();
      },
    );
    return output.stream;
  }

  void _changed() {
    if (!_disposed) _changes.add(null);
  }

  // JSON money is a string; reject values unsafe on Flutter Web as well.
  static int _money(dynamic value) {
    if (value is! String || !RegExp(r'^-?\d+$').hasMatch(value)) {
      throw const FormatException('Invalid VND');
    }
    final parsed = int.parse(value);
    if (parsed.abs() > 9007199254740991) {
      throw const FormatException('VND outside safe range');
    }
    return parsed;
  }

  static Jar _jar(dynamic data) => Jar.fromJson({
    ...Map<String, dynamic>.from(data as Map),
    'allocated': _money(data['allocated']),
    'spent': _money(data['spent']),
  });
  static AllocationRecord _allocation(dynamic data) =>
      AllocationRecord.fromJson({
        ...Map<String, dynamic>.from(data as Map),
        'amount': _money(data['amount']),
        'amounts': {
          for (final e in (data['amounts'] as Map).entries)
            e.key as String: _money(e.value),
        },
      });
  @override
  Stream<DashboardOverview> watchOverview(DateTime month) => _watch(() async {
    final data = await _request(
      'GET',
      'overview',
      query: {
        'start': DateTime(month.year, month.month).toUtc().toIso8601String(),
        'end': DateTime(month.year, month.month + 1).toUtc().toIso8601String(),
      },
    );
    return DashboardOverview(
      balance: _money(data['balance']),
      initialBalance: _money(data['initialBalance']),
      income: _money(data['income']),
      expense: _money(data['expense']),
      budget: _money(data['budget']),
      transactions: [
        for (final t in data['transactions'] as List)
          DashboardTransaction(
            id: t['id'] as String,
            title: t['title'] as String,
            amount: _money(t['amount']),
            occurredAt: DateTime.parse(t['occurredAt'] as String).toLocal(),
            category: FinanceCategory.values.byName(t['category'] as String),
            jarId: t['jarId'] as String?,
            note: t['note'] as String?,
          ),
      ],
      upcoming: const [],
      isDemo: data['isDemo'] == true,
      isPersistent: data['isPersistent'] == true,
    );
  });
  @override
  Stream<JarOverview> watchJars() => _watch(() async {
    final d = await _request('GET', 'jars');
    return JarOverview(
      jars: [for (final j in d['jars'] as List) _jar(j)],
      deletedJars: [for (final j in d['deletedJars'] as List) _jar(j)],
      history: [for (final a in d['history'] as List) _allocation(a)],
      accountBalance: _money(d['accountBalance']),
      revision: d['revision'] as int,
      isPersistent: d['isPersistent'] == true,
    );
  });
  @override
  Future<List<ExpenseSource>> getExpenseSources() async {
    final data = await _request('GET', 'expense-sources');
    return [
      for (final d in data as List)
        ExpenseSource(
          title: d['title'] as String,
          availableAmount: _money(d['availableAmount']),
          jarId: d['jarId'] as String?,
        ),
    ];
  }

  @override
  Future<void> recordExpense(ExpenseDraft draft) async {
    await _request(
      'POST',
      'expenses',
      key: draft.requestId ?? newRequestId(),
      body: {
        'title': draft.title,
        'amount': draft.amount.toString(),
        'category': draft.category.name,
        'occurredAt': draft.occurredAt.toUtc().toIso8601String(),
        'jarId': draft.jarId,
        'note': draft.note?.trim().isEmpty == true ? null : draft.note,
      },
    );
    _changed();
  }

  @override
  Future<Jar> addJar({
    required String title,
    required String subtitle,
    required String styleKey,
    String? requestId,
  }) async {
    final data = await _request(
      'POST',
      'jars',
      key: requestId ?? newRequestId(),
      body: {'title': title, 'subtitle': subtitle, 'styleKey': styleKey},
    );
    _changed();
    return _jar(data);
  }

  @override
  Future<void> setAllocations(
    Map<String, int> ratios, {
    required int expectedRevision,
    String? requestId,
  }) async {
    await _request(
      'PUT',
      'jars/ratios',
      key: requestId ?? newRequestId(),
      body: {'ratios': ratios, 'expectedRevision': expectedRevision},
    );
    _changed();
  }

  @override
  Future<void> deleteJar({
    required String jarId,
    required int expectedRevision,
    String? transferRatioToJarId,
    String? requestId,
  }) async {
    await _request(
      'DELETE',
      'jars/${Uri.encodeComponent(jarId)}',
      key: requestId ?? newRequestId(),
      body: {
        'expectedRevision': expectedRevision,
        'transferRatioToJarId': transferRatioToJarId,
      },
    );
    _changed();
  }

  @override
  Future<AllocationRecord> allocate({
    required int amount,
    required String requestId,
    int? expectedRevision,
  }) async {
    final data = await _request(
      'POST',
      'allocations',
      key: requestId,
      body: {'amount': amount.toString(), 'expectedRevision': expectedRevision},
    );
    _changed();
    return _allocation(data);
  }

  void refresh() => _changed();
  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
  }
}
