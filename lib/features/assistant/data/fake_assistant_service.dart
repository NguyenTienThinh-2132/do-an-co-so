import 'dart:async';

import '../../../core/types/app_failure.dart';
import '../../../core/types/result.dart';
import '../../tasks/domain/ports/task_reader.dart';
import '../../tasks/domain/ports/task_dto.dart';
import '../../tasks/domain/entities/task_priority.dart';
import '../../tasks/domain/entities/task_status.dart';
import '../domain/assistant_models.dart';

/// Mẫu chỉ đọc qua public port, không gọi LLM, không ghi dữ liệu.
class FakeAssistantService implements AssistantService {
  FakeAssistantService({
    required this.tasks,
    this.delay = const Duration(milliseconds: 350),
    this.slowDelay = const Duration(seconds: 3),
  });
  final TaskReader tasks;
  final Duration delay;
  final Duration slowDelay;

  @override
  Stream<AssistantEvent> reply(AssistantRequest request) =>
      Stream.multi((sink) {
        var active = true;
        final timer = Timer(
          request.scenario == AssistantScenario.slow ? slowDelay : delay,
          () async {
            if (!active) return;
            if (request.scenario == AssistantScenario.error) {
              sink.add(
                const AssistantError(
                  AppFailure(
                    code: AppFailureCode.unavailable,
                    message: 'Kịch bản lỗi mô phỏng. Bạn có thể thử lại.',
                  ),
                ),
              );
              sink.close();
              return;
            }
            try {
              final result = await tasks.getTasks(request.query);
              if (!active) return;
              switch (result) {
                case Failure<List<TaskDto>>(:final failure):
                  sink.add(AssistantError(failure));
                case Success<List<TaskDto>>(:final value):
                  sink.add(AssistantText(_answer(request, value)));
                  sink.add(const AssistantDone());
              }
            } catch (_) {
              if (active) {
                sink.add(
                  const AssistantError(
                    AppFailure(
                      code: AppFailureCode.unavailable,
                      message: 'Chưa đọc được công việc.',
                    ),
                  ),
                );
              }
            }
            if (active) sink.close();
          },
        );
        sink.onCancel = () {
          active = false;
          timer.cancel();
        };
      });

  String _answer(AssistantRequest request, List<TaskDto> tasks) {
    final question = request.text.toLowerCase();
    if ([
      'chi tiêu',
      'số dư',
      'thanh toán',
      'đầu tư',
      'hóa đơn',
    ].any(question.contains)) {
      return 'Mình đang ở chế độ mô phỏng và hiện có thể giúp bạn xem công việc. Dữ liệu tài chính chưa được kết nối.';
    }
    final start = request.query.start.toLocal();
    final end = request.query.end.toLocal();
    final lastDay = end.subtract(const Duration(microseconds: 1));
    final range = _date(start) == _date(lastDay)
        ? 'ngày ${_date(start)}'
        : 'khoảng ${_date(start)} đến ${_date(lastDay)}';
    final done = tasks.where((t) => t.status == TaskStatus.completed).length;
    final doing = tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final pending = tasks.where((t) => t.status == TaskStatus.pending).length;
    if (question.contains('tiến độ') || question.contains('hoàn thành')) {
      if (tasks.isEmpty) {
        return 'Bạn chưa có công việc nào trong $range.\nTiến độ hiện tại: 0/0 công việc (0%).\nBạn có thể thêm công việc ở màn Công việc để bắt đầu theo dõi.';
      }
      final percent = (done / tasks.length * 100).toStringAsFixed(1);
      return 'Tiến độ của bạn trong $range:\n'
          '• Hoàn thành: $done/${tasks.length} công việc ($percent%).\n'
          '• Đang làm: $doing công việc.\n'
          '• Chờ xử lý: $pending công việc.\n\n'
          '${done == tasks.length ? 'Bạn đã hoàn thành toàn bộ công việc trong khoảng này.' : 'Bạn còn ${tasks.length - done} công việc chưa hoàn thành.'}';
    }
    final highOnly = question.contains('ưu tiên');
    final selected = highOnly
        ? tasks.where((t) => t.priority == TaskPriority.high).toList()
        : tasks;
    if (selected.isEmpty) {
      return highOnly
          ? 'Bạn không có công việc ưu tiên cao trong $range. Bạn có thể xem “Việc trong khoảng này” để kiểm tra các công việc còn lại.'
          : 'Bạn chưa có công việc nào trong $range. Bạn có thể chọn ngày khác hoặc thêm công việc ở màn Công việc.';
    }
    final lines = selected
        .map(
          (t) =>
              '• ${t.title}\n'
              '  Thời gian: ${_date(t.startAt.toLocal())} ${_time(t.startAt.toLocal())} – ${_date(t.endAt.toLocal())} ${_time(t.endAt.toLocal())}\n'
              '  Ưu tiên: ${_priority(t.priority)} · ${_status(t.status)}',
        )
        .join('\n\n');
    final remaining =
        selected.where((t) => t.status != TaskStatus.completed).toList()
          ..sort((a, b) {
            final priority = b.priority.index.compareTo(a.priority.index);
            if (priority != 0) return priority;
            final time = a.startAt.compareTo(b.startAt);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    final suggestion = remaining.isEmpty
        ? 'Các công việc trên đều đã hoàn thành.'
        : 'Gợi ý: bạn có thể tập trung vào “${remaining.first.title}” trước vì công việc này chưa hoàn thành${highOnly || remaining.first.priority == TaskPriority.high ? ' và có mức ưu tiên cao' : ''}.';
    return 'Bạn có ${selected.length} công việc${highOnly ? ' ưu tiên cao' : ''} trong $range:\n\n$lines\n\n$suggestion';
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String _priority(TaskPriority p) => switch (p) {
    TaskPriority.low => 'Thấp',
    TaskPriority.medium => 'Trung bình',
    TaskPriority.high => 'Cao',
  };
  static String _status(TaskStatus s) => switch (s) {
    TaskStatus.pending => 'Chờ xử lý',
    TaskStatus.inProgress => 'Đang làm',
    TaskStatus.completed => 'Đã hoàn thành',
  };
}
