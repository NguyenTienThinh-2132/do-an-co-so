import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/finance_month_picker.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../dashboard/domain/dashboard_repository.dart';
import '../../../dashboard/presentation/providers/dashboard_controller.dart';
import '../../../dashboard/presentation/widgets/dashboard_cards.dart';
import '../../../dashboard/presentation/widgets/expense_sheet.dart';
import '../../domain/cash_flow_report.dart';
import '../widgets/cash_flow_chart.dart';

String cashFlowTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key, required this.controller});
  final DashboardController controller;
  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  CashFlowType _type = CashFlowType.expense;
  FinanceCategory? _category;
  DateTime? _filterMonth;
  DashboardController get _controller => widget.controller;

  Future<void> _selectMonth() async {
    final selected = await showFinanceMonthPicker(context, _controller.month);
    if (selected != null && mounted) {
      setState(() => _category = null);
      _controller.selectMonth(selected);
    }
  }

  Future<void> _addExpense(DashboardOverview data) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpenseSheet(
        onSave: _controller.addExpense,
        date: _controller.clock(),
        isDemo: data.isDemo,
        isPersistent: data.isPersistent,
        loadSources: _controller.getExpenseSources,
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _type = CashFlowType.expense;
        _category = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu khoản chi và cập nhật dòng tiền.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final data = _controller.overview;
      return Column(
        key: const ValueKey('cash-flow-screen'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lilac,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.donut_large_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dòng tiền',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Thu chi rõ ràng, từng khoản một.',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('cashflow-toggle-money'),
                  tooltip: _controller.balanceVisible
                      ? 'Ẩn số tiền'
                      : 'Hiện số tiền',
                  onPressed: _controller.toggleBalance,
                  icon: Icon(
                    _controller.balanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 21,
                    color: AppColors.muted,
                  ),
                ),
                IconButton(
                  key: const ValueKey('cashflow-add-expense'),
                  tooltip: 'Thêm khoản chi',
                  onPressed:
                      data == null ||
                          _controller.loading ||
                          _controller.error != null
                      ? null
                      : () => _addExpense(data),
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _controller.loading
                ? const Center(child: CircularProgressIndicator())
                : data == null || _controller.error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 38,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa tải được dòng tiền. Bạn thử lại nhé.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _controller.reload,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _body(data),
          ),
        ],
      );
    },
  );

  Widget _body(DashboardOverview data) {
    final income = CashFlowReport.fromTransactions(
      transactions: data.transactions,
      month: _controller.month,
      type: CashFlowType.income,
    );
    final expense = CashFlowReport.fromTransactions(
      transactions: data.transactions,
      month: _controller.month,
      type: CashFlowType.expense,
    );
    final report = _type == CashFlowType.expense ? expense : income;
    final selected =
        _filterMonth == _controller.month &&
            report.groups.any((g) => g.category == _category)
        ? _category
        : null;
    final visible = selected == null
        ? report.transactions
        : report.transactions.where((t) => t.category == selected).toList();
    return ListView(
      key: const PageStorageKey('cashflow-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        _summary(data, income.total, expense.total),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _typeButton(
                CashFlowType.expense,
                'Chi tiêu',
                Icons.north_east_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _typeButton(
                CashFlowType.income,
                'Thu nhập',
                Icons.south_west_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _type == CashFlowType.expense
                    ? 'Cơ cấu chi tiêu'
                    : 'Cơ cấu thu nhập',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              const Text(
                'Tỷ trọng theo danh mục trong tháng',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              Center(
                child: CashFlowChart(
                  key: const ValueKey('cashflow-chart'),
                  report: report,
                  moneyVisible: _controller.balanceVisible,
                  selectedCategory: selected,
                ),
              ),
              const SizedBox(height: 18),
              if (report.groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      _type == CashFlowType.expense
                          ? 'Chưa có khoản chi trong tháng này.'
                          : 'Chưa có khoản thu trong tháng này.',
                      key: const ValueKey('cashflow-chart-empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                )
              else ...[
                for (final group in report.groups) _groupRow(group, selected),
                const SizedBox(height: 10),
                const Text(
                  'Tỷ lệ trên tổng của tháng, làm tròn 1 chữ số thập phân. Chạm danh mục để lọc giao dịch.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 5,
          children: [
            Text(
              _type == CashFlowType.expense ? 'Các khoản chi' : 'Các khoản thu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${visible.length} giao dịch',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          InputChip(
            key: const ValueKey('cashflow-clear-category'),
            label: Text(categoryAppearance(selected).$3),
            onDeleted: () => setState(() => _category = null),
            deleteButtonTooltipMessage: 'Bỏ lọc danh mục',
            backgroundColor: AppColors.lilac,
            side: BorderSide.none,
          ),
        ],
        const SizedBox(height: 12),
        if (visible.isEmpty)
          HomeCard(
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 10),
                Text(
                  _type == CashFlowType.expense
                      ? 'Chưa có khoản chi để hiển thị.'
                      : 'Chưa có khoản thu để hiển thị.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          )
        else
          for (final transaction in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _transactionCard(transaction),
            ),
      ],
    );
  }

  Widget _summary(DashboardOverview data, int income, int expense) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF3A1B63), AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'TỔNG QUAN THÁNG',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: Color(0xFFDDD0F1),
                ),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('cashflow-select-month'),
              onPressed: _selectMonth,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 13),
              label: Text(
                'Tháng ${_controller.month.month}/${_controller.month.year}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const Text(
          'Chênh lệch thu − chi',
          style: TextStyle(fontSize: 11, color: Color(0xFFDDD0F1)),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: MoneyText(
            income - expense,
            signed: true,
            visible: _controller.balanceVisible,
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Expanded(
              child: _summaryAmount(
                'Tổng thu',
                income,
                const Color(0xFF8BE3C3),
              ),
            ),
            Container(
              width: 1,
              height: 34,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: _summaryAmount(
                  'Tổng chi',
                  expense,
                  const Color(0xFFFFBBDA),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          data.isDemo
              ? 'Có dữ liệu mẫu · ${data.isPersistent ? 'Đã lưu trên máy chủ' : 'Phiên thử trong bộ nhớ'}'
              : data.isPersistent
              ? 'Đã lưu trên máy chủ'
              : 'Dữ liệu trong bộ nhớ',
          style: const TextStyle(fontSize: 9, color: Color(0xFFDDD0F1)),
        ),
      ],
    ),
  );

  Widget _summaryAmount(String title, int value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 10, color: Color(0xFFDDD0F1)),
      ),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: MoneyText(
          value,
          visible: _controller.balanceVisible,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );

  Widget _typeButton(CashFlowType type, String title, IconData icon) =>
      OutlinedButton.icon(
        key: ValueKey('cashflow-type-${type.name}'),
        style: OutlinedButton.styleFrom(
          backgroundColor: type == _type ? AppColors.primary : Colors.white,
          foregroundColor: type == _type ? Colors.white : AppColors.muted,
          side: BorderSide(
            color: type == _type ? AppColors.primary : AppColors.line,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        onPressed: () => setState(() {
          _type = type;
          _category = null;
        }),
        icon: Icon(icon, size: 15),
        label: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _groupRow(CashFlowGroup group, FinanceCategory? selected) {
    final style = categoryAppearance(group.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        key: ValueKey('cashflow-category-${group.category.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _category = selected == group.category ? null : group.category;
          _filterMonth = _controller.month;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
          decoration: BoxDecoration(
            color: selected == group.category
                ? AppColors.lilac
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: style.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.$3,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${group.count} giao dịch',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      group.percentLabel,
                      key: ValueKey('cashflow-percent-${group.category.name}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: style.$2,
                      ),
                    ),
                    MoneyText(
                      group.amount,
                      visible: _controller.balanceVisible,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionCard(DashboardTransaction transaction) {
    final style = categoryAppearance(transaction.category);
    return Material(
      key: ValueKey('cashflow-transaction-${transaction.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _details(transaction),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: style.$2.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(style.$1, color: style.$2, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          style.$3,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MoneyText(
                transaction.amount,
                signed: true,
                visible: _controller.balanceVisible,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: transaction.amount > 0
                      ? AppColors.green
                      : AppColors.pink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cashFlowTimestamp(transaction.occurredAt),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Ghi chú: ${transaction.note?.trim().isNotEmpty == true ? transaction.note! : 'Chưa có ghi chú'}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
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

  void _details(DashboardTransaction transaction) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chi tiết giao dịch',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                transaction.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              MoneyText(
                transaction.amount,
                signed: true,
                visible: _controller.balanceVisible,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: transaction.amount > 0
                      ? AppColors.green
                      : AppColors.pink,
                ),
              ),
              const SizedBox(height: 16),
              Text('Loại: ${transaction.amount > 0 ? 'Thu nhập' : 'Chi tiêu'}'),
              const SizedBox(height: 8),
              Text('Danh mục: ${categoryAppearance(transaction.category).$3}'),
              const SizedBox(height: 8),
              Text('Thời gian: ${cashFlowTimestamp(transaction.occurredAt)}'),
              const SizedBox(height: 20),
              const Text(
                'Ghi chú',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SelectableText(
                transaction.note?.trim().isNotEmpty == true
                    ? transaction.note!
                    : 'Chưa có ghi chú',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
