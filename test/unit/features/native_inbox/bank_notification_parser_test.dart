import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/native_inbox/domain/bank_catalog.dart';
import 'package:finai/features/native_inbox/domain/native_event.dart';
import 'package:finai/features/native_inbox/domain/bank_notification_parser.dart';

// Fixture tự tạo, không phải mẫu ngân hàng thật đã kiểm chứng.
NativeEvent notice(
  String text, {
  String title = 'Biến động tài khoản',
  bool truncated = false,
  String id = 'tpb',
}) => NativeEvent(
  id: 'synthetic',
  kind: 'bankNotification',
  receivedAt: DateTime.utc(2026, 11, 12, 8),
  data: {'bankId': id, 'text': text, 'title': title, 'truncated': truncated},
);
void main() {
  const parser = BankNotificationParser();
  test('fixture bàn giao tự tạo khớp kết quả kỳ vọng', () {
    final fixture = jsonDecode(
      File('test/fixtures/native_inbox/bank_notifications_synthetic.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      fixture['provenance'],
      'synthetic_only_not_verified_bank_notifications',
    );
    for (final sample in fixture['cases'] as List) {
      final result = parser.parse(notice(sample['text'] as String));
      expect(
        result.status.name,
        sample['status'],
        reason: sample['name'] as String,
      );
      if (sample['status'] == 'parsed') {
        expect(result.amountVnd, sample['amountVnd']);
        expect(result.direction!.name, sample['direction']);
      }
    }
  });
  test('số tài khoản trước tiền có dấu không bị hiểu là phân nhóm nghìn', () {
    final result = parser.parse(notice('TK 1234567890 +500.000 VND'));
    expect(result.status, BankNoticeStatus.parsed);
    expect(result.amountVnd, 500000);
  });
  test('Native asset giống nguồn danh mục Dart, không bị lệch tên', () {
    final rows = jsonDecode(
      File('android/app/src/main/assets/finai_bank_catalog.json')
          .readAsStringSync(),
    );
    expect(rows, [
      for (final e in vietnamBankCatalog)
        {'id': e.id, 'name': e.name, 'aliases': e.aliases},
    ]);
  });
  test('tách thu và số dư riêng, giờ VN sang UTC, mô tả che số dài', () {
    final r = parser.parse(
      notice(
        'TK **** +1,250,000 VND lúc 12/11/2026 15:30:05\nSố dư: 2,500,000 VND\nND: chuyen TK 1234567890',
      ),
    );
    expect(r.status, BankNoticeStatus.parsed);
    expect(r.amountVnd, 1250000);
    expect(r.direction, BankMoneyDirection.income);
    expect(r.balanceVnd, 2500000);
    expect(r.transactionAt, DateTime.utc(2026, 11, 12, 8, 30, 5));
    expect(r.description, contains('****'));
    expect(r.description, isNot(contains('1234567890')));
  });
  test('tách chi và nhóm nghìn kiểu Việt Nam', () {
    final r = parser.parse(notice('TK **** -250.000 VNĐ. SD: 1.000.000 VNĐ'));
    expect(r.status, BankNoticeStatus.parsed);
    expect(r.amountVnd, 250000);
    expect(r.direction, BankMoneyDirection.expense);
    expect(r.balanceVnd, 1000000);
    expect(r.transactionAt, isNull);
  });
  test('dấu âm unicode và số dư âm', () {
    final r = parser.parse(notice('−100000 VND; số dư: -20000 VND'));
    expect(r.amountVnd, 100000);
    expect(r.direction, BankMoneyDirection.expense);
    expect(r.balanceVnd, -20000);
  });
  test('hỗ trợ .00 và ,00 không làm tròn tiền', () {
    for (final amount in [
      '1,250,000.00',
      '1.250.000,00',
      '1250000.00',
      '1250000,00',
    ]) {
      expect(
        parser.parse(notice('+$amount VND')).amountVnd,
        1250000,
        reason: amount,
      );
    }
  });
  test('ghi có/ghi nợ khi không có dấu, không tự đoán nếu chỉ có số tiền', () {
    expect(
      parser.parse(notice('Ghi có 500,000 VND')).direction,
      BankMoneyDirection.income,
    );
    expect(
      parser.parse(notice('Ghi nợ 500.000 VND')).direction,
      BankMoneyDirection.expense,
    );
    expect(
      parser.parse(notice('500.000 VND')).status,
      BankNoticeStatus.unrecognized,
    );
  });
  test('bỏ OTP kể cả có số tiền và tiêu đề OTP', () {
    for (final s in [
      'OTP 123456 cho giao dich -500.000 VND',
      'Mã xác thực: 123456',
      'Verification code 123456',
    ]) {
      expect(parser.parse(notice(s)).status, BankNoticeStatus.ignored);
    }
    expect(
      parser.parse(notice('+1000 VND', title: 'OTP')).status,
      BankNoticeStatus.ignored,
    );
  });
  test('bỏ quảng cáo kể cả có số tiền kèm dấu và hoàn tiền', () {
    expect(
      parser.parse(notice('Ưu đãi voucher 500.000 VND')).status,
      BankNoticeStatus.ignored,
    );
    expect(
      parser.parse(notice('Hoàn tiền +50.000 VND')).status,
      BankNoticeStatus.ignored,
    );
  });
  test('từ chối số tiền sai, nhiều tiền và dấu/chiều mâu thuẫn', () {
    for (final s in [
      '+1,23,456 VND',
      'Ghi có 1 500 VND',
      '+1.23 VND',
      '+0 VND',
      '+50 USD',
      '-500 VND ghi có',
      '+500 VND -200 VND',
      'Số dư: 500 VND',
      '+500 VND phí 10 VND',
      '+9999999999999999 VND',
    ]) {
      expect(
        parser.parse(notice(s)).status,
        BankNoticeStatus.unrecognized,
        reason: s,
      );
    }
  });
  test('giao dịch lỗi/đang chờ không được coi đã xảy ra', () {
    for (final s in [
      'Giao dịch thất bại -500 VND',
      'Pending +500 VND',
      'Dự kiến +500 VND',
    ]) {
      expect(parser.parse(notice(s)).status, BankNoticeStatus.unrecognized);
    }
  });
  test('thiếu giờ/sai ngày không lấy giờ nhận làm giờ giao dịch', () {
    for (final s in [
      '+500 VND',
      '+500 VND 31/02/2026 12:00',
      '+500 VND 12/11/2026 25:00',
      '+500 VND 12/11/2026 15:00 GMT+07:00',
    ]) {
      expect(parser.parse(notice(s)).transactionAt, isNull);
    }
  });
  test('payload bị cắt hoặc nguồn ngoài danh mục không được tách', () {
    expect(
      parser.parse(notice('+500 VND', truncated: true)).status,
      BankNoticeStatus.unrecognized,
    );
    expect(
      parser.parse(notice('+500 VND', id: 'unknown')).status,
      BankNoticeStatus.unrecognized,
    );
  });
}
