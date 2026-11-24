class FinanceRuleException implements Exception {
  const FinanceRuleException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Jar {
  const Jar({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.styleKey,
    required this.allocationBps,
    this.allocatedAmount = 0,
    this.spentAmount = 0,
    this.isDefault = false,
    this.isDeleted = false,
  });
  final String id;
  final String title;
  final String subtitle;
  final String styleKey;
  final int allocationBps;
  final int allocatedAmount;
  final int spentAmount;
  final bool isDefault;
  final bool isDeleted;
  int get remainingAmount => isDeleted ? 0 : allocatedAmount - spentAmount;
  Jar copyWith({
    int? allocationBps,
    int? allocatedAmount,
    int? spentAmount,
    bool? isDeleted,
  }) => Jar(
    id: id,
    title: title,
    subtitle: subtitle,
    styleKey: styleKey,
    allocationBps: allocationBps ?? this.allocationBps,
    allocatedAmount: allocatedAmount ?? this.allocatedAmount,
    spentAmount: spentAmount ?? this.spentAmount,
    isDefault: isDefault,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'style': styleKey,
    'bps': allocationBps,
    'allocated': allocatedAmount,
    'spent': spentAmount,
    'default': isDefault,
    'deleted': isDeleted,
  };
  factory Jar.fromJson(Map<String, dynamic> json) => Jar(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    styleKey: json['style'] as String,
    allocationBps: json['bps'] as int,
    allocatedAmount: json['allocated'] as int,
    spentAmount: json['spent'] as int,
    isDefault: json['default'] as bool,
    isDeleted: json['deleted'] as bool? ?? false,
  );
}

const defaultJars = [
  Jar(
    id: 'necessities',
    title: 'Hũ Thiết yếu',
    subtitle: 'Nhà ở, thực phẩm, sinh hoạt',
    styleKey: 'home',
    allocationBps: 5500,
    isDefault: true,
  ),
  Jar(
    id: 'long-term',
    title: 'Tiết kiệm dài hạn',
    subtitle: 'Dành dụm cho những mục tiêu lớn',
    styleKey: 'savings',
    allocationBps: 1000,
    isDefault: true,
  ),
  Jar(
    id: 'education',
    title: 'Giáo dục & Phát triển',
    subtitle: 'Đầu tư vào kiến thức và kỹ năng',
    styleKey: 'education',
    allocationBps: 1000,
    isDefault: true,
  ),
  Jar(
    id: 'enjoyment',
    title: 'Hưởng thụ & Giải trí',
    subtitle: 'Du lịch, cà phê và điều bạn thích',
    styleKey: 'enjoyment',
    allocationBps: 1000,
    isDefault: true,
  ),
  Jar(
    id: 'financial-freedom',
    title: 'Đầu tư Tự do tài chính',
    subtitle: 'Chuẩn bị cho tương lai của bạn',
    styleKey: 'investment',
    allocationBps: 1000,
    isDefault: true,
  ),
  Jar(
    id: 'giving',
    title: 'Cho đi & Thiện nguyện',
    subtitle: 'Chia sẻ cùng gia đình và cộng đồng',
    styleKey: 'giving',
    allocationBps: 500,
    isDefault: true,
  ),
];

class AllocationRecord {
  AllocationRecord({
    required this.id,
    required this.amount,
    required this.createdAt,
    required Map<String, int> amounts,
    required Map<String, int> ratios,
  }) : amounts = Map.unmodifiable(amounts),
       ratios = Map.unmodifiable(ratios);
  final String id;
  final int amount;
  final DateTime createdAt;
  final Map<String, int> amounts;
  final Map<String, int> ratios;
  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'at': createdAt.toIso8601String(),
    'amounts': amounts,
    'ratios': ratios,
  };
  factory AllocationRecord.fromJson(Map<String, dynamic> json) =>
      AllocationRecord(
        id: json['id'] as String,
        amount: json['amount'] as int,
        createdAt: DateTime.parse(json['at'] as String),
        amounts: Map<String, int>.from(json['amounts'] as Map),
        ratios: Map<String, int>.from(json['ratios'] as Map),
      );
}

class JarOverview {
  JarOverview({
    required List<Jar> jars,
    required List<AllocationRecord> history,
    required this.accountBalance,
    required this.revision,
    required this.isPersistent,
    List<Jar> deletedJars = const [],
  }) : jars = List.unmodifiable(jars),
       deletedJars = List.unmodifiable(deletedJars),
       history = List.unmodifiable(history);
  final List<Jar> jars;
  final List<Jar> deletedJars;
  final List<AllocationRecord> history;
  final int accountBalance;
  final int revision;
  final bool isPersistent;
  int get allocated => history.fold(0, (sum, record) => sum + record.amount);
  int get remaining => jars.fold(0, (sum, jar) => sum + jar.remainingAmount);
  int get unallocated => accountBalance - remaining;
  int get totalBps => jars.fold(0, (sum, jar) => sum + jar.allocationBps);
}

abstract interface class JarRepository {
  Stream<JarOverview> watchJars();
  Future<Jar> addJar({
    required String title,
    required String subtitle,
    required String styleKey,
    String? requestId,
  });
  Future<void> setAllocations(
    Map<String, int> ratios, {
    required int expectedRevision,
    String? requestId,
  });
  Future<void> deleteJar({
    required String jarId,
    required int expectedRevision,
    String? transferRatioToJarId,
    String? requestId,
  });
  Future<AllocationRecord> allocate({
    required int amount,
    required String requestId,
    int? expectedRevision,
  });
}

/// Largest remainders preserve every dong, including tiny contributions.
Map<String, int> splitAllocation(int amount, List<Jar> jars) {
  if (amount <= 0 ||
      jars.isEmpty ||
      jars.fold<int>(0, (sum, jar) => sum + jar.allocationBps) != 10000 ||
      jars.any((j) => j.allocationBps < 0 || j.allocationBps > 10000) ||
      jars.map((j) => j.id).toSet().length != jars.length) {
    throw const FinanceRuleException(
      'Tổng tỷ lệ phải đúng 100% trước khi phân bổ.',
    );
  }
  final result = {
    for (final jar in jars)
      jar.id:
          (BigInt.from(amount) *
                  BigInt.from(jar.allocationBps) ~/
                  BigInt.from(10000))
              .toInt(),
  };
  final ordered = [...jars]
    ..sort((a, b) {
      final comparison =
          (BigInt.from(amount) *
                  BigInt.from(b.allocationBps) %
                  BigInt.from(10000))
              .compareTo(
                BigInt.from(amount) *
                    BigInt.from(a.allocationBps) %
                    BigInt.from(10000),
              );
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
  final remainder =
      amount - result.values.fold<int>(0, (sum, value) => sum + value);
  for (var i = 0; i < remainder; i++) {
    result[ordered[i].id] = result[ordered[i].id]! + 1;
  }
  return result;
}
