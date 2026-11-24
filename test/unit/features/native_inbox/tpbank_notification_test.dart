import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/native_inbox/domain/bank_catalog.dart';
import 'package:finai/features/native_inbox/domain/bank_notification_parser.dart';
import 'package:finai/features/native_inbox/domain/native_event.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/native_inbox/tpbank_redacted.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  NativeEvent event({String? text, String bankId = 'tpb'}) => NativeEvent(
    id: 'redacted',
    kind: 'bankNotification',
    receivedAt: DateTime.utc(2026, 11, 12),
    data: {
      'bankId': bankId,
      'title': fixture['title'],
      'text': text ?? fixture['text'],
    },
  );
  const parser = BankNotificationParser();
  test('từ khóa cộng/trừ và ký hiệu đồng dùng chung', () {
    expect(
      parser.parse(event(text: 'Tài khoản cộng tiền 500.000 ₫')).direction,
      BankMoneyDirection.income,
    );
    expect(
      parser.parse(event(text: 'Tài khoản trừ tiền 50.000 VND')).direction,
      BankMoneyDirection.expense,
    );
    expect(
      parser.parse(event(text: 'Account debited 50,000 VND')).direction,
      BankMoneyDirection.expense,
    );
  });
  test('quy tắc chung đọc PS, bỏ SD và SD KHA DUNG, lấy ND nhiều dòng', () {
    final r = parser.parse(event());
    expect(r.status, BankNoticeStatus.parsed);
    expect(r.direction, BankMoneyDirection.expense);
    expect(r.amountVnd, 75000);
    expect(r.description, contains('THU NGHIEM'));
    expect(r.description, contains('[ACCOUNT]'));
    expect(r.description, isNot(contains('[REFERENCE]')));
  });
  test(
    'cùng nội dung dùng một quy tắc cho mọi ID, không rẽ nhánh tên ngân hàng',
    () {
      for (final bank in vietnamBankCatalog) {
        final r = parser.parse(event(bankId: bank.id));
        expect(r.status, BankNoticeStatus.parsed, reason: bank.name);
        expect(r.amountVnd, 75000);
        expect(r.direction, BankMoneyDirection.expense);
      }
    },
  );
  test('PS dương là cộng, không cần phụ thuộc giờ', () {
    final r = parser.parse(
      event(text: (fixture['text'] as String).replaceFirst('PS:-', 'PS:+')),
    );
    expect(r.direction, BankMoneyDirection.income);
    expect(r.amountVnd, 75000);
  });
  test('thiếu dấu và nhiều PS không được đoán', () {
    for (final body in [
      (fixture['text'] as String).replaceFirst('PS:-', 'PS:'),
      '${fixture['text']}\nPS:+1.000VND',
    ]) {
      expect(
        parser.parse(event(text: body)).status,
        BankNoticeStatus.unrecognized,
      );
    }
  });
  test('OTP vẫn bị loại', () {
    expect(
      parser.parse(event(text: '${fixture['text']}\nOTP 000000')).status,
      BankNoticeStatus.ignored,
    );
  });
}
