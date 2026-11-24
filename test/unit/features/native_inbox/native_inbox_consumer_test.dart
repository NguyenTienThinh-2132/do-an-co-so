import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/core/types/app_failure.dart';
import 'package:finai/features/native_inbox/application/native_inbox_consumer.dart';
import 'package:finai/features/native_inbox/domain/native_event.dart';
import 'package:finai/features/native_inbox/domain/native_inbox_port.dart';

class MemoryInbox implements NativeInboxPort {
  final events = StreamController<NativeEvent>.broadcast();
  final pending = <NativeEvent>[];
  final acked = <String>[];
  bool failAck = false;
  @override
  Future<Result<List<NativeEvent>>> getPending() async =>
      Success(List.of(pending));
  @override
  Future<Result<void>> acknowledge(List<String> ids) async {
    if (failAck) {
      return const Failure(
        AppFailure(code: AppFailureCode.unavailable, message: 'offline'),
      );
    }
    acked.addAll(ids);
    pending.removeWhere((e) => ids.contains(e.id));
    return const Success(null);
  }

  @override
  Stream<NativeEvent> watchIncoming() => events.stream;
  @override
  Future<Result<bool>> isAccessGranted() async => const Success(true);
  @override
  Future<Result<void>> openAccessSettings() async => const Success(null);
  @override
  Future<Result<void>> setAllowedPackages(List<String> packages) async =>
      const Success(null);
}

NativeEvent event(String id, String kind) => NativeEvent(
  id: id,
  kind: kind,
  receivedAt: DateTime.utc(2026),
  data: const {},
);
void main() {
  test('recover chỉ ack sự kiện handler đã nhận xử lý', () async {
    final port = MemoryInbox()
      ..pending.addAll([
        event('tap', 'taskOpen'),
        event('notice', 'notification'),
      ]);
    final consumer = NativeInboxConsumer(
      port: port,
      handle: (e) async => e.kind == 'taskOpen',
    );
    await consumer.recover();
    expect(port.acked, ['tap']);
    expect(port.pending.map((e) => e.id), ['notice']);
    consumer.dispose();
    await port.events.close();
  });
  test(
    'ack lỗi giữ sự kiện, thử lại không mở task lần hai trong cùng phiên',
    () async {
      final port = MemoryInbox()
        ..pending.add(event('tap', 'taskOpen'))
        ..failAck = true;
      var opened = 0;
      final consumer = NativeInboxConsumer(
        port: port,
        handle: (e) async {
          opened++;
          return true;
        },
      );
      await consumer.recover();
      expect(consumer.failure, isNotNull);
      expect(port.pending, hasLength(1));
      port.failAck = false;
      await consumer.recover();
      expect(opened, 1);
      expect(port.pending, isEmpty);
      expect(consumer.failure, isNull);
      consumer.dispose();
      await port.events.close();
    },
  );
  test('handler lỗi không ack và lần phục hồi sau được xử lý lại', () async {
    final port = MemoryInbox()..pending.add(event('tap', 'taskOpen'));
    var ready = false;
    final consumer = NativeInboxConsumer(
      port: port,
      handle: (e) async {
        if (!ready) throw StateError('not ready');
        return true;
      },
    );
    await consumer.recover();
    expect(port.acked, isEmpty);
    ready = true;
    await consumer.recover();
    expect(port.acked, ['tap']);
    consumer.dispose();
    await port.events.close();
  });
  test('dispose không tiếp tục xử lý pending', () async {
    final port = MemoryInbox()..pending.add(event('tap', 'taskOpen'));
    final consumer = NativeInboxConsumer(port: port, handle: (e) async => true)
      ..dispose();
    await consumer.recover();
    expect(port.acked, isEmpty);
    await port.events.close();
  });
  test('sự kiện đến trước khi Flutter start được đọc lại từ pending', () async {
    final port = MemoryInbox();
    final incoming = event('before-start', 'taskOpen');
    port.pending.add(incoming);
    port.events.add(incoming); // Chưa có subscriber: chỉ pending giữ sự kiện.
    await Future<void>.delayed(Duration.zero);
    var handled = 0;
    final consumer = NativeInboxConsumer(
      port: port,
      handle: (e) async {
        handled++;
        return true;
      },
    );
    consumer.start();
    await Future<void>.delayed(Duration.zero);
    expect(handled, 1);
    expect(port.pending, isEmpty);
    expect(port.acked, ['before-start']);
    consumer.dispose();
    await port.events.close();
  });

  test(
    'pending và live trùng ID chỉ xử lý một lần, ack sau khi handler xong',
    () async {
      final port = MemoryInbox();
      final incoming = event('both-channels', 'taskOpen');
      port.pending.add(incoming);
      final started = Completer<void>();
      final done = Completer<bool>();
      var handled = 0;
      final consumer = NativeInboxConsumer(
        port: port,
        handle: (e) async {
          handled++;
          if (!started.isCompleted) started.complete();
          return done.future;
        },
      );
      consumer.start();
      port.events.add(incoming);
      await started.future;
      expect(port.acked, isEmpty);
      expect(port.pending, hasLength(1));
      done.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(handled, 1);
      expect(port.pending, isEmpty);
      expect(port.acked.toSet(), {'both-channels'});
      consumer.dispose();
      await port.events.close();
    },
  );

  test(
    'Flutter đóng khi đang xử lý giữ pending cho consumer lần mở sau',
    () async {
      final port = MemoryInbox()
        ..pending.add(event('close-mid-handler', 'taskOpen'));
      final started = Completer<void>();
      final done = Completer<bool>();
      final first = NativeInboxConsumer(
        port: port,
        handle: (e) async {
          started.complete();
          return done.future;
        },
      );
      final recovery = first.recover();
      await started.future;
      first.dispose();
      done.complete(true);
      await recovery;
      expect(port.acked, isEmpty);
      expect(port.pending, hasLength(1));
      final second = NativeInboxConsumer(port: port, handle: (e) async => true);
      await second.recover();
      expect(port.pending, isEmpty);
      expect(port.acked, ['close-mid-handler']);
      second.dispose();
      await port.events.close();
    },
  );
}
