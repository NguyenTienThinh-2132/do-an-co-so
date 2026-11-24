import 'native_event.dart';
import 'bank_catalog.dart';

enum BankNoticeStatus { parsed, ignored, unrecognized }

enum BankMoneyDirection { income, expense }

/// Kết quả đọc tham khảo, không phải Transaction và không ghi module tài chính.
class BankNoticeResult {
  const BankNoticeResult({
    required this.status,
    required this.reason,
    this.amountVnd,
    this.direction,
    this.balanceVnd,
    this.transactionAt,
    this.description,
  });
  final BankNoticeStatus status;
  final String reason;
  final int? amountVnd;
  final BankMoneyDirection? direction;
  final int? balanceVnd;

  /// null nếu thông báo thiếu ngày/giờ hợp lệ; không thay bằng giờ nhận.
  final DateTime? transactionAt;
  final String? description;
}

/// Quy tắc VND tổng quát, chưa đại diện hỗ trợ mọi mẫu ngân hàng.
class BankNotificationParser {
  const BankNotificationParser();
  static final _otp = RegExp(
    r'\botp\b|\bone[ -]time\b|mã xác (?:thực|nhận)|ma xac (?:thuc|nhan)|verification code|authentication code',
    caseSensitive: false,
  );
  static final _ads = RegExp(
    r'ưu đãi|uu dai|khuyến mãi|khuyen mai|hoàn tiền|hoan tien|cashback|voucher|lãi suất|lai suat|mở thẻ|mo the',
    caseSensitive: false,
  );
  static final _money = RegExp(
    r'([+\-−]?\s*\d+(?:[.,]\d+)*)(?:\s*)(VND|VNĐ|đồng|đ|₫)(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
  static final _balance = RegExp(
    r'(?:số dư(?: khả dụng)?|so du(?: kha dung)?|balance(?: available)?|available balance|sd(?: kha dung)?)\s*[:=]?\s*([+\-−]?\s*\d+(?:[.,]\d+)*)\s*(?:VND|VNĐ|đồng|đ|₫)(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );

  BankNoticeResult parse(NativeEvent event) {
    if (event.kind != 'bankNotification' ||
        !vietnamBankCatalog.any((bank) => bank.id == event.data['bankId'])) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Chưa nhận diện nguồn ngân hàng.',
      );
    }
    final title = event.data['title'] as String? ?? '';
    final body = event.data['text'] as String? ?? '';
    if (event.data['truncated'] == true) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Thông báo bị cắt; cần đối chiếu bản đầy đủ.',
      );
    }
    final text = '$title\n$body';
    if (_otp.hasMatch(text)) {
      return const BankNoticeResult(
        status: BankNoticeStatus.ignored,
        reason: 'Bỏ qua thông báo xác thực/OTP.',
      );
    }
    final incoming = RegExp(
      r'ghi có|ghi co|báo có|bao co|\bcredit(?:ed)?\b|cộng tiền|cong tien|nhận tiền|nhan tien|tăng|tang',
      caseSensitive: false,
    ).hasMatch(text);
    final outgoing = RegExp(
      r'ghi nợ|ghi no|báo nợ|bao no|\bdebit(?:ed)?\b|trừ tiền|tru tien|giảm|giam|thanh toán thành công|thanh toan thanh cong|chuyển tiền thành công|chuyen tien thanh cong',
      caseSensitive: false,
    ).hasMatch(text);
    final balances = _balance.allMatches(text).toList();
    final amounts = _money
        .allMatches(text)
        .where(
          (m) => !balances.any((b) => m.start >= b.start && m.end <= b.end),
        )
        .toList();
    final signed = amounts
        .where((m) => RegExp(r'^[+\-−]').hasMatch(m[1]!.trim()))
        .toList();
    if (_ads.hasMatch(text)) {
      return const BankNoticeResult(
        status: BankNoticeStatus.ignored,
        reason: 'Bỏ qua nội dung ưu đãi/quảng cáo.',
      );
    }
    // Không suy đoán giao dịch lỗi/đang chờ là biến động đã xảy ra.
    if (RegExp(
      r'thất bại|that bai|không thành công|khong thanh cong|failed|pending|đang xử lý|dang xu ly|dự kiến|du kien',
      caseSensitive: false,
    ).hasMatch(text)) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Thông báo chưa xác nhận giao dịch đã xảy ra.',
      );
    }
    final candidates = signed.isNotEmpty ? signed : amounts;
    if (amounts.length != 1 ||
        candidates.length != 1 ||
        (incoming && outgoing)) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Thiếu hoặc có nhiều số tiền/chiều giao dịch; cần đối chiếu.',
      );
    }
    final token = candidates.single[1]!.trim();
    if (!RegExp(r'^[+\-−]').hasMatch(token) &&
        RegExp(r'\d[ \u00a0]*$')
            .hasMatch(text.substring(0, candidates.single.start))) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Chưa hỗ trợ số tiền phân nhóm bằng khoảng trắng.',
      );
    }
    final sign = token.startsWith('+')
        ? BankMoneyDirection.income
        : token.startsWith('-') || token.startsWith('−')
        ? BankMoneyDirection.expense
        : null;
    final words = incoming
        ? BankMoneyDirection.income
        : outgoing
        ? BankMoneyDirection.expense
        : null;
    if ((sign != null && words != null && sign != words) ||
        (sign == null && words == null)) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Chưa xác định chắc chắn thu/chi.',
      );
    }
    final amount = _vnd(token);
    if (amount == null || amount <= 0) {
      return const BankNoticeResult(
        status: BankNoticeStatus.unrecognized,
        reason: 'Định dạng số tiền VND chưa hỗ trợ.',
      );
    }
    int? balance;
    if (balances.length == 1) {
      final raw = balances.single[1]!.trim();
      final value = _vnd(raw);
      balance = value == null
          ? null
          : (raw.startsWith('-') || raw.startsWith('−') ? -value : value);
    }
    final content = RegExp(
      r'(?:nội dung|noi dung|nd|description|content|remark)\s*[:=]\s*([\s\S]*?)(?=\n\s*(?:SO\s+GD|mã giao dịch|ma giao dich|ref|SD(?: KHA DUNG)?|số dư|balance)\s*:|$)',
      caseSensitive: false,
    ).firstMatch(body)?[1];
    return BankNoticeResult(
      status: BankNoticeStatus.parsed,
      reason: 'Kết quả quy tắc tổng quát — cần đối chiếu.',
      amountVnd: amount,
      direction: sign ?? words,
      balanceVnd: balance,
      transactionAt: _date(text),
      description: content == null ? null : maskBankText(content.trim()),
    );
  }

  static int? _vnd(String token) {
    var value = token.replaceAll(RegExp(r'[+\-−\s]'), '');
    // Chỉ nhận số nguyên hoặc phần lẻ .00/,00, không làm tròn tiền.
    if (value.contains('.') && value.contains(',')) {
      final decimal = value.lastIndexOf('.') > value.lastIndexOf(',')
          ? '.'
          : ',';
      final grouping = decimal == '.' ? ',' : '.';
      final parts = value.split(decimal);
      if (parts.length != 2 ||
          parts[1] != '00' ||
          !RegExp('^\\d{1,3}(?:\\$grouping\\d{3})+\$').hasMatch(parts[0])) {
        return null;
      }
      value = parts[0].replaceAll(grouping, '');
    } else if (value.contains('.') || value.contains(',')) {
      final sep = value.contains('.') ? '.' : ',';
      final parts = value.split(sep);
      if (parts.length == 2 && parts[1] == '00') {
        value = parts[0];
      } else {
        if (parts[0].length > 3 || parts.skip(1).any((p) => p.length != 3)) {
          return null;
        }
        value = parts.join();
      }
    }
    if (!RegExp(r'^\d{1,15}$').hasMatch(value)) return null;
    return int.tryParse(value);
  }

  static DateTime? _date(String text) {
    final m = RegExp(
      r'\b(\d{2})/(\d{2})/(\d{4})[ T]+(\d{2}):(\d{2})(?::(\d{2}))?\b',
    ).firstMatch(text);
    if (m == null) return null;
    final v = [for (var i = 1; i <= 6; i++) int.parse(m[i] ?? '0')];
    if (v[2] < 1900 || v[2] > 2200) return null;
    final wall = DateTime.utc(v[2], v[1], v[0], v[3], v[4], v[5]);
    if (wall.year != v[2] ||
        wall.month != v[1] ||
        wall.day != v[0] ||
        wall.hour != v[3] ||
        wall.minute != v[4] ||
        wall.second != v[5]) {
      return null;
    }
    // Bản thử chỉ hỗ trợ mẫu giờ Việt Nam không kèm offset khác.
    if (RegExp(
      r'\b(?:UTC|GMT)|[+]\d{2}:\d{2}',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    return wall.subtract(const Duration(hours: 7));
  }
}

/// Che số dài và email trong mô tả; không bảo đảm che hết tên/thông tin cá nhân.
/// Bằng chứng phải được rà soát/che thủ công trước khi chia sẻ.
String maskBankText(String text) => text
    .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
    .replaceAll(RegExp(r'\d{5,}'), '****')
    .replaceAll(
      RegExp(
        r'(?:TK|STK|tài khoản|tai khoan)\s*[:=]?\s*[A-Za-z0-9*]+',
        caseSensitive: false,
      ),
      'TK ****',
    );
