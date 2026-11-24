import 'dart:async';

import 'package:flutter/material.dart';

import 'task_overdue_badge.dart';

import '../application/tasks_list_controller.dart';
import '../application/task_status_controller.dart';
import '../application/task_delete_controller.dart';
import '../../../core/types/app_failure.dart';
import '../application/tasks_list_state.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_priority.dart';
import '../domain/entities/task_query.dart';
import '../domain/entities/task_calendar_range.dart';
import '../domain/entities/task_status.dart';

const _purple = Color(0xFF7C3AED);

/// Chủ sở hữu load/dispose controller. Query là nguồn ngày đang chọn.
class TasksDayPage extends StatelessWidget {
  const TasksDayPage({
    super.key,
    required this.controller,
    this.dailyController,
    this.now,
    this.onCreate,
    this.onAssistant,
    this.onInbox,
    this.reminderChanges,
    this.hasReminderWarning,
    this.retryReminderSync,
    this.onOpen,
    this.onEdit,
    this.statusController,
    this.deleteController,
    this.mode = TasksCalendarMode.day,
    this.selectedDate,
    this.onModeChanged,
    this.onDateSelected,
    this.onPrevious,
    this.onNext,
    this.focusWeekDay = false,
    this.onShowWholeWeek,
  });
  final TasksCalendarMode mode;
  final DateTime? selectedDate;
  final ValueChanged<TasksCalendarMode>? onModeChanged;
  final ValueChanged<DateTime>? onDateSelected;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool focusWeekDay;
  final VoidCallback? onShowWholeWeek;
  final TasksListController controller;
  final Listenable? reminderChanges;
  final bool Function()? hasReminderWarning;
  final VoidCallback? retryReminderSync;
  final VoidCallback? onCreate;
  final VoidCallback? onAssistant;
  final VoidCallback? onInbox;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onEdit;
  final TaskStatusController? statusController;
  final TaskDeleteController? deleteController;

  /// Snapshot không lọc cùng ngày; được inject tại composition root.
  final TasksListController? dailyController;

  void _selectStatus(TaskStatus? status) {
    final query = controller.state.query;
    controller.setQuery(
      TaskQuery(
        start: query.start,
        end: query.end,
        status: status,
        priority: query.priority,
        searchText: query.searchText,
      ),
    );
  }

  void _selectPriority(TaskPriority? priority) {
    final query = controller.state.query;
    controller.setQuery(
      TaskQuery(
        start: query.start,
        end: query.end,
        status: query.status,
        priority: priority,
        searchText: query.searchText,
      ),
    );
  }

  TasksListState _dailyState(TasksListState state) {
    final daily = dailyController?.state;
    if (daily != null &&
        daily.query.start == state.query.start &&
        daily.query.end == state.query.end &&
        daily.query.status == null &&
        daily.query.priority == null &&
        daily.query.searchText.isEmpty) {
      return daily;
    }
    // Không lấy số liệu đã lọc làm tổng cả ngày nếu thiếu snapshot phù hợp.
    return state.query.status == null &&
            state.query.priority == null &&
            state.query.searchText.isEmpty
        ? state
        : TasksListState.initial(state.query);
  }

  /// Chỉ inject đồng hồ khi test; mặc định lấy thời gian thật lúc bấm.
  final DateTime Function()? now;

