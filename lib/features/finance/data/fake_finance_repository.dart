import 'dart:async';

import '../../dashboard/domain/dashboard_repository.dart';
import '../../jars/domain/jar_repository.dart';

/// Demo data repository – shown when the backend is unreachable.
class FakeFinanceRepository
    implements DashboardReader, ExpenseWriter, JarRepository {
  static final _now = DateTime.now();

  static DashboardOverview makeDemoOverview(DateTime month) {
    final m = month.month;
    final y = month.year;
    return DashboardOverview(
      balance: 15500000,
      initialBalance: 20000000,
      income: 20000000,
      expense: 4500000,
      budget: 10000000,
      isDemo: true,
      isPersistent: false,
      upcoming: const [],
      transactions: [
        DashboardTransaction(
          id: 'demo-1',
          title: 'Lương tháng $m/$y',
          amount: 20000000,
          occurredAt: DateTime(y, m, 1),
          category: FinanceCategory.other,
        ),
        DashboardTransaction(
          id: 'demo-2',
          title: 'Tiền nhà',
          amount: -2000000,
          occurredAt: DateTime(y, m, 3),
          category: FinanceCategory.housing,
        ),
        DashboardTransaction(
          id: 'demo-3',
          title: 'Siêu thị VinMart',
          amount: -800000,
          occurredAt: DateTime(y, m, 5),
          category: FinanceCategory.food,
        ),
        DashboardTransaction(
          id: 'demo-4',
          title: 'Xăng xe',
          amount: -300000,
          occurredAt: DateTime(y, m, 7),
          category: FinanceCategory.transport,
        ),
        DashboardTransaction(
          id: 'demo-5',
          title: 'Khóa học online',
          amount: -500000,
          occurredAt: DateTime(y, m, 10),
          category: FinanceCategory.education,
        ),
        DashboardTransaction(
          id: 'demo-6',
          title: 'Cà phê Highland',
          amount: -200000,
          occurredAt: DateTime(y, m, 12),
          category: FinanceCategory.food,
        ),
        DashboardTransaction(
          id: 'demo-7',
          title: 'Mua sắm quần áo',
          amount: -400000,
          occurredAt: DateTime(y, m, 14),
          category: FinanceCategory.shopping,
        ),
        DashboardTransaction(
          id: 'demo-8',
          title: 'Grab / di chuyển',
          amount: -300000,
          occurredAt: DateTime(y, m, 16),
          category: FinanceCategory.transport,
        ),
      ],
    );
  }

  static JarOverview makeDemoJars() {
    const jars = [
      Jar(
        id: 'necessities',
        title: 'Hũ Thiết yếu',
        subtitle: 'Nhà ở, thực phẩm, sinh hoạt',
        styleKey: 'home',
        allocationBps: 5500,
        allocatedAmount: 11000000,
        spentAmount: 3300000,
        isDefault: true,
      ),
      Jar(
        id: 'long-term',
        title: 'Tiết kiệm dài hạn',
        subtitle: 'Dành dụm cho những mục tiêu lớn',
        styleKey: 'savings',
        allocationBps: 1000,
        allocatedAmount: 2000000,
        spentAmount: 0,
        isDefault: true,
      ),
      Jar(
        id: 'education',
        title: 'Giáo dục & Phát triển',
        subtitle: 'Đầu tư vào kiến thức và kỹ năng',
        styleKey: 'education',
        allocationBps: 1000,
        allocatedAmount: 2000000,
        spentAmount: 500000,
        isDefault: true,
      ),
      Jar(
        id: 'enjoyment',
        title: 'Hưởng thụ & Giải trí',
        subtitle: 'Du lịch, cà phê và điều bạn thích',
        styleKey: 'enjoyment',
        allocationBps: 1000,
        allocatedAmount: 2000000,
        spentAmount: 400000,
        isDefault: true,
      ),
      Jar(
        id: 'financial-freedom',
        title: 'Đầu tư Tự do tài chính',
        subtitle: 'Chuẩn bị cho tương lai của bạn',
        styleKey: 'investment',
        allocationBps: 1000,
        allocatedAmount: 2000000,
        spentAmount: 0,
        isDefault: true,
      ),
      Jar(
        id: 'giving',
        title: 'Cho đi & Thiện nguyện',
        subtitle: 'Chia sẻ cùng gia đình và cộng đồng',
        styleKey: 'giving',
        allocationBps: 500,
        allocatedAmount: 1000000,
        spentAmount: 300000,
        isDefault: true,
      ),
    ];

    return JarOverview(
      jars: jars,
      history: [
        AllocationRecord(
          id: 'demo-alloc-1',
          amount: 20000000,
          createdAt: DateTime(_now.year, _now.month, 1),
          amounts: const {
            'necessities': 11000000,
            'long-term': 2000000,
            'education': 2000000,
            'enjoyment': 2000000,
            'financial-freedom': 2000000,
            'giving': 1000000,
          },
          ratios: const {
            'necessities': 5500,
            'long-term': 1000,
            'education': 1000,
            'enjoyment': 1000,
            'financial-freedom': 1000,
            'giving': 500,
          },
        ),
      ],
      accountBalance: 15500000,
      revision: 1,
      isPersistent: false,
    );
  }

  @override
  Stream<DashboardOverview> watchOverview(DateTime month) =>
      Stream.value(makeDemoOverview(month));

  @override
  Stream<JarOverview> watchJars() => Stream.value(makeDemoJars());

  @override
  Future<List<ExpenseSource>> getExpenseSources() async => const [
    ExpenseSource(
      title: 'Hũ Thiết yếu',
      availableAmount: 7700000,
      jarId: 'necessities',
    ),
    ExpenseSource(
      title: 'Hưởng thụ & Giải trí',
      availableAmount: 1600000,
      jarId: 'enjoyment',
    ),
    ExpenseSource(
      title: 'Giáo dục & Phát triển',
      availableAmount: 1500000,
      jarId: 'education',
    ),
  ];

  @override
  Future<void> recordExpense(ExpenseDraft draft) async {}

  @override
  Future<Jar> addJar({
    required String title,
    required String subtitle,
    required String styleKey,
    String? requestId,
  }) async {
    throw const FinanceRuleException('Chế độ demo: không thể thêm hũ.');
  }

  @override
  Future<void> setAllocations(
    Map<String, int> ratios, {
    required int expectedRevision,
    String? requestId,
  }) async {
    throw const FinanceRuleException(
      'Chế độ demo: không thể thay đổi phân bổ.',
    );
  }

  @override
  Future<void> deleteJar({
    required String jarId,
    required int expectedRevision,
    String? transferRatioToJarId,
    String? requestId,
  }) async {
    throw const FinanceRuleException('Chế độ demo: không thể xóa hũ.');
  }

  @override
  Future<AllocationRecord> allocate({
    required int amount,
    required String requestId,
    int? expectedRevision,
  }) async {
    throw const FinanceRuleException('Chế độ demo: không thể phân bổ.');
  }
}
