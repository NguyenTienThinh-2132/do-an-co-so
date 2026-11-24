import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/types/result.dart';
import '../../tasks/domain/ports/task_reminder_port.dart';
import '../domain/native_event.dart';
import 'bank_notice_card.dart';
import '../domain/native_inbox_port.dart';

/// Màn thử kỹ thuật, mặc định ẩn nội dung thông báo để tránh lộ dữ liệu.
class NativeInboxPage extends StatefulWidget {
  const NativeInboxPage({
    super.key,
    required this.port,
    required this.permissions,
  });
  final NativeInboxPort? port;
  final TaskReminderPort? permissions;
  @override
  State<NativeInboxPage> createState() => _NativeInboxPageState();
}

class _NativeInboxPageState extends State<NativeInboxPage>
    with WidgetsBindingObserver {
  StreamSubscription<NativeEvent>? _subscription;
  List<NativeEvent> _events = [];
  bool _loading = false;
  bool _dirty = false;
  bool _access = false;
  bool _notify = false;
  bool _exact = false;
  bool _show = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.port != null) {
      _subscription = widget.port!.watchIncoming().listen(
        (_) => _refresh(),
        onError: (Object _) {
          if (mounted) {
            setState(() => _error = 'Chưa nhận được sự kiện trực tiếp.');
          }
        },
      );
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (widget.port == null || !mounted) return;
    if (_loading) {
      _dirty = true;
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      do {
        _dirty = false;
        final access = await widget.port!.isAccessGranted();
        final events = await widget.port!.getPending();
        final notify = await widget.permissions?.canNotify();
        final exact = await widget.permissions?.canScheduleExact();
        if (!mounted) return;
        setState(() {
          _access = access is Success<bool> && access.value;
          _notify = notify is Success<bool> && notify.value;
          _exact = exact is Success<bool> && exact.value;
          if (events case Success<List<NativeEvent>>(:final value)) {
            _events = value;
          } else {
            _error = 'Không đọc được Native Inbox. Hãy thử lại.';
          }
        });
      } while (_dirty && mounted);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa kết nối được Native.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ack(List<String> ids) async {
    if (widget.port == null || _loading) return;
    setState(() => _loading = true);
    try {
      final result = await widget.port!.acknowledge(ids);
      if (!mounted) return;
      setState(() => _loading = false);
      if (result is Failure<void>) {
        setState(() => _error = 'Chưa xác nhận được. Sự kiện vẫn được giữ.');
        return;
      }
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Chưa xác nhận được. Sự kiện vẫn được giữ.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F7FB),
    appBar: AppBar(title: const Text('Native Inbox • thử nghiệm')),
    body: widget.port == null
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Màn này cần Android. Web chỉ xem giao diện Tasks và chat mô phỏng.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextButton.icon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Đọc lại Inbox'),
              ),
              SwitchListTile(
                value: _show,
                onChanged: (value) => setState(() => _show = value),
                title: const Text('Hiện nội dung trên thiết bị này'),
                subtitle: const Text('Mặc định ẩn nội dung nhạy cảm.'),
              ),
              Text(
                'Sự kiện chưa xác nhận: COUNT (tối đa 200 mỗi lượt)'
                    .replaceFirst('COUNT', _events.length.toString()),
              ),
              if (_events.isEmpty && !_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có sự kiện.', textAlign: TextAlign.center),
                ),
              for (final event in _events)
                if (event.kind == 'bankNotification')
                  BankNoticeCard(
                    event: event,
                    showContent: _show,
                    onAcknowledge: _loading ? null : () => _ack([event.id]),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.kind,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(event.data['packageName'] as String? ?? 'FinAI'),
                          Text(event.receivedAt.toLocal().toString()),
                          Text(
                            _show
                                ? (event.data['title'] as String? ?? '')
                                : 'Nội dung đã ẩn',
                          ),
                          if (_show) Text(event.data['text'] as String? ?? ''),
                          TextButton(
                            onPressed: _loading ? null : () => _ack([event.id]),
                            child: const Text('Xác nhận đã nhận'),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_events.isNotEmpty)
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () => _ack(_events.map((e) => e.id).toList()),
                  child: const Text('Xác nhận các mục đang hiển thị'),
                ),
              const SizedBox(height: 20),
              Card(
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  title: const Text('Quyền truy cập'),
                  subtitle: Text(
                    _access && _notify && _exact
                        ? 'Đã cấp đủ quyền'
                        : 'Một số quyền chưa được cấp',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _access
                          ? 'Đã cấp quyền đọc thông báo'
                          : 'Chưa cấp quyền đọc thông báo',
                    ),
                    Text(
                      _notify
                          ? 'Được phép hiện thông báo'
                          : 'Chưa được hiện thông báo',
                    ),
                    Text(
                      _exact
                          ? 'Được đặt nhắc chính xác'
                          : 'Chưa có quyền nhắc chính xác',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhận thông báo FinAI và app có tên khớp danh mục ngân hàng. Tên app chưa xác minh nguồn chính chủ. Bỏ OTP/quảng cáo theo quy tắc; không tự tạo giao dịch.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await widget.port!.openAccessSettings();
                          },
                          child: const Text('Cấp quyền đọc thông báo'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await widget.permissions?.requestNotifications();
                            await _refresh();
                          },
                          child: const Text('Quyền thông báo'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await widget.permissions?.openExactAlarmSettings();
                          },
                          child: const Text('Quyền nhắc chính xác'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
