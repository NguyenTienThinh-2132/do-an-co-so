import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../domain/native_event.dart';
import '../domain/native_inbox_port.dart';

/// Chỉ ack khi handler đã nhận xử lý; trả false giữ sự kiện cho consumer khác.
/// Delivery at-least-once: eventId khử lặp trong phiên, Native giữ tombstone.
class NativeInboxConsumer extends ChangeNotifier {
  NativeInboxConsumer({required this.port, required this.handle});
  final NativeInboxPort port;
  final Future<bool> Function(NativeEvent) handle;
  final Set<String> _handled = {};
  StreamSubscription<NativeEvent>? _subscription;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  bool _recovering = false;
  AppFailure? _failure;
  AppFailure? get failure => _failure;

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = port.watchIncoming().listen((event) {
      unawaited(_enqueue(event));
    }, onError: (Object _) => _fail());
    unawaited(recover());
  }

  void _fail() {
    if (_disposed) return;
    _failure = const AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Chưa xử lý được Native Inbox. Sự kiện vẫn được giữ để thử lại.',
    );
    notifyListeners();
  }

  Future<void> _enqueue(NativeEvent event) {
    _tail = _tail.then((_) async {
      if (_disposed) return;
      try {
        if (!_handled.contains(event.id)) {
          if (!await handle(event)) return;
          if (_disposed) return;
          _handled.add(event.id);
        }
        final ack = await port.acknowledge([event.id]);
        if (ack is Failure<void>) {
          _fail();
          return;
        }
        if (!_disposed) {
          _failure = null;
          notifyListeners();
        }
      } catch (_) {
        _fail();
      }
    });
    return _tail;
  }

  Future<void> recover() async {
    if (_disposed || _recovering) return;
    _recovering = true;
    try {
      final result = await port.getPending();
      if (_disposed) return;
      switch (result) {
        case Success<List<NativeEvent>>(:final value):
          for (final event in value) {
            await _enqueue(event);
          }
        case Failure<List<NativeEvent>>():
          _fail();
      }
    } catch (_) {
      _fail();
    } finally {
      _recovering = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
