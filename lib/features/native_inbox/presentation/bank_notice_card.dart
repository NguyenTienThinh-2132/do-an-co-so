import 'package:flutter/material.dart';

import '../domain/native_event.dart';
import '../domain/bank_notification_parser.dart';

class BankNoticeCard extends StatelessWidget {
  const BankNoticeCard({
    super.key,
    required this.event,
    required this.showContent,
    required this.onAcknowledge,
  });
  final NativeEvent event;
  final bool showContent;
  final VoidCallback? onAcknowledge;
  @override
  Widget build(BuildContext context) {
    final result = const BankNotificationParser().parse(event);
    final bank = event.data['bankName'] as String? ?? 'Ngân hàng';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bank,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7C3AED),
              ),
            ),
            Text(event.data['packageName'] as String? ?? ''),
            const Text(
              'Nhận diện theo tên app • chưa xác minh ứng dụng chính chủ',
              style: TextStyle(fontSize: 12),
            ),
            if (result.status == BankNoticeStatus.parsed) ...[
              Text(
                result.direction == BankMoneyDirection.income
                    ? 'Cộng tiền'
                    : 'Trừ tiền',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                showContent
                    ? 'Số tiền: ${result.amountVnd} VND'
                    : 'Số tiền: •••• VND',
              ),
              Text(
                !showContent
                    ? 'Nội dung: đã ẩn'
                    : result.description == null || result.description!.isEmpty
                    ? 'Nội dung: chưa xác định'
                    : 'Nội dung: ${result.description}',
              ),
            ] else
              Text(
                result.status == BankNoticeStatus.ignored
                    ? 'Đã loại khỏi kết quả giao dịch'
                    : 'Chưa tách được giao dịch',
              ),
            Text(result.reason),
            const Text(
              'Chỉ đọc tham khảo • chưa lưu giao dịch',
              style: TextStyle(fontSize: 12),
            ),
            TextButton(
              onPressed: onAcknowledge,
              child: const Text('Xác nhận đã nhận'),
            ),
          ],
        ),
      ),
    );
  }
}
