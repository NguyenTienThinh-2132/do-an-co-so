import 'dart:async';

import '../../dashboard/domain/dashboard_repository.dart';
import '../../jars/domain/jar_repository.dart';
import 'fake_finance_repository.dart';
import 'remote_finance_repository.dart';

/// Wraps [RemoteFinanceRepository] and falls back to [FakeFinanceRepository]
/// when the backend is unreachable.
class FallbackFinanceRepository
    implements DashboardReader, ExpenseWriter, JarRepository {
  FallbackFinanceRepository({required this.remote});

  final RemoteFinanceRepository remote;
  final _fake = FakeFinanceRepository();

  /// Forwards values from [primary]; on any error emits the result of [getFake].
  Stream<T> _withFallback<T>(
    Stream<T> primary,
    Future<T> Function() getFake,
  ) {
    StreamSubscription<T>? sub;
    late StreamController<T> controller;

    controller = StreamController<T>(
      onListen: () {
        sub = primary.listen(
          (value) {
            if (!controller.isClosed) controller.add(value);
          },
          onError: (Object e) async {
            try {
              final fake = await getFake();
              if (!controller.isClosed) controller.add(fake);
            } catch (_) {
              if (!controller.isClosed) controller.addError(e);
            }
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
          cancelOnError: false,
        );
      },
      onCancel: () => sub?.cancel(),
    );

    return controller.stream;
  }

  @override
  Stream<DashboardOverview> watchOverview(DateTime month) => _withFallback(
    remote.watchOverview(month),
    () async => FakeFinanceRepository.makeDemoOverview(month),
  );

  @override
  Stream<JarOverview> watchJars() => _withFallback(
    remote.watchJars(),
    () async => FakeFinanceRepository.makeDemoJars(),
  );

  @override
  Future<List<ExpenseSource>> getExpenseSources() async {
    try {
      return await remote.getExpenseSources();
    } catch (_) {
      return _fake.getExpenseSources();
    }
  }

  @override
  Future<void> recordExpense(ExpenseDraft draft) =>
      remote.recordExpense(draft);

  @override
  Future<Jar> addJar({
    required String title,
    required String subtitle,
    required String styleKey,
    String? requestId,
  }) => remote.addJar(
    title: title,
    subtitle: subtitle,
    styleKey: styleKey,
    requestId: requestId,
  );

  @override
  Future<void> setAllocations(
    Map<String, int> ratios, {
    required int expectedRevision,
    String? requestId,
  }) => remote.setAllocations(
    ratios,
    expectedRevision: expectedRevision,
    requestId: requestId,
  );

  @override
  Future<void> deleteJar({
    required String jarId,
    required int expectedRevision,
    String? transferRatioToJarId,
    String? requestId,
  }) => remote.deleteJar(
    jarId: jarId,
    expectedRevision: expectedRevision,
    transferRatioToJarId: transferRatioToJarId,
    requestId: requestId,
  );

  @override
  Future<AllocationRecord> allocate({
    required int amount,
    required String requestId,
    int? expectedRevision,
  }) => remote.allocate(
    amount: amount,
    requestId: requestId,
    expectedRevision: expectedRevision,
  );
}
