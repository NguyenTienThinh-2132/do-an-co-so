import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finai/features/native_inbox/presentation/native_inbox_page.dart';

import '../../../unit/features/native_inbox/native_inbox_consumer_test.dart'
    as fixtures;

void main() {
  testWidgets('Web không báo đã cấp quyền hoặc nhận sự kiện Native', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NativeInboxPage(port: null, permissions: null)),
    );
    expect(find.textContaining('Màn này cần Android'), findsOneWidget);
    expect(find.text('Cấp quyền đọc thông báo'), findsNothing);
  });
  testWidgets(
    'ẩn payload mặc định; ack lỗi giữ mục và hiển thị lỗi; retry xóa mục',
    (tester) async {
      final port = fixtures.MemoryInbox()
        ..pending.add(fixtures.event('n1', 'notification'))
        ..failAck = true;
      await tester.pumpWidget(
        MaterialApp(home: NativeInboxPage(port: port, permissions: null)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nội dung đã ẩn'), findsOneWidget);
      final ack = find.text('Xác nhận đã nhận');
      await tester.ensureVisible(ack);
      await tester.tap(ack);
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa xác nhận được. Sự kiện vẫn được giữ.'),
        findsOneWidget,
      );
      expect(port.pending, hasLength(1));
      port.failAck = false;
      await tester.ensureVisible(ack);
      await tester.tap(ack);
      await tester.pumpAndSettle();
      expect(port.pending, isEmpty);
      expect(find.text('Chưa có sự kiện.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await port.events.close();
    },
  );
}
