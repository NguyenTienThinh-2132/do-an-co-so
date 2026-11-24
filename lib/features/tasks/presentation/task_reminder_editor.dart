import 'package:flutter/material.dart';

import '../application/task_reminder_editor_controller.dart';

class TaskReminderEditor extends StatelessWidget {
  const TaskReminderEditor({
    super.key,
    required this.controller,
    this.blocked = false,
  });
  final TaskReminderEditorController controller;
  final bool blocked;
  Future<void> _pick(BuildContext context) async {
    final initial = controller.at;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
      lastDate: DateTime(initial.year > 2200 ? initial.year : 2200, 12, 31),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null) {
      controller.setAt(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = controller;
      final busy = blocked || c.loading || c.saving;
      final date = [c.at.day, c.at.month, c.at.year].join('/');
      final time = [
        c.at.hour.toString().padLeft(2, '0'),
        c.at.minute.toString().padLeft(2, '0'),
      ].join(':');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            title: const Text('Nhắc việc'),
            subtitle: Text(
              c.port == null
                  ? 'Chỉ hoạt động trên Android'
                  : 'Thông báo cục bộ trên điện thoại này',
            ),
            secondary: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF7C3AED),
            ),
            value: c.enabled,
            onChanged: busy || c.port == null ? null : c.setEnabled,
          ),
          if (c.enabled) ...[
            TextButton.icon(
              onPressed: busy ? null : () => _pick(context),
              icon: const Icon(Icons.schedule),
              label: Text('$date • $time'),
            ),
            const Text(
              'Cần cho phép thông báo và Báo thức & nhắc việc.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : c.notificationPermission,
                  child: const Text('Cấp quyền thông báo'),
                ),
                TextButton(
                  onPressed: busy ? null : c.exactSettings,
                  child: const Text('Quyền nhắc chính xác'),
                ),
              ],
            ),
          ],
          if (c.loading || c.saving) const LinearProgressIndicator(),
          if (c.failure != null)
            Text(
              c.failure!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (c.saved)
            const Text(
              'Đã lưu cài đặt nhắc việc.',
              style: TextStyle(color: Color(0xFF7C3AED)),
            ),
        ],
      );
    },
  );
}