  void _selectDay(DateTime value) {
    if (onDateSelected != null) {
      onDateSelected!(value);
      return;
    }
    final local = value.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final query = controller.state.query;
    controller.setQuery(
      TaskQuery(
        start: day,
        end: DateTime(day.year, day.month, day.day + 1),
        status: query.status,
        priority: query.priority,
        searchText: query.searchText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: onCreate == null
        ? null
        : FloatingActionButton(
            onPressed: onCreate,
            tooltip: 'Thêm công việc',
            child: const Icon(Icons.add),
          ),
    backgroundColor: const Color(0xFFF6F7FB),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          controller,
          dailyController,
          statusController,
          deleteController,
          reminderChanges,
        ]),
        builder: (context, _) {
          final state = controller.state;
          final selectedDay = selectedDate ?? state.query.start.toLocal();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _Header(onAssistant: onAssistant, onInbox: onInbox),
              if (hasReminderWarning?.call() == true)
                Card(
                  color: const Color(0xFFFFE8D8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          'Công việc đã lưu nhưng nhắc việc cục bộ chưa đồng bộ.',
                        ),
                        TextButton(
                          onPressed: retryReminderSync,
                          child: const Text('Đồng bộ lại nhắc việc'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _Summary(
                state: _dailyState(state),
                title: mode == TasksCalendarMode.day
                    ? 'TIẾN ĐỘ TRONG NGÀY'
                    : mode == TasksCalendarMode.week
                    ? 'TIẾN ĐỘ TRONG TUẦN'
                    : 'TIẾN ĐỘ TRONG THÁNG',
                onRetry: (dailyController ?? controller).retry,
              ),
              const SizedBox(height: 16),
              _ViewSelector(mode: mode, onChanged: onModeChanged),
              const SizedBox(height: 16),
              if (mode != TasksCalendarMode.day)
                Row(
                  children: [
                    IconButton(
                      key: const Key('tasks-period-previous'),
                      onPressed: onPrevious,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        mode == TasksCalendarMode.week
                            ? 'Lịch tuần trực quan'
                            : 'Lịch tháng',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      key: const Key('tasks-period-next'),
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              _CalendarStrip(
                day: selectedDay,
                showDays: mode != TasksCalendarMode.month,
                tasks: mode == TasksCalendarMode.week ? state.tasks : null,
                onSelect: _selectDay,
                onToday: () => _selectDay(now?.call() ?? DateTime.now()),
              ),
              if (mode == TasksCalendarMode.month)
                _MonthGrid(
                  day: selectedDay,
                  tasks: state.tasks,
                  onSelect: _selectDay,
                ),
              if (mode == TasksCalendarMode.week && focusWeekDay)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onShowWholeWeek,
                    child: const Text('Xem cả tuần'),
                  ),
                ),
              const SizedBox(height: 12),
              _TaskSearchField(controller: controller),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final option in <(String, TaskStatus?)>[
                    ('Tất cả', null),
                    ('Chờ xử lý', TaskStatus.pending),
                    ('Đang làm', TaskStatus.inProgress),
                    ('Đã xong', TaskStatus.completed),
                  ])
                    ChoiceChip(
                      key: ValueKey('task-status-${option.$2?.name ?? 'all'}'),
                      label: Text(option.$1),
                      selected: state.query.status == option.$2,
                      selectedColor: _purple,
                      labelStyle: TextStyle(
                        color: state.query.status == option.$2
                            ? Colors.white
                            : null,
                      ),
                      onSelected: (_) => _selectStatus(option.$2),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  key: const Key('tasks-priority-filter'),
                  tooltip: 'Lọc theo mức ưu tiên',
                  initialValue: state.query.priority?.name ?? 'all',
                  onSelected: (value) => _selectPriority(switch (value) {
                    'low' => TaskPriority.low,
                    'medium' => TaskPriority.medium,
                    'high' => TaskPriority.high,
                    _ => null,
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('Mọi mức ưu tiên')),
                    PopupMenuItem(value: 'high', child: Text('Ưu tiên cao')),
                    PopupMenuItem(
                      value: 'medium',
                      child: Text('Ưu tiên trung bình'),
                    ),
                    PopupMenuItem(value: 'low', child: Text('Ưu tiên thấp')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.flag_outlined, size: 18),
                    backgroundColor: state.query.priority == null
                        ? Colors.white
                        : const Color(0xFFEDE9FE),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            switch (state.query.priority) {
                              TaskPriority.high => 'Ưu tiên cao',
                              TaskPriority.medium => 'Ưu tiên trung bình',
                              TaskPriority.low => 'Ưu tiên thấp',
                              null => 'Mọi mức ưu tiên',
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dòng thời gian ngày ${selectedDay.day}/${selectedDay.month}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._calendarContent(state, selectedDay),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _calendarContent(TasksListState state, DateTime date) {
    if (state.phase != TasksListPhase.ready || mode == TasksCalendarMode.day) {
      return _content(state);
    }
    if (mode == TasksCalendarMode.month || focusWeekDay) {
      return _content(
        TasksListState.ready(
          state.query,
          state.tasks.where(
            (task) => TaskCalendarRange.overlapsDay(task, date),
          ),
        ),
      );
    }
    if (state.isEmpty) return _content(state);
    return [
      for (final day in TaskCalendarRange(date, TasksCalendarMode.week).days)
        if (state.tasks.any((t) => TaskCalendarRange.overlapsDay(t, day))) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Thứ ${day.weekday == 7 ? "CN" : day.weekday + 1} • ${day.day}/${day.month}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _purple,
              ),
            ),
          ),
          ..._content(
            TasksListState.ready(
              state.query,
              state.tasks.where((t) => TaskCalendarRange.overlapsDay(t, day)),
            ),
          ),
        ],
    ];
  }

  List<Widget> _content(TasksListState state) => switch (state.phase) {
    TasksListPhase.initial || TasksListPhase.loading => [
      const _MessageCard(
        child: Column(
          children: [
            CircularProgressIndicator(color: _purple),
            SizedBox(height: 16),
            Text('Đang tải công việc…'),
          ],
        ),
      ),
    ],
    TasksListPhase.error => [
      _MessageCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, color: _purple, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Không thể tải công việc. Vui lòng thử lại.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                controller.retry();
                dailyController?.retry();
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    ],
    TasksListPhase.ready when state.isEmpty => [
      const _MessageCard(
        child: Column(
          children: [
            Icon(Icons.done_all, size: 40, color: _purple),
            SizedBox(height: 12),
            Text(
              'Không có công việc nào!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Không có công việc phù hợp với ngày và bộ lọc đã chọn.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ],
    TasksListPhase.ready => [
      for (final task in state.tasks) ...[
        _TaskCard(
          task: task,
          now: now,
          onOpen: onOpen == null ? null : () => onOpen!(task.id),
          deleteController: deleteController,
          onRefresh: () {
            controller.retry();
            dailyController?.retry();
          },
          onEdit: onEdit == null ? null : () => onEdit!(task.id),
          statusSaving: statusController?.isSaving(task.id) ?? false,
          statusFailure: statusController?.failureFor(task.id),
          onStatus: statusController == null
              ? null
              : (status) =>
                    unawaited(statusController!.setStatus(task.id, status)),
          onRetryStatus: statusController == null
              ? null
              : () => unawaited(statusController!.retry(task.id)),
        ),
        const SizedBox(height: 12),
      ],
    ],
  };
}

class _Header extends StatelessWidget {
  const _Header({this.onAssistant, this.onInbox});
  final VoidCallback? onAssistant;
  final VoidCallback? onInbox;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.event_available, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch trình Công việc',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 3),
            Text(
              'FinAI Schedule & Task',
              style: TextStyle(color: _purple, fontSize: 12),
            ),
          ],
        ),
      ),
      if (onAssistant != null)
        IconButton(
          onPressed: onAssistant,
          tooltip: 'Trợ lý AI',
          icon: const Icon(Icons.auto_awesome, color: _purple),
        ),
      IconButton(
        onPressed: onInbox,
        tooltip: 'Native Inbox',
        icon: Icon(Icons.notifications_none),
      ),
    ],
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    this.onRetry,
    this.title = 'TIẾN ĐỘ TRONG NGÀY',
  });
  final TasksListState state;
  final String title;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final ready = state.phase == TasksListPhase.ready;
    final total = state.tasks.length;
    final completed = state.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final ongoing = state.tasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B0A33), Color(0xFF471B8C), Color(0xFF351069)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.diamond_outlined,
                  color: Color(0xFFC084FC),
                  size: 22,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FinAI Premier Planner',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (state.phase == TasksListPhase.error)
              TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thử lại tiến độ'),
              ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Color(0xFFE9D5FF)),
            ),
            const SizedBox(height: 8),
            Text(
              ready ? '$completed / $total công việc' : '— / — công việc',
              key: const Key('tasks-progress-count'),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tỷ lệ hoàn thành:',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        ready ? '${(ratio * 100).toStringAsFixed(1)}%' : '—',
                        key: const Key('tasks-progress-percent'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: ready ? ratio : 0,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFC084FC),
                    backgroundColor: Colors.white12,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 24,
                    runSpacing: 6,
                    children: [
                      Text(ready ? 'Đang làm: $ongoing' : 'Đang làm: —'),
                      Text(
                        ready ? 'Còn lại: ${total - completed}' : 'Còn lại: —',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.mode, this.onChanged});
  final TasksCalendarMode mode;
  final ValueChanged<TasksCalendarMode>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE7E8EF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final option in <(TasksCalendarMode, String)>[
          (TasksCalendarMode.day, 'Ngày'),
          (TasksCalendarMode.week, 'Tuần'),
          (TasksCalendarMode.month, 'Tháng'),
        ])
          Expanded(
            child: Material(
              color: mode == option.$1 ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: ValueKey(['tasks-view', option.$1.name].join('-')),
                borderRadius: BorderRadius.circular(12),
                onTap: onChanged == null ? null : () => onChanged!(option.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    option.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mode == option.$1 ? _purple : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CalendarStrip extends StatefulWidget {
  const _CalendarStrip({
    required this.day,
    required this.onSelect,
    required this.onToday,
    this.showDays = true,
    this.tasks,
  });
  final DateTime day;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onToday;
  final bool showDays;
  final List<Task>? tasks;

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  bool _opening = false;

  Future<void> _pickDate() async {
    if (_opening) return;
    setState(() => _opening = true);
    final initial = widget.day;
    DateTime? selected;
    try {
      selected = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
        lastDate: DateTime(initial.year > 2200 ? initial.year : 2200, 12, 31),
        helpText: 'Chọn ngày công việc',
        cancelText: 'Hủy',
        confirmText: 'Chọn',
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (mounted && selected != null) widget.onSelect(selected);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('tasks-date-picker'),
                onPressed: _opening ? null : _pickDate,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tháng ${day.month}, ${day.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            TextButton(
              key: const Key('tasks-today'),
              onPressed: widget.onToday,
              child: const Text('Hôm nay'),
            ),
          ],
        ),
        if (widget.showDays)
          SizedBox(
            height: widget.tasks == null ? 76 : 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = DateTime(
                  monday.year,
                  monday.month,
                  monday.day + index,
                );
                final selected =
                    date.year == day.year &&
                    date.month == day.month &&
                    date.day == day.day;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Ngày ${date.day}/${date.month}/${date.year}',
                  child: Material(
                    color: selected ? _purple : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey(
                        'task-day-${date.year}-${date.month}-${date.day}',
                      ),
                      onTap: () => widget.onSelect(date),
                      child: SizedBox(
                        width: 48,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              index == 6 ? 'CN' : 'T${index + 2}',
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                            if (widget.tasks != null)
                              Text(
                                [
                                  widget.tasks!
                                      .where(
                                        (t) => TaskCalendarRange.overlapsDay(
                                          t,
                                          date,
                                        ),
                                      )
                                      .length
                                      .toString(),
                                  'việc',
                                ].join(' '),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: selected ? Colors.white : Colors.grey,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    this.now,
    this.onOpen,
    this.onEdit,
    this.statusSaving = false,
    this.statusFailure,
    this.onStatus,
    this.onRetryStatus,
    this.deleteController,
    this.onRefresh,
  });
  final Task task;
  final DateTime Function()? now;
  final VoidCallback? onOpen;
  final TaskDeleteController? deleteController;
  final VoidCallback? onRefresh;
  final bool statusSaving;
  final AppFailure? statusFailure;
  final ValueChanged<TaskStatus>? onStatus;
  final VoidCallback? onRetryStatus;
  final VoidCallback? onEdit;
  String _clock(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final busy =
        statusSaving || (deleteController?.isDeleting(task.id) ?? false);
    final deleteFailure = deleteController?.failureFor(task.id);
    final done = task.status == TaskStatus.completed;
    final status = switch (task.status) {
      TaskStatus.pending => 'Chờ xử lý',
      TaskStatus.inProgress => 'Đang làm',
      TaskStatus.completed => 'Đã xong',
    };
    final priority = switch (task.priority) {
      TaskPriority.low => 'Thấp',
      TaskPriority.medium => 'Trung bình',
      TaskPriority.high => 'Ưu tiên cao',
    };
    final priorityColor = switch (task.priority) {
      TaskPriority.high => const Color(0xFFBE123C),
      TaskPriority.medium => _purple,
      TaskPriority.low => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEDE8F5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onStatus != null)
            PopupMenuButton<TaskStatus>(
              key: ValueKey('task-status-menu-${task.id}'),
              tooltip: 'Đổi trạng thái',
              onSelected: onStatus,
              icon: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? _purple : Colors.grey,
              ),
              itemBuilder: (_) => [
                for (final option in <(TaskStatus, String)>[
                  (TaskStatus.pending, 'Chờ xử lý'),
                  (TaskStatus.inProgress, 'Đang làm'),
                  (TaskStatus.completed, 'Đã xong'),
                ])
                  PopupMenuItem(
                    value: option.$1,
                    enabled: option.$1 != task.status,
                    child: Text(option.$2),
                  ),
              ],
            )
          else
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? _purple : Colors.grey,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${_clock(task.startAt)} – ${_clock(task.endAt)}',
                      style: const TextStyle(color: _purple, fontSize: 12),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          priority,
                          style: TextStyle(fontSize: 11, color: priorityColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: busy ? null : onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                TaskOverdueBadge(task: task, now: now),
                if (statusFailure != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    statusFailure!.code == AppFailureCode.notFound
                        ? 'Công việc đã bị xóa. Hãy tải lại danh sách.'
                        : 'Chưa đổi được trạng thái. Vui lòng thử lại.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : onRetryStatus,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (deleteFailure != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    deleteFailure.code == AppFailureCode.notFound
                        ? 'Công việc đã bị xóa trước đó. Hãy tải lại danh sách.'
                        : 'Không xóa được. Bấm thùng rác để xác nhận và thử lại.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : onRefresh,
                    child: const Text('Tải lại danh sách'),
                  ),
                ],
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 12, color: _purple),
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Sửa công việc',
                        onPressed: busy ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    if (deleteController != null)
                      _TaskDeleteButton(
                        task: task,
                        controller: deleteController!,
                        blocked: busy,
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
}

/// Chỉ quản lý ô nhập/debounce; không sở hữu repository hoặc controller danh sách.
class _TaskSearchField extends StatefulWidget {
  const _TaskSearchField({required this.controller});
  final TasksListController controller;
  @override
  State<_TaskSearchField> createState() => _TaskSearchFieldState();
}

class _TaskSearchFieldState extends State<_TaskSearchField>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _text;
  late String _applied;
  Timer? _timer;
  bool _syncing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _applied = widget.controller.state.query.searchText;
    _text = TextEditingController(text: _applied)..addListener(_onEdit);
    widget.controller.addListener(_syncQuery);
  }

  @override
  void didUpdateWidget(covariant _TaskSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncQuery);
      _timer?.cancel();
      _applied = widget.controller.state.query.searchText;
      _syncing = true;
      _text.text = _applied;
      _syncing = false;
      widget.controller.addListener(_syncQuery);
    }
  }

  void _syncQuery() {
    final search = widget.controller.state.query.searchText;
    if (search == _applied) return;
    _timer?.cancel();
    _applied = search;
    _syncing = true;
    _text.value = TextEditingValue(
      text: search,
      selection: TextSelection.collapsed(offset: search.length),
    );
    _syncing = false;
    setState(() {});
  }

  void _onEdit() {
    if (_syncing) return;
    _timer?.cancel();
    setState(() {});
    final composing = _text.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    _timer = Timer(const Duration(milliseconds: 350), _apply);
  }

  void _apply() {
    _timer?.cancel();
    if (!mounted) return;
    final query = widget.controller.state.query;
    final search = _text.text.trim();
    if (search == query.searchText) return;
    widget.controller.setQuery(
      TaskQuery(
        start: query.start,
        end: query.end,
        status: query.status,
        priority: query.priority,
        searchText: search,
      ),
    );
  }

  void _clear() {
    _text.clear();
    _apply();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_syncQuery);
    _text.removeListener(_onEdit);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TextField(
      key: const Key('tasks-search'),
      controller: _text,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _apply(),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm theo tên công việc',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                key: const Key('tasks-search-clear'),
                tooltip: 'Xóa tìm kiếm',
                onPressed: _clear,
                icon: const Icon(Icons.cancel_outlined),
              ),
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TaskDeleteButton extends StatefulWidget {
  const _TaskDeleteButton({
    required this.task,
    required this.controller,
    required this.blocked,
  });
  final Task task;
  final TaskDeleteController controller;
  final bool blocked;
  @override
  State<_TaskDeleteButton> createState() => _TaskDeleteButtonState();
}

class _TaskDeleteButtonState extends State<_TaskDeleteButton> {
  bool _confirming = false;
  Future<void> _confirm() async {
    if (_confirming || widget.blocked) return;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.delete_outline, color: Color(0xFFBE123C)),
        title: const Text('Xóa công việc?'),
        content: Text(widget.task.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('task-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed == true && !widget.blocked) {
      await widget.controller.delete(widget.task.id);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey(['task-delete', widget.task.id].join('-')),
    tooltip: 'Xóa công việc',
    color: const Color(0xFFBE123C),
    onPressed: widget.blocked || _confirming ? null : _confirm,
    icon: const Icon(Icons.delete_outline, size: 20),
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.day,
    required this.tasks,
    required this.onSelect,
  });
  final DateTime day;
  final List<Task> tasks;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(day.year, day.month);
    final start = DateTime(day.year, day.month, 2 - first.weekday);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: Text('T2', textAlign: TextAlign.center)),
              Expanded(child: Text('T3', textAlign: TextAlign.center)),
              Expanded(child: Text('T4', textAlign: TextAlign.center)),
              Expanded(child: Text('T5', textAlign: TextAlign.center)),
              Expanded(child: Text('T6', textAlign: TextAlign.center)),
              Expanded(child: Text('T7', textAlign: TextAlign.center)),
              Expanded(child: Text('CN', textAlign: TextAlign.center)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 54,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final date = DateTime(start.year, start.month, start.day + index);
              final selected =
                  date.year == day.year &&
                  date.month == day.month &&
                  date.day == day.day;
              final count = tasks
                  .where((t) => TaskCalendarRange.overlapsDay(t, date))
                  .length;
              return Semantics(
                button: true,
                selected: selected,
                label: [
                  [date.day, date.month, date.year].join('/'),
                  '$count công việc',
                ].join(': '),
                child: Material(
                  color: selected ? _purple : const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: ValueKey(
                      [
                        'tasks-month',
                        [date.year, date.month, date.day].join('-'),
                      ].join('-'),
                    ),
                    onTap: () => onSelect(date),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : date.month == day.month
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                        if (count > 0)
                          Text(
                            '$count việc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: selected ? Colors.white : _purple,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
