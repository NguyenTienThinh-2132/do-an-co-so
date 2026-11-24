import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../dashboard/domain/dashboard_repository.dart';
import '../../../dashboard/presentation/widgets/dashboard_cards.dart';
import '../../domain/cash_flow_report.dart';

class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    super.key,
    required this.report,
    required this.moneyVisible,
    this.selectedCategory,
  });
  final CashFlowReport report;
  final bool moneyVisible;
  final FinanceCategory? selectedCategory;
  @override
  Widget build(BuildContext context) => Semantics(
    label: report.total == 0
        ? 'Chưa có dữ liệu biểu đồ'
        : 'Biểu đồ tỷ trọng ${report.type == CashFlowType.expense ? 'chi tiêu' : 'thu nhập'} theo danh mục',
    child: SizedBox(
      width: 206,
      height: 206,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DonutPainter(report, selectedCategory),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(45),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  report.type == CashFlowType.expense ? 'TỔNG CHI' : 'TỔNG THU',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MoneyText(
                    report.total,
                    visible: moneyVisible,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${report.transactions.length} giao dịch',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.report, this.selected);
  final CashFlowReport report;
  final FinanceCategory? selected;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 31.0;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = AppColors.line);
    if (report.total <= 0) return;
    var start = -math.pi / 2;
    for (final group in report.groups) {
      final sweep = group.amount / report.total * math.pi * 2;
      final baseColor = categoryAppearance(group.category).$2;
      paint.color = selected == null || selected == group.category
          ? baseColor
          : baseColor.withValues(alpha: 0.25);
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.report != report || oldDelegate.selected != selected;
}
