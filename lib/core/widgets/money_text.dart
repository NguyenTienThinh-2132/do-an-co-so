import 'package:flutter/material.dart';

import '../utils/money_format.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.visible = true,
    this.signed = false,
  });

  final int amount;
  final TextStyle? style;
  final bool visible;
  final bool signed;

  @override
  Widget build(BuildContext context) => Text(
    visible ? formatVnd(amount, signed: signed) : '••••••',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: (style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
