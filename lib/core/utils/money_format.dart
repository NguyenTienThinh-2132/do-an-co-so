String formatVnd(int amount, {bool signed = false}) {
  final digits = amount.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final prefix = amount < 0 ? '−' : (signed && amount > 0 ? '+' : '');
  return '$prefix$digits ₫';
}
