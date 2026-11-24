import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/native_inbox/domain/bank_catalog.dart';
import 'package:finai/features/native_inbox/domain/bank_app_name_matcher.dart';

void main() {
  final matcher = BankAppNameMatcher();
  test('tên và bí danh của toàn bộ danh mục trả đúng ID', () {
    for (final bank in vietnamBankCatalog) {
      for (final name in [bank.name, ...bank.aliases]) {
        expect(matcher.match(name)?.id, bank.id, reason: name);
      }
    }
    expect(
      vietnamBankCatalog.map((e) => e.id).toSet().length,
      vietnamBankCatalog.length,
    );
  });
  test('không phân biệt hoa thường, khoảng trắng, dấu phân cách', () {
    expect(matcher.match('  tp BANK  ')?.id, 'tpb');
    expect(matcher.match('TECHCOMBANK - MOBILE')?.id, 'tcb');
    expect(matcher.match('MB.Bank')?.id, 'mb');
    expect(matcher.match('CAKE by VPBank')?.id, 'cake');
  });
  test('ngân hàng số và tên cũ vẫn là đúng mục riêng', () {
    expect(matcher.match('Timo by BVBank')?.id, 'timo');
    expect(matcher.match('TNEX by MSB')?.id, 'tnex');
    expect(matcher.match('NeoOne')?.id, 'cbb');
    expect(matcher.match('OceanBank')?.id, 'mbv');
    expect(matcher.match('DongA Bank')?.id, 'vikki');
  });
  test('không nhận app khác chỉ vì chứa tên ngân hàng', () {
    for (final label in [
      'TPBank Fake',
      'Techcombank OTP Reader',
      'My TPBank',
      'Tin nhắn từ BIDV',
      'MoMo',
      'ZaloPay',
      'FinAI',
      '',
      '   ',
      'TPBank/Other',
      'TPBank\u200b',
      'TPBаnk',
    ]) {
      expect(matcher.match(label), isNull, reason: label);
    }
    expect(matcher.match(List.filled(201, 'a').join()), isNull);
  });
  test('bí danh trùng giữa nhiều ngân hàng bị từ chối', () {
    final ambiguous = BankAppNameMatcher(
      catalog: const [
        BankCatalogEntry(id: 'a', name: 'A', aliases: ['Shared Bank']),
        BankCatalogEntry(id: 'b', name: 'B', aliases: ['Shared-Bank']),
      ],
    );
    expect(ambiguous.match('Shared Bank'), isNull);
  });
  test('bí danh trùng trong cùng ID không tạo kết quả mơ hồ', () {
    final same = BankAppNameMatcher(
      catalog: const [
        BankCatalogEntry(id: 'a', name: 'A Bank', aliases: ['A-Bank']),
      ],
    );
    expect(same.match('A Bank')?.id, 'a');
  });
}
