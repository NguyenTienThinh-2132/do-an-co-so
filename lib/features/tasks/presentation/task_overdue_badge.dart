import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/entities/task.dart';
import '../domain/entities/task_status.dart';

/// Suy ra từ thời gian/trạng thái, không ghi cột quá hạn vào database.
class TaskOverdueBadge extends StatefulWidget {
  const TaskOverdueBadge({super.key, required this.task, this.now});
  final Task task;
  final DateTime Function()? now;
  @override
  State<TaskOverdueBadge> createState() => _TaskOverdueBadgeState();
}

class _TaskOverdueBadgeState extends State<TaskOverdueBadge>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _overdue = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    final now = widget.now?.call() ?? DateTime.now();
    _overdue = widget.task.isOverdueAt(now);
    if (!_overdue && widget.task.status != TaskStatus.completed) {
      var wait =
          widget.task.endAt.difference(now) + const Duration(milliseconds: 1);
      if (wait > const Duration(days: 1)) wait = const Duration(days: 1);
      if (wait <= Duration.zero) wait = const Duration(milliseconds: 1);
      _timer = Timer(wait, () {
        if (mounted) setState(_sync);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TaskOverdueBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_sync);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _overdue
      ? const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Quá hạn',
            style: TextStyle(
              color: Color(0xFFBE123C),
              fontWeight: FontWeight.w600,
            ),
          ),
        )
      : const SizedBox.shrink();
}
