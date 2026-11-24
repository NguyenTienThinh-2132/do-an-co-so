import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/dashboard_repository.dart';

class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF38215B).withValues(alpha: 0.025),
          blurRadius: 20,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.overview,
    required this.visible,
    required this.onToggle,
    required this.month,
  });
  final DashboardOverview overview;
  final bool visible;
  final VoidCallback onToggle;
  final DateTime month;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B154D), Color(0xFF6230AF), Color(0xFF813BE0)],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.18),
          blurRadius: 22,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(right: -58, top: -56, child: _ring(220)),
        Positioned(right: -19, top: -17, child: _ring(142)),
        Positioned(
          right: 35,
          top: 54,
          child: Transform.rotate(
            angle: 0.6,
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.045),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 13, 21, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: Color(0xFFDBC8FF),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SỐ DƯ HIỆN TẠI',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFDBC8FF),
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('toggle-balance'),
                    tooltip: visible ? 'Ẩn số dư' : 'Hiện số dư',
                    onPressed: onToggle,
                    icon: Icon(
                      visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: const Color(0xFFDBC8FF),
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(
                  overview.balance,
                  visible: visible,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Tất cả tài khoản',
                    style: TextStyle(color: Color(0xFFDDD0F1), fontSize: 11),
                  ),
                  if (overview.isDemo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Dữ liệu mẫu',
                        style: TextStyle(fontSize: 9, color: Color(0xFFEADFFF)),
                      ),
                    ),
                  ],
                ],
              ),
              if (overview.initialBalance != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  key: const ValueKey('balance-explanation'),
                  onTap: () => _showExplanation(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Color(0xFFDDD0F1),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Tiền ban đầu',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFDDD0F1),
                            ),
                          ),
                        ),
                        Flexible(
                          child: MoneyText(
                            overview.initialBalance!,
                            visible: visible,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: Color(0xFFDDD0F1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _flow(
                      'Thu tháng ${month.month}',
                      overview.income,
                      const Color(0xFF8BE3C3),
                      Icons.south_west_rounded,
                    ),
                  ),
                  Container(
                    height: 31,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _flow(
                      'Chi tháng ${month.month}',
                      overview.expense,
                      const Color(0xFFFFB0C8),
                      Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chênh lệch thu − chi tháng',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFDDD0F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: MoneyText(
                        overview.monthlyNetChange,
                        visible: visible,
                        signed: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: overview.monthlyNetChange >= 0
                              ? const Color(0xFF8BE3C3)
                              : const Color(0xFFFFB0C8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showExplanation(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cách tính số dư',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Số dư hiện tại = tiền ban đầu + thu đã ghi nhận − chi đã ghi nhận.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              _explanationRow('Tiền ban đầu', overview.initialBalance!),
              const SizedBox(height: 16),
              _explanationRow(
                'Biến động từ mọi giao dịch',
                overview.recordedNetChange!,
                signed: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),
              _explanationRow('Số dư hiện tại', overview.balance),
              const SizedBox(height: 22),
              Text(
                'Thu/chi và chênh lệch tháng bên dưới thẻ chỉ thuộc tháng ${month.month}/${month.year}. Số dư hiện tại tính toàn bộ giao dịch, nên không thay đổi khi bạn chọn tháng khác.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _explanationRow(String label, int amount, {bool signed = false}) =>
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 12),
          Flexible(
            child: MoneyText(
              amount,
              visible: visible,
              signed: signed,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.075),
        width: 1,
      ),
    ),
  );

  Widget _flow(String label, int amount, Color color, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFDDD0F1)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      MoneyText(
        amount,
        visible: visible,
        style: TextStyle(
          fontSize: 15,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.overview,
    required this.visible,
    required this.onTap,
  });
  final DashboardOverview overview;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = overview.budget > 0
        ? overview.expense / overview.budget
        : 0.0;
    final overBudget = overview.expense > overview.budget;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: HomeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.lilac,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.donut_small_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Ngân sách tháng',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Text(
                  '${(ratio * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
                  style: TextStyle(
                    color: overBudget ? AppColors.pink : AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: AppColors.lilac,
              color: overBudget ? AppColors.pink : AppColors.primary,
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                const Text(
                  'Đã chi ',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                Expanded(
                  child: MoneyText(
                    overview.expense,
                    visible: visible,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  overBudget ? 'Vượt ' : 'Còn ',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                Flexible(
                  child: MoneyText(
                    (overview.budget - overview.expense).abs(),
                    visible: visible,
                    style: TextStyle(
                      fontSize: 10,
                      color: overBudget ? AppColors.pink : AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color, String) categoryAppearance(FinanceCategory category) =>
    switch (category) {
      FinanceCategory.food => (
        Icons.local_cafe_outlined,
        const Color(0xFFCE8734),
        'Ăn uống',
      ),
      FinanceCategory.transport => (
        Icons.directions_car_outlined,
        const Color(0xFF218D77),
        'Di chuyển',
      ),
      FinanceCategory.shopping => (
        Icons.shopping_bag_outlined,
        const Color(0xFFC65E9B),
        'Mua sắm',
      ),
      FinanceCategory.education => (
        Icons.school_outlined,
        const Color(0xFF4C80C9),
        'Học tập',
      ),
      FinanceCategory.housing => (
        Icons.home_work_outlined,
        AppColors.primary,
        'Nhà ở',
      ),
      FinanceCategory.other => (
        Icons.receipt_long_outlined,
        AppColors.muted,
        'Khác',
      ),
    };

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.visible,
    this.onTap,
  });
  final DashboardTransaction transaction;
  final bool visible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = categoryAppearance(transaction.category);
    final date = transaction.occurredAt;
    final income = transaction.amount > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: (income ? AppColors.green : color).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          income ? Icons.account_balance_outlined : icon,
          color: income ? AppColors.green : color,
          size: 21,
        ),
      ),
      title: Text(
        transaction.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${income ? 'Thu nhập' : label} · ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      ),
      trailing: SizedBox(
        width: 117,
        child: Align(
          alignment: Alignment.centerRight,
          child: MoneyText(
            transaction.amount,
            visible: visible,
            signed: true,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: income ? AppColors.green : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class UpcomingRow extends StatelessWidget {
  const UpcomingRow({super.key, required this.entry, required this.visible});
  final UpcomingEntry entry;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final income = entry.amount > 0;
    final color = income ? AppColors.green : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${entry.dueAt.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  'TH ${entry.dueAt.month}',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  income ? 'Khoản thu dự kiến' : 'Khoản chi dự kiến',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: MoneyText(
              entry.amount,
              visible: visible,
              signed: true,
              style: TextStyle(
                color: income ? AppColors.green : AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
