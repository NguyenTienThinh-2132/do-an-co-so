import 'bank_catalog.dart';

/// Chỉ nhận diện ứng viên theo app label do Android PackageManager cung cấp.
/// Kết quả không xác minh package/chữ ký và không cho phép đọc payload.
/// Không dùng matcher này với notification title/text hoặc tên lấy từ extras.
class BankAppNameMatcher {
  BankAppNameMatcher({Iterable<BankCatalogEntry> catalog = vietnamBankCatalog})
    : _catalog = List.unmodifiable(catalog);

  final List<BankCatalogEntry> _catalog;

  /// Khớp toàn bộ tên/bí danh đã khai báo; không dùng contains hoặc đoán hậu tố.
  /// Tên rỗng, quá dài hoặc trùng giữa nhiều ID đều trả null.
  BankCatalogEntry? match(String appLabel) {
    if (appLabel.length > 200) return null;
    final key = _normalize(appLabel);
    if (key.isEmpty) return null;
    final matches = <String, BankCatalogEntry>{};
    for (final bank in _catalog) {
      if ([bank.name, ...bank.aliases].any((name) => _normalize(name) == key)) {
        matches[bank.id] = bank;
      }
    }
    return matches.length == 1 ? matches.values.single : null;
  }

  // Chỉ bỏ các dấu phân cách thông dụng. Giữ dấu tiếng Việt và ký tự khác:
  // không tự bỏ ký tự lạ/zero-width, không biến 'TPBank Fake' thành TPBank.
  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\u00a0._\-–—]+'), '');
}
