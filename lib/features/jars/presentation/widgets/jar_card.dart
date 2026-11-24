import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../models/jar_view_data.dart';

class JarCard extends StatelessWidget {
  const JarCard({
    super.key,
    required this.jar,
    required this.moneyVisible,
    required this.onTap,
  });
  final JarViewData jar;
  final bool moneyVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(21),
      side: const BorderSide(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: jar.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(jar.icon, color: jar.color, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jar.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        jar.subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (jar.isLocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Được phân bổ',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      MoneyText(
                        jar.allocatedAmount,
                        visible: moneyVisible,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: jar.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    jar.allocationLabel,
                    style: TextStyle(
                      color: jar.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: jar.usageProgress,
              color: jar.isOverspent ? AppColors.pink : jar.color,
              backgroundColor: jar.color.withValues(alpha: 0.07),
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _stat('Đã chi', jar.spentAmount, AppColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(
                    'Còn lại',
                    jar.remainingAmount,
                    jar.isOverspent ? AppColors.pink : jar.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stat(String label, int amount, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      const SizedBox(height: 3),
      MoneyText(
        amount,
        visible: moneyVisible,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}
