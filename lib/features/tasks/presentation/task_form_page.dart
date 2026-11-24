import 'package:flutter/material.dart';

import '../../../core/types/result.dart';
import '../application/task_reminder_editor_controller.dart';
import '../domain/ports/task_reminder_port.dart';
import 'task_reminder_editor.dart';

import '../../../core/types/app_failure.dart';

import '../application/task_form_controller.dart';
import '../domain/entities/task_draft.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_priority.dart';

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({
    super.key,
    required this.controller,
    required this.initialDay,
    this.initialTask,
    this.reminderPort,
  });
  final TaskFormController controller;
  final DateTime initialDay;
  final Task? initialTask;
  final TaskReminderPort? reminderPort;
  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  TaskPriority _priority = TaskPriority.medium;
  String? _timeError;
  Task? _savedTask;
  bool _reminderAttempted = false;
  late final TaskReminderEditorController _reminder;

  @override
  void initState() {
    super.initState();
    _reminder = TaskReminderEditorController(
      port: widget.reminderPort,
      initialAt:
          widget.initialTask?.startAt ??
          DateTime(
            widget.initialDay.year,
            widget.initialDay.month,
            widget.initialDay.day,
            9,
          ),
    );
    _reminder.addListener(_onReminder);
    final task = widget.initialTask;
    if (task != null) {
      _title.text = task.title;
      _description.text = task.description ?? '';
      _priority = task.priority;
      _start = task.startAt.toLocal();
      _end = task.endAt.toLocal();
      return;
    }
    final day = widget.initialDay.toLocal();
    _start = DateTime(day.year, day.month, day.day, 9);
    _end = DateTime(day.year, day.month, day.day, 10);
  }

  void _onReminder() {
    if (mounted) setState(() {});
  }

  String _date(DateTime d) => [d.day, d.month, d.year].join('/');
  String _time(DateTime d) => [
    d.hour.toString().padLeft(2, '0'),
    d.minute.toString().padLeft(2, '0'),
  ].join(':');

  Future<void> _pick(bool start, bool date) async {
    final initial = start ? _start : _end;
    DateTime? value;
    if (date) {
      final selected = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200, 12, 31),
      );
      if (selected != null) {
        value = DateTime(
          selected.year,
          selected.month,
          selected.day,
          initial.hour,
          initial.minute,
        );
      }
    } else {
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (selected != null) {
        value = DateTime(
          initial.year,
          initial.month,
          initial.day,
          selected.hour,
          selected.minute,
        );
      }
    }
    if (!mounted || value == null) return;
    if (start && _reminder.at.isAtSameMomentAs(_start)) _reminder.setAt(value);
    setState(() {
      if (start) {
        _start = value!;
      } else {
        _end = value!;
      }
      _timeError = null;
    });
  }

  Future<void> _save() async {
    if (widget.controller.saving || _reminder.saving) return;
    final valid = _form.currentState!.validate();
    setState(() {
      _timeError = _end.isAfter(_start)
          ? null
          : 'Kết thúc phải sau thời điểm bắt đầu.';
    });
    if (!valid || _timeError != null) return;
    FocusScope.of(context).unfocus();
    final task =
        _savedTask ??
        await widget.controller.submit(
          TaskDraft(
            title: _title.text,
            categoryId: widget.initialTask?.categoryId,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            startAt: _start,
            endAt: _end,
            priority: _priority,
          ),
        );
    if (!mounted || task == null) return;
    _savedTask = task;
    if (widget.initialTask == null &&
        (_reminder.enabled || _reminderAttempted)) {
      _reminderAttempted = true;
      final result = await _reminder.apply(task);
      if (!mounted) return;
      if (result is Failure<void>) {
        setState(() {});
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _reminder.removeListener(_onReminder);
    _reminder.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.saving || _reminder.saving;
      final saving = busy || _savedTask != null;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF6F7FB),
            leading: IconButton(
              onPressed: busy ? null : () => Navigator.maybePop(context),
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
            ),
            title: Text(
              widget.initialTask == null ? 'Công việc mới' : 'Sửa công việc',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton(
                  key: const Key('task-save'),
                  onPressed: busy ? null : _save,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_savedTask == null ? 'Lưu' : 'Lưu nhắc việc'),
                ),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    if (widget.initialTask == null)
                      _section(
                        child: TaskReminderEditor(
                          controller: _reminder,
                          blocked: busy,
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Nhắc việc được quản lý ở màn chi tiết.'),
                      ),
                    if (_savedTask != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Công việc đã lưu; chỉ đang lưu lại nhắc việc, không tạo thêm công việc.',
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B0A33), Color(0xFF471B8C)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Color(0xFFC084FC),
                            size: 32,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dành thời gian cho điều quan trọng',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Lên lịch công việc cùng FinAI',
                                  style: TextStyle(
                                    color: Color(0xFFE9D5FF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('task-title'),
                      controller: _title,
                      enabled: !saving,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Thêm tên công việc',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tên công việc.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _section(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.schedule, color: Color(0xFF7C3AED)),
                              SizedBox(width: 10),
                              Text(
                                'Thời gian',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _timeRow('Bắt đầu', true, saving),
                          const Divider(height: 24),
                          _timeRow('Kết thúc', false, saving),
                          const SizedBox(height: 10),
                          const Text(
                            'Giờ địa phương trên thiết bị',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          if (_timeError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _timeError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _section(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                color: Color(0xFF7C3AED),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Mức ưu tiên',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final option in <(TaskPriority, String)>[
                                (TaskPriority.low, 'Thấp'),
                                (TaskPriority.medium, 'Trung bình'),
                                (TaskPriority.high, 'Cao'),
                              ])
                                ChoiceChip(
                                  label: Text(option.$2),
                                  selected: _priority == option.$1,
                                  onSelected: saving
                                      ? null
                                      : (_) => setState(
                                          () => _priority = option.$1,
                                        ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _section(
                      child: TextFormField(
                        key: const Key('task-description'),
                        controller: _description,
                        enabled: !saving,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          hintText: 'Thêm ghi chú cho công việc…',
                          prefixIcon: Icon(Icons.notes),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (widget.controller.failure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          widget.controller.failure!.code ==
                                  AppFailureCode.notFound
                              ? 'Công việc đã bị xóa. Đóng form để quay lại danh sách.'
                              : 'Chưa lưu được công việc. Kiểm tra dữ liệu hoặc kết nối và bấm Lưu để thử lại.',
                          key: const Key('task-save-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _section({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEDE8F5)),
    ),
    child: child,
  );

  Widget _timeRow(String label, bool start, bool saving) {
    final value = start ? _start : _end;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: saving ? null : () => _pick(start, true),
              child: Text(_date(value)),
            ),
            TextButton(
              onPressed: saving ? null : () => _pick(start, false),
              child: Text(_time(value)),
            ),
          ],
        ),
      ],
    );
  }
}
