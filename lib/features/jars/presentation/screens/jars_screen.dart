import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/jar_repository.dart';
import '../models/jar_view_data.dart';
import '../providers/jars_controller.dart';
import '../widgets/jar_card.dart';
import '../widgets/jar_forms.dart';

class JarsScreen extends StatelessWidget {
  const JarsScreen({
    super.key,
    required this.controller,
    this.moneyVisible = true,
  });
  final JarsController controller;
  final bool moneyVisible;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final data = controller.overview;
      return Column(
        key: const ValueKey('jars-screen'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
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
                    Icons.savings_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý hũ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Dành chỗ cho những điều quan trọng.',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Lịch sử phân bổ',
                  onPressed: data == null
                      ? null
                      : () => _history(context, data),
                  icon: const Icon(
                    Icons.history_rounded,
                    color: AppColors.muted,
                    size: 22,
                  ),
                ),
                IconButton(
                  tooltip: 'Về các hũ tài chính',
                  onPressed: () => _help(context),
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.muted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null || data == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.error ?? 'Chưa tải được các hũ.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: controller.reload,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    key: const PageStorageKey('jars-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                    children: [
                      _summary(context, data),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('add-jar'),
                              onPressed: () => _add(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Thêm hũ',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('edit-ratios'),
                              onPressed: () => _editRatios(context, data),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text(
                                'Chỉnh tỷ lệ',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      Wrap(
                        spacing: 10,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Hệ thống ${data.jars.length} hũ tài chính',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lilac,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'Tổng tỷ lệ: ${formatBps(data.totalBps)}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '6 hũ mặc định và các hũ bạn thêm. Tỷ lệ mới chỉ áp dụng cho lần phân bổ tiếp theo.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final jar in data.jars)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: JarCard(
                            key: ValueKey('jar-${jar.id}'),
                            jar: JarViewData(jar),
                            moneyVisible: moneyVisible,
                            onTap: () => _jarDetails(context, jar),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.primary,
                              size: 21,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tự động cân bằng FinAI',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Sắp ra mắt',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(value: false, onChanged: null),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );

  Widget _summary(BuildContext context, JarOverview data) => Container(
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
        const Text(
          'TIỀN HIỆN CÓ TRONG HŨ',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDDD0F1),
          ),
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: MoneyText(
            data.remaining,
            visible: moneyVisible,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          data.isPersistent ? 'Đã lưu trên máy chủ' : 'Phiên thử trong bộ nhớ',
          style: const TextStyle(fontSize: 10, color: Color(0xFFDDD0F1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        _summaryRow('Đã phân bổ lũy kế', data.allocated),
        const SizedBox(height: 10),
        _summaryRow(
          'Chưa phân bổ',
          data.unallocated,
          color: const Color(0xFF8BE3C3),
        ),
        const SizedBox(height: 17),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('allocate-money'),
            onPressed: data.unallocated <= 0
                ? null
                : () => _allocate(context, data),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Phân bổ thêm'),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Chia tiền đang có vào hũ, không cộng thêm vào số dư tài khoản.',
          style: TextStyle(fontSize: 10, color: Color(0xFFDDD0F1), height: 1.5),
        ),
      ],
    ),
  );

  Widget _summaryRow(String label, int amount, {Color color = Colors.white}) =>
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFFDDD0F1)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: MoneyText(
              amount,
              visible: moneyVisible,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      );

  Future<void> _openForm(
    BuildContext context,
    Widget form,
    String success,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => form,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
  }

  void _add(BuildContext context) => _openForm(
    context,
    AddJarSheet(repository: controller.repository),
    'Đã thêm hũ với tỷ lệ 0%. Chỉnh tỷ lệ để hũ nhận tiền nhé.',
  );
  void _editRatios(BuildContext context, JarOverview data) => _openForm(
    context,
    AllocationRatiosSheet(repository: controller.repository, overview: data),
    'Đã lưu tỷ lệ cho các lần phân bổ tiếp theo.',
  );
  void _allocate(BuildContext context, JarOverview data) => _openForm(
    context,
    AllocateMoneySheet(
      repository: controller.repository,
      overview: data,
      moneyVisible: moneyVisible,
    ),
    'Đã phân bổ tiền vào các hũ. Tổng số dư tài khoản giữ nguyên.',
  );

  void _jarDetails(BuildContext context, Jar jar) async {
    final view = JarViewData(jar);
    var deleteRequested = false;
    await _sheet(context, jar.title, [
      Text(
        jar.isDefault ? 'Hũ mặc định' : 'Hũ do bạn thêm',
        style: const TextStyle(fontSize: 11, color: AppColors.primary),
      ),
      const SizedBox(height: 10),
      Text(jar.subtitle.isEmpty ? 'Mục tiêu tài chính của bạn' : jar.subtitle),
      const SizedBox(height: 20),
      _detail(
        'Tỷ lệ cho lần phân bổ tiếp theo',
        Text(
          view.allocationLabel,
          style: TextStyle(color: view.color, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 16),
      _detail(
        'Được phân bổ',
        MoneyText(jar.allocatedAmount, visible: moneyVisible),
      ),
      const SizedBox(height: 16),
      _detail('Đã chi', MoneyText(jar.spentAmount, visible: moneyVisible)),
      const SizedBox(height: 16),
      _detail(
        'Còn lại',
        MoneyText(
          jar.remainingAmount,
          visible: moneyVisible,
          style: TextStyle(color: view.color, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Khi thêm khoản chi ở Trang chủ, chọn hũ này trong mục “Trừ tiền từ” để cập nhật cả số dư tài khoản và hũ.',
        style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      if (jar.isDefault)
        const Text(
          'Hũ mặc định được giữ lại. Chỉ hũ tự thêm mới có thể xóa.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        )
      else
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('delete-jar'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.pink),
            onPressed: () {
              deleteRequested = true;
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Xóa hũ'),
          ),
        ),
    ]);
    if (!deleteRequested || !context.mounted) return;
    final data = controller.overview;
    if (data == null || !data.jars.any((j) => j.id == jar.id)) return;
    _openForm(
      context,
      DeleteJarSheet(
        repository: controller.repository,
        overview: data,
        jar: data.jars.firstWhere((j) => j.id == jar.id),
        moneyVisible: moneyVisible,
      ),
      'Đã xóa hũ. Tiền còn lại đã trả về phần chưa phân bổ.',
    );
  }

  Widget _detail(String label, Widget value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(child: value),
    ],
  );

  void _history(
    BuildContext context,
    JarOverview data,
  ) => _sheet(context, 'Lịch sử phân bổ', [
    if (data.history.isEmpty)
      const Text('Chưa có lần phân bổ nào. Nhấn “Phân bổ thêm” để bắt đầu.'),
    for (final record in data.history)
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail(
              '${record.createdAt.toLocal().day}/${record.createdAt.toLocal().month}/${record.createdAt.toLocal().year}',
              MoneyText(
                record.amount,
                visible: moneyVisible,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in record.amounts.entries.where(
              (e) => e.value > 0,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _detail(
                  _historyJarTitle(data, entry.key),
                  MoneyText(
                    entry.value,
                    visible: moneyVisible,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            const Divider(height: 24),
          ],
        ),
      ),
  ]);

  String _historyJarTitle(JarOverview data, String id) {
    for (final jar in [...data.jars, ...data.deletedJars]) {
      if (jar.id == id) {
        return '${jar.title}${jar.isDeleted ? ' (đã xóa)' : ''}';
      }
    }
    return 'Hũ đã xóa';
  }

  void _help(BuildContext context) => _sheet(context, 'Phân bổ tiền vào hũ', [
    const Text(
      'Bạn bắt đầu với 6 hũ mặc định và có thể thêm hũ mới. Hũ mới có tỷ lệ 0% và số dư 0 ₫.',
    ),
    const SizedBox(height: 16),
    const Text(
      'Tổng tỷ lệ phải đúng 100%. Giảm một hũ để dành phần trăm cho hũ khác. Đổi tỷ lệ không chia lại tiền đã có trong hũ.',
    ),
    const SizedBox(height: 16),
    const Text(
      '“Phân bổ thêm” lấy tiền từ phần chưa phân bổ, không tạo khoản thu mới. Số tiền chia vào các hũ luôn đúng bằng số tiền bạn nhập.',
    ),
    const SizedBox(height: 16),
    const Text(
      'Khi chi tiền, chọn hũ hoặc tiền chưa phân bổ. Giao dịch chỉ trừ một lần vào số dư tài khoản.',
    ),
    const SizedBox(height: 16),
    const Text(
      'Chạm vào hũ tự thêm rồi chọn “Xóa hũ”. Tiền còn lại trả về phần chưa phân bổ; bạn chọn hũ nhận tỷ lệ, còn lịch sử cũ được giữ lại. Sáu hũ mặc định không bị xóa.',
    ),
  ]);

  Future<void> _sheet(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => showModalBottomSheet<void>(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
