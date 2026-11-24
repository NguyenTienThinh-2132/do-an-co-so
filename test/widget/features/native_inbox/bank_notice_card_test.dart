import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/native_inbox/presentation/bank_notice_card.dart';
import 'package:finai/features/native_inbox/domain/native_event.dart';

NativeEvent fixture({String text = '+250.000 VND; SD: 500.000 VND'}) =>
    NativeEvent(
      id: 'synthetic',
      kind: 'bankNotification',
      receivedAt: DateTime.utc(2026, 11, 12),
      data: {
        'bankId': 'tpb',
        'bankName': 'Mẫu tự tạo',
        'packageName': 'example.synthetic',
        'title': 'Biến động',
        'text': text,
      },
    );
void main() {
  testWidgets(
    'ẩn tiền mặc định, hiển thị cảnh báo nguồn và ack do người dùng',
    (tester) async {
      var acknowledged = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BankNoticeCard(
              event: fixture(),
              showContent: false,
              onAcknowledge: () {
                acknowledged = true;
              },
            ),
          ),
        ),
      );
      expect(find.text('Cộng tiền'), findsOneWidget);
      expect(find.text('Số tiền: •••• VND'), findsOneWidget);
      expect(find.textContaining('250000'), findsNothing);
      expect(find.textContaining('chưa xác minh'), findsOneWidget);
      expect(acknowledged, isFalse);
      await tester.tap(find.text('Xác nhận đã nhận'));
      await tester.pump();
      expect(acknowledged, isTrue);
    },
  );
  testWidgets('hiện kết quả khi đồng ý xem nội dung, không tự thêm giao dịch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BankNoticeCard(
            event: fixture(),
            showContent: true,
            onAcknowledge: null,
          ),
        ),
      ),
    );
    expect(find.text('Số tiền: 250000 VND'), findsOneWidget);
    expect(find.textContaining('Số dư:'), findsNothing);
    expect(find.text('Nội dung: chưa xác định'), findsOneWidget);
    expect(find.textContaining('chưa lưu giao dịch'), findsOneWidget);
  });
  testWidgets('mẫu không hiểu hiển thị rõ chưa tách được', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BankNoticeCard(
            event: fixture(text: 'Thông báo không đủ dữ kiện'),
            showContent: false,
            onAcknowledge: null,
          ),
        ),
      ),
    );
    expect(find.text('Chưa tách được giao dịch'), findsOneWidget);
    expect(find.text('Cộng tiền'), findsNothing);
    expect(find.text('Trừ tiền'), findsNothing);
  });
}
