import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

Future<DateTime?> showFinanceMonthPicker(
  BuildContext context,
  DateTime initialMonth,
) {
  var year = initialMonth.year;
  return showModalBottomSheet<DateTime>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Năm trước',
                      onPressed: year > 1970
                          ? () => setSheetState(() => year--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        'Chọn tháng · $year',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Năm sau',
                      onPressed: year < 2100
                          ? () => setSheetState(() => year++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 1.8,
                  children: List.generate(12, (index) {
                    final active =
                        initialMonth.year == year &&
                        initialMonth.month == index + 1;
                    return OutlinedButton(
                      key: ValueKey('month-${index + 1}'),
                      onPressed: () =>
                          Navigator.pop(context, DateTime(year, index + 1)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: active
                            ? AppColors.lilac
                            : Colors.white,
                        side: BorderSide(
                          color: active ? AppColors.primary : AppColors.line,
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Tháng ${index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
