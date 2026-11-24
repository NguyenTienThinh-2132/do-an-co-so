import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/finance_month_picker.dart';
import '../../domain/dashboard_repository.dart';
import '../providers/dashboard_controller.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/expense_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onAssistantRequested,
  });
  final DashboardController controller;
  final void Function([String? prompt]) onAssistantRequested;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final data = controller.overview;
      return Column(
        children: [
          _header(context),
          Expanded(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null
                ? _error(context)
                : data == null
                ? const Center(child: Text('Chưa có dữ liệu tổng quan.'))
                : ListView(
                    key: const PageStorageKey('home-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Tổng quan',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            key: const ValueKey('select-month'),
                            onPressed: () => _selectMonth(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: const Size(0, 36),
                              side: const BorderSide(color: AppColors.line),
                            ),
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                            ),
                            label: Text(
                              'Tháng ${controller.month.month}/${controller.month.year}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      BalanceCard(
                        overview: data,
                        visible: controller.balanceVisible,
                        onToggle: controller.toggleBalance,
                        month: controller.month,
                      ),
                      const SizedBox(height: 16),
                      BudgetCard(
                        overview: data,
                        visible: controller.balanceVisible,
                        onTap: () => _showBudget(context, data),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'Tiện ích của bạn'),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _quickAction(
                            'Thêm khoản chi',
                            Icons.add_rounded,
                            () => _addExpense(context, data),
                            primary: true,
                            key: const ValueKey('add-expense'),
                          ),
                          const SizedBox(width: 10),
                          _quickAction(
                            'Sổ giao dịch',
                            Icons.receipt_long_outlined,
                            () => _showTransactions(context, data),
                          ),
                          const SizedBox(width: 10),
                          _quickAction(
                            'Ngân sách',
                            Icons.donut_small_outlined,
                            () => _showBudget(context, data),
                          ),
                          const SizedBox(width: 10),
                          _quickAction(
                            'Phân tích',
                            Icons.bar_chart_rounded,
                            () => _showAnalytics(context, data),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _assistantCard(),
                      const SizedBox(height: 25),
                      _sectionTitle(
                        context,
                        'Mốc sắp tới',
                        action: 'Xem tất cả',
                        onAction: () => _showUpcoming(context, data),
                      ),
                      const SizedBox(height: 12),
                      HomeCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: data.upcoming.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Chưa có khoản thu chi sắp tới trong tháng này.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < data.upcoming.take(2).length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 1),
                                    UpcomingRow(
                                      entry: data.upcoming[i],
                                      visible: controller.balanceVisible,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 25),
                      _sectionTitle(
                        context,
                        'Giao dịch gần đây',
                        action: 'Xem tất cả',
                        onAction: () => _showTransactions(context, data),
                      ),
                      const SizedBox(height: 12),
                      HomeCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: data.transactions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 22,
                                  horizontal: 8,
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 30,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Chưa có giao dịch trong tháng này',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _addExpense(context, data),
                                      child: const Text(
                                        'Thêm khoản chi đầu tiên',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < data.transactions.take(3).length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 1),
                                    TransactionRow(
                                      transaction: data.transactions[i],
                                      visible: controller.balanceVisible,
                                      onTap: () => _showTransaction(
                                        context,
                                        data.transactions[i],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_outline_rounded,
                            size: 12,
                            color: AppColors.muted,
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Một chút chủ động, một ngày an tâm.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 16, 15),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA36CFF), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.auto_graph_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FinAI',
                style: TextStyle(
                  fontSize: 22,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Xin chào, Minh Quân',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () {
            final data = controller.overview;
            if (data != null) _showUpcoming(context, data);
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 24),
              if (controller.overview?.upcoming.isNotEmpty ?? false)
                Positioned(
                  top: 0,
                  right: 1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.pink,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'Hồ sơ',
          onPressed: () => _sheet(context, 'Hồ sơ', [
            const Text(
              'Minh Quân',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              controller.overview?.isPersistent == true
                  ? 'Hồ sơ và số dư khởi tạo là dữ liệu mẫu. Các thay đổi tài chính được lưu trên máy chủ.'
                  : 'Bạn đang dùng hồ sơ và dữ liệu mẫu trong bộ nhớ; các thay đổi sẽ mất khi khởi động lại ứng dụng.',
            ),
          ]),
          icon: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: AppColors.lilac,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDED0F8)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'MQ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _error(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.muted,
          ),
          const SizedBox(height: 16),
          Text(controller.error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.reload,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onAction,
  }) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (action != null)
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _quickAction(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool primary = false,
    Key? key,
  }) => Expanded(
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Column(
        children: [
          Container(
            height: 58,
            width: double.infinity,
            decoration: BoxDecoration(
              color: primary ? null : Colors.white,
              gradient: primary
                  ? const LinearGradient(
                      colors: [Color(0xFF9957F4), AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(17),
              border: primary ? null : Border.all(color: AppColors.line),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.17),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 25,
              color: primary ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 33,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: primary ? AppColors.primary : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _assistantCard() => InkWell(
    onTap: () => onAssistantRequested(),
    borderRadius: BorderRadius.circular(21),
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0E6FF), Color(0xFFF8F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE4D4FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFA267FF), AppColors.primary],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chi tiêu nhẹ đầu, có FinAI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A2080),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Hỏi một chút, chủ động hơn mỗi ngày.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF8C6CAC)),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ],
      ),
    ),
  );

  Future<void> _addExpense(BuildContext context, DashboardOverview data) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpenseSheet(
        onSave: controller.addExpense,
        date: controller.clock(),
        isDemo: data.isDemo,
        isPersistent: data.isPersistent,
        loadSources: controller.getExpenseSources,
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data.isDemo
                ? 'Đã thêm khoản chi vào dữ liệu mẫu.'
                : 'Đã thêm khoản chi.',
          ),
        ),
      );
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final selected = await showFinanceMonthPicker(context, controller.month);
    if (selected != null && context.mounted) controller.selectMonth(selected);
  }

  void _showTransactions(BuildContext context, DashboardOverview data) =>
      _sheet(context, 'Sổ giao dịch', [
        Text(
          'Tháng ${controller.month.month}/${controller.month.year}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (data.transactions.isEmpty)
          const Text('Chưa có giao dịch trong tháng này.'),
        for (final transaction in data.transactions)
          TransactionRow(
            transaction: transaction,
            visible: controller.balanceVisible,
            onTap: () => _showTransaction(context, transaction),
          ),
      ]);

  void _showTransaction(
    BuildContext context,
    DashboardTransaction transaction,
  ) => _sheet(context, 'Chi tiết giao dịch', [
    Text(transaction.title, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 16),
    MoneyText(
      transaction.amount,
      visible: controller.balanceVisible,
      signed: true,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: transaction.amount > 0 ? AppColors.green : AppColors.ink,
      ),
    ),
    const SizedBox(height: 16),
    Text(
      'Ngày ${transaction.occurredAt.day}/${transaction.occurredAt.month}/${transaction.occurredAt.year}',
    ),
    const SizedBox(height: 8),
    Text(
      'Danh mục: ${transaction.amount > 0 ? 'Thu nhập' : categoryAppearance(transaction.category).$3}',
    ),
    if (transaction.note?.isNotEmpty == true) ...[
      const SizedBox(height: 16),
      const Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(transaction.note!),
    ],
  ]);

  void _showUpcoming(BuildContext context, DashboardOverview data) =>
      _sheet(context, 'Mốc thu chi sắp tới', [
        const Text(
          'Các khoản dự kiến chưa làm thay đổi số dư hiện tại.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        if (data.upcoming.isEmpty)
          const Text('Chưa có khoản thu chi sắp tới trong tháng này.'),
        for (final entry in data.upcoming)
          UpcomingRow(entry: entry, visible: controller.balanceVisible),
      ]);

  void _showBudget(BuildContext context, DashboardOverview data) => _sheet(
    context,
    'Ngân sách tháng ${controller.month.month}',
    [
      const Text('Hạn mức chi tiêu', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 6),
      MoneyText(
        data.budget,
        visible: controller.balanceVisible,
        style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 20),
      BudgetCard(
        overview: data,
        visible: controller.balanceVisible,
        onTap: () => Navigator.pop(context),
      ),
      const SizedBox(height: 20),
      Text(
        data.expense > data.budget
            ? 'Bạn đã vượt ngân sách tháng. Hãy xem lại các khoản chi để cân đối nhé.'
            : 'Bạn vẫn đang trong ngân sách. Giữ nhịp chi tiêu này nhé!',
        style: const TextStyle(color: AppColors.muted),
      ),
    ],
  );

  void _showAnalytics(BuildContext context, DashboardOverview data) {
    final totals = <FinanceCategory, int>{};
    for (final transaction in data.transactions.where((t) => t.amount < 0)) {
      totals.update(
        transaction.category,
        (amount) => amount - transaction.amount,
        ifAbsent: () => -transaction.amount,
      );
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _sheet(context, 'Chi tiêu theo danh mục', [
      Text(
        'Tháng ${controller.month.month}/${controller.month.year}',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 20),
      if (sorted.isEmpty) const Text('Chưa có khoản chi để phân tích.'),
      for (final entry in sorted)
        Padding(
          padding: const EdgeInsets.only(bottom: 19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(categoryAppearance(entry.key).$3)),
                  MoneyText(
                    entry.value,
                    visible: controller.balanceVisible,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: data.expense > 0 ? entry.value / data.expense : 0,
                color: categoryAppearance(entry.key).$2,
                backgroundColor: AppColors.background,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      if (sorted.isNotEmpty)
        Text(
          'Tổng chi: ${controller.balanceVisible ? formatVnd(data.expense) : '••••••'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
    ]);
  }

  void _sheet(BuildContext context, String title, List<Widget> children) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      );
}
