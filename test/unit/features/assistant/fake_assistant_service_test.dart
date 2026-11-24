import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/assistant/data/fake_assistant_service.dart';
import 'package:finai/features/assistant/domain/assistant_models.dart';
import 'package:finai/features/tasks/domain/ports/task_reader.dart';
import 'package:finai/features/tasks/domain/ports/task_dto.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';

class Reader implements TaskReader {
  Reader(this.rows);
  final List<TaskDto> rows;
  TaskQuery? received;
  @override
  Future<Result<List<TaskDto>>> getTasks(TaskQuery query) async {
    received = query;
    return Success(rows);
  }
}

class DeferredReader implements TaskReader {
  final started = Completer<void>();
  final result = Completer<Result<List<TaskDto>>>();
  @override
  Future<Result<List<TaskDto>>> getTasks(TaskQuery query) {
    started.complete();
    return result.future;
  }
}

TaskDto row(
  String id,
  String title, {
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.pending,
}) => TaskDto.fromTask(
  Task(
    id: id,
    title: title,
    startAt: DateTime(2026, 11, 13, 19),
    endAt: DateTime(2026, 11, 13, 20),
    priority: priority,
    status: status,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
);
void main() {
  final query = TaskQuery(
    start: DateTime(2026, 11, 13),
    end: DateTime(2026, 11, 14),
  );
  Future<String> answer(Reader reader, String text) async {
    final events = await FakeAssistantService(
      tasks: reader,
      delay: Duration.zero,
    ).reply(AssistantRequest(text: text, query: query)).toList();
    expect(reader.received, same(query));
    expect(events.last, isA<AssistantDone>());
    return events.whereType<AssistantText>().single.text;
  }

  test('hủy trong lúc reader đang chạy không phát phản hồi đến muộn', () async {
    final reader = DeferredReader();
    final events = <AssistantEvent>[];
    final subscription = FakeAssistantService(
      tasks: reader,
      delay: Duration.zero,
    ).reply(AssistantRequest(text: 'Tiến độ', query: query)).listen(events.add);
    await reader.started.future;
    await subscription.cancel();
    reader.result.complete(const Success([]));
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });
  test('nút khoảng này dùng dữ liệu reader, thời gian và trạng thái, gợi ý việc chưa hoàn thành', () async {
    final text = await answer(
      Reader([
        row(
          '1',
          'Việc đã xong',
          priority: TaskPriority.high,
          status: TaskStatus.completed,
        ),
        row('2', 'Báo cáo FinAI', priority: TaskPriority.high),
      ]),
      'Việc trong khoảng này',
    );
    expect(text, contains('2 công việc'));
    expect(text, contains('13/11/2026'));
    expect(text, contains('19:00'));
    expect(text, contains('20:00'));
    expect(text, contains('Đã hoàn thành'));
    expect(text, contains('tập trung vào “Báo cáo FinAI”'));
  });
  test('nút ưu tiên cao chỉ hiển thị công việc cao', () async {
    final text = await answer(
      Reader([
        row('1', 'Việc thấp', priority: TaskPriority.low),
        row('2', 'Việc cao', priority: TaskPriority.high),
      ]),
      'Việc ưu tiên cao',
    );
    expect(text, contains('1 công việc ưu tiên cao'));
    expect(text, contains('Việc cao'));
    expect(text, isNot(contains('Việc thấp')));
  });
  test(
    'không có ưu tiên cao có câu trả lời riêng, không tạo việc giả',
    () async {
      final text = await answer(
        Reader([row('1', 'Việc thường')]),
        'Việc ưu tiên cao',
      );
      expect(text, contains('không có công việc ưu tiên cao'));
    },
  );
  test('tiến độ tính từ dữ liệu thật của reader', () async {
    final text = await answer(
      Reader([
        row('1', 'A', status: TaskStatus.completed),
        row('2', 'B', status: TaskStatus.inProgress),
        row('3', 'C'),
      ]),
      'Tiến độ',
    );
    expect(text, contains('1/3 công việc (33.3%)'));
    expect(text, contains('Đang làm: 1'));
    expect(text, contains('Chờ xử lý: 1'));
  });
  test('danh sách rỗng có hướng dẫn, tiến độ 0 không chia cho 0', () async {
    expect(
      await answer(Reader([]), 'Việc trong khoảng này'),
      contains('chưa có công việc nào'),
    );
    final progress = await answer(Reader([]), 'Tiến độ');
    expect(progress, contains('0/0 công việc (0%)'));
    expect(progress, isNot(contains('NaN')));
  });
  test('hoàn thành hết không gợi ý làm lại việc đã xong', () async {
    final text = await answer(
      Reader([
        row(
          '1',
          'Xong',
          priority: TaskPriority.high,
          status: TaskStatus.completed,
        ),
      ]),
      'Việc ưu tiên cao',
    );
    expect(text, contains('đều đã hoàn thành'));
    expect(text, isNot(contains('tập trung vào')));
  });
}
