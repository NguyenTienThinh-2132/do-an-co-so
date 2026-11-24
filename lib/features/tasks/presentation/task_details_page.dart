import 'package:flutter/material.dart';

import '../../../core/types/app_failure.dart';
import '../application/task_details_controller.dart';
import '../domain/entities/task_status.dart';
import '../domain/entities/task_priority.dart';
import 'task_overdue_badge.dart';
import '../application/task_reminder_editor_controller.dart';
import 'task_reminder_editor.dart';

class TaskDetailsPage extends StatelessWidget {
  const TaskDetailsPage({
    super.key,
    required this.controller,
    this.onEdit,
    this.now,
    this.reminderController,
  });
  final TaskDetailsController controller;
  final VoidCallback? onEdit;
  final DateTime Function()? now;
  final TaskReminderEditorController? reminderController;

  String _date(DateTime value) {
    final d = value.toLocal();
    final date = [d.day, d.month, d.year].join('/');
    final time = [
      d.hour.toString().padLeft(2, '0'),
      d.minute.toString().padLeft(2, '0'),
    ].join(':');
    return '$date • $time';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final task = controller.task;
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          actions: [
            if (task != null)
              IconButton(
                onPressed: onEdit,
                tooltip: 'Sửa công việc',
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : task == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 40,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(height: 16),
                      Text(switch (controller.failure?.code) {
                        AppFailureCode.notFound =>
                          'Công việc không còn tồn tại hoặc đã bị xóa.',
                        AppFailureCode.validation =>
                          'ID công việc không hợp lệ.',
                        _ => 'Không thể tải công việc.',
                      }, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: controller.load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B0A33), Color(0xFF471B8C)],
                          ),
                        ),
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TaskOverdueBadge(task: task, now: now),
                      if (reminderController != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TaskReminderEditor(
                                  controller: reminderController!,
                                ),
                                AnimatedBuilder(
                                  animation: reminderController!,
                                  builder: (context, _) => FilledButton(
                                    onPressed:
                                        reminderController!.saving ||
                                            reminderController!.port == null
                                        ? null
                                        : () => reminderController!.apply(task),
                                    child: const Text('Lưu nhắc việc'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.schedule),
                              title: const Text('Bắt đầu'),
                              subtitle: Text(_date(task.startAt)),
                            ),
                            ListTile(
                              leading: const Icon(Icons.event),
                              title: const Text('Kết thúc'),
                              subtitle: Text(_date(task.endAt)),
                            ),
                            ListTile(
                              leading: const Icon(Icons.flag_outlined),
                              title: const Text('Ưu tiên'),
                              subtitle: Text(switch (task.priority) {
                                TaskPriority.low => 'Thấp',
                                TaskPriority.medium => 'Trung bình',
                                TaskPriority.high => 'Cao',
                              }),
                            ),
                            ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: const Text('Trạng thái'),
                              subtitle: Text(switch (task.status) {
                                TaskStatus.pending => 'Chờ xử lý',
                                TaskStatus.inProgress => 'Đang làm',
                                TaskStatus.completed => 'Đã xong',
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mô tả',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                task.description?.trim().isNotEmpty == true
                                    ? task.description!
                                    : 'Chưa có mô tả.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
