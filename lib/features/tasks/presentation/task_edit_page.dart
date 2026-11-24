import 'package:flutter/material.dart';

import '../../../core/types/app_failure.dart';
import '../application/task_edit_controller.dart';
import 'task_form_page.dart';

class TaskEditPage extends StatelessWidget {
  const TaskEditPage({super.key, required this.controller});
  final TaskEditController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final task = controller.task;
      if (!controller.loading && task != null) {
        return TaskFormPage(
          key: ValueKey(task.id),
          controller: controller,
          initialDay: task.startAt.toLocal(),
          initialTask: task,
        );
      }
      final code = controller.loadFailure?.code;
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(title: const Text('Sửa công việc')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: controller.loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 40,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(height: 16),
                      Text(switch (code) {
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
        ),
      );
    },
  );
}
