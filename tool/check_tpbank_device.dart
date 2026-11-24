import 'dart:convert';
import 'dart:io';

import 'package:finai/features/native_inbox/domain/bank_notification_parser.dart';
import 'package:finai/features/native_inbox/domain/native_event.dart';

/// Đọc payload qua stdin trong bộ nhớ, chỉ xuất kết quả bool/enum.
/// Không ghi dữ liệu ngân hàng thật ra file hoặc stdout.
Future<void> main() async {
  final input = await stdin.transform(utf8.decoder).join();
  final events = jsonDecode(input) as List;
  for (final raw in events) {
    final event = NativeEvent.fromPlatform(raw);
    if (event.data['packageName'] != 'com.tpb.mb.gprsandroid') continue;
    final result = const BankNotificationParser().parse(event);
    final body = '${event.data['title'] ?? ''}\n${event.data['text'] ?? ''}';
    int? number(String label) {
      final m = RegExp(
        '(?:^|\\n)\\s*$label\\s*:\\s*([+\\-−]?)([0-9.,]+)VND',
        caseSensitive: false,
      ).firstMatch(body);
      if (m == null) return null;
      final n = int.tryParse(m[2]!.replaceAll(RegExp(r'[.,]'), ''));
      return n == null ? null : (m[1] == '-' || m[1] == '−' ? -n : n);
    }

    final ps = number('PS');
    stdout.writeln(
      jsonEncode({
        'sourcePackageMatchesTpbank': true,
        'status': result.status.name,
        'direction': result.direction?.name,
        'amountMatchesPs': ps != null && result.amountVnd == ps.abs(),
        'directionMatchesPs':
            ps != null &&
            ((ps < 0 && result.direction == BankMoneyDirection.expense) ||
                (ps > 0 && result.direction == BankMoneyDirection.income)),
        'descriptionPresent': result.description?.isNotEmpty == true,
      }),
    );
  }
  if (events.isEmpty) stdout.writeln('NO_TPBANK_EVENT');
}
