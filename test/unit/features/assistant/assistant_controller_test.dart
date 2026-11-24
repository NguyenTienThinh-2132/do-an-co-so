import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/core/types/app_failure.dart';
import 'package:finai/features/assistant/application/assistant_controller.dart';
import 'package:finai/features/assistant/domain/assistant_models.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';

class ControlledService implements AssistantService {
  final requests = <AssistantRequest>[];
  final streams = <StreamController<AssistantEvent>>[];
  @override
  Stream<AssistantEvent> reply(AssistantRequest request) {
    requests.add(request);
    final c = StreamController<AssistantEvent>.broadcast();
    streams.add(c);
    return c.stream;
  }

  Future<void> close() async {
    for (final s in streams) {
      await s.close();
    }
  }
}

const failure = AppFailure(
  code: AppFailureCode.unavailable,
  message: 'Mẫu lỗi',
);
void main() {
  final query = TaskQuery(
    start: DateTime.utc(2026, 11, 13),
    end: DateTime.utc(2026, 11, 14),
  );
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test('chặn rỗng/gửi đồng thời và trim đúng', () async {
    final service = ControlledService();
    final c = AssistantController(service: service, query: query);
    expect(c.send('  '), isFalse);
    expect(service.requests, isEmpty);
    expect(c.send('  Tiến độ  '), isTrue);
    expect(c.send('Gửi lần hai'), isFalse);
    expect(c.messages.single.text, 'Tiến độ');
    expect(service.requests, hasLength(1));
    c.dispose();
    await service.close();
  });
  test('hủy rồi gửi mới không nhận phản hồi muộn của lượt cũ', () async {
    final service = ControlledService();
    final c = AssistantController(service: service, query: query);
    c.send('Cũ');
    c.cancel();
    expect(c.replying, isFalse);
    c.send('Mới');
    service.streams[0].add(const AssistantText('Không được hiện'));
    service.streams[0].add(const AssistantDone());
    service.streams[1].add(const AssistantText('Trả lời mới'));
    service.streams[1].add(const AssistantDone());
    await flush();
    expect(
      c.messages.where((m) => m.role == ChatRole.assistant).single.text,
      'Trả lời mới',
    );
    expect(c.failure, isNull);
    c.dispose();
    await service.close();
  });
  test('lỗi rồi retry không nhân đôi tin nhắn người dùng', () async {
    final service = ControlledService();
    final c = AssistantController(service: service, query: query);
    c.send('Tiến độ', scenario: AssistantScenario.error);
    service.streams[0].add(const AssistantError(failure));
    await flush();
    expect(c.failure, same(failure));
    expect(c.replying, isFalse);
    c.retry();
    expect(service.requests.last.scenario, AssistantScenario.success);
    expect(service.requests.last.query, same(query));
    expect(c.messages, hasLength(1));
    service.streams[1].add(const AssistantText('Thành công'));
    service.streams[1].add(const AssistantDone());
    await flush();
    expect(c.messages, hasLength(2));
    expect(c.failure, isNull);
    c.dispose();
    await service.close();
  });
  test(
    'Done lặp và lỗi sau Done không được tạo phản hồi hoặc lỗi thứ hai',
    () async {
      final service = ControlledService();
      final c = AssistantController(service: service, query: query);
      c.send('Tiến độ');
      service.streams[0].add(const AssistantText('Đã xong'));
      service.streams[0].add(const AssistantDone());
      service.streams[0].add(const AssistantDone());
      service.streams[0].add(const AssistantError(failure));
      service.streams[0].add(const AssistantDone());
      await flush();
      expect(
        c.messages.where((m) => m.role == ChatRole.assistant),
        hasLength(1),
      );
      expect(c.failure, isNull);
      c.dispose();
      await service.close();
    },
  );
  test('stream đóng sớm báo lỗi để thử lại, không lưu trả lời dở', () async {
    final service = ControlledService();
    final c = AssistantController(service: service, query: query);
    c.send('Tiến độ');
    service.streams[0].add(const AssistantText('Dở dang'));
    await service.streams[0].close();
    await flush();
    expect(c.failure, isNotNull);
    expect(c.replying, isFalse);
    expect(c.messages, hasLength(1));
    c.dispose();
    await service.close();
  });
  test('dispose không nhận sự kiện đến sau hoặc cho gửi thêm', () async {
    final service = ControlledService();
    final c = AssistantController(service: service, query: query);
    c.send('Tiến độ');
    c.dispose();
    service.streams[0].add(const AssistantText('Muộn'));
    service.streams[0].add(const AssistantDone());
    await flush();
    expect(c.messages, hasLength(1));
    expect(c.send('Mới'), isFalse);
    await service.close();
  });
}
