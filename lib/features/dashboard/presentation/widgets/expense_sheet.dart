import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/dashboard_repository.dart';
import '../../../jars/domain/jar_repository.dart';
import 'dashboard_cards.dart';

class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({
    super.key,
    required this.onSave,
    required this.date,
    required this.isDemo,
    required this.loadSources,
    this.isPersistent = false,
  });
  final Future<void> Function(ExpenseDraft) onSave;
  final DateTime date;
  final bool isDemo;
  final bool isPersistent;
  final Future<List<ExpenseSource>> Function() loadSources;

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  final _requestId = newRequestId();
  late final DateTime _occurredAt;
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  FinanceCategory _category = FinanceCategory.food;
  bool _saving = false;
  String? _error;
  List<ExpenseSource>? _sources;
  String _sourceId = 'unallocated';
  @override
  void initState() {
    super.initState();
    _occurredAt = widget.date;
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final sources = await widget.loadSources();
      if (mounted) {
        setState(() {
          _sources = sources;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tải được nguồn tiền. Hãy thử lại.');
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _sources == null || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        ExpenseDraft(
          requestId: _requestId,
          title: _title.text.trim(),
          amount: int.parse(_amount.text),
          category: _category,
          occurredAt: _occurredAt,
          jarId: _sourceId == 'unallocated' ? null : _sourceId,
          note: _note.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is FinanceRuleException
              ? error.message
              : 'Chưa lưu được khoản chi. Bạn thử lại nhé.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thêm khoản chi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Ngày ${_occurredAt.day}/${_occurredAt.month}/${_occurredAt.year}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (widget.isDemo) ...[
                const SizedBox(height: 12),
                Text(
                  widget.isPersistent
                      ? 'Đang dùng dữ liệu mẫu. Khoản chi được lưu trên máy chủ.'
                      : 'Bản xem trước · Khoản chi chỉ được giữ đến khi khởi động lại ứng dụng.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('expense-title'),
                controller: _title,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Bạn đã chi cho việc gì?',
                  hintText: 'Ví dụ: Ăn trưa',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập nội dung khoản chi.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('expense-note'),
                controller: _note,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  hintText: 'Ví dụ: Ăn trưa cùng nhóm sau buổi họp',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('expense-amount'),
                controller: _amount,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  hintText: 'Ví dụ: 65000',
                  suffixText: 'VND',
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Nhập số tiền lớn hơn 0.';
                  }
                  final source = _sources
                      ?.where((s) => (s.jarId ?? 'unallocated') == _sourceId)
                      .firstOrNull;
                  if (source != null && amount > source.availableAmount) {
                    return 'Số tiền vượt số dư nguồn được chọn.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_sources != null)
                DropdownButtonFormField<String>(
                  key: const ValueKey('expense-source'),
                  initialValue: _sourceId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Trừ tiền từ'),
                  items: [
                    for (final source in _sources!)
                      DropdownMenuItem(
                        value: source.jarId ?? 'unallocated',
                        child: Text(
                          '${source.title} · ${formatVnd(source.availableAmount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _sourceId = value);
                        },
                )
              else if (_error == null)
                const LinearProgressIndicator()
              else
                TextButton(
                  onPressed: _loadSources,
                  child: const Text('Tải lại nguồn tiền'),
                ),
              const SizedBox(height: 24),
              const Text(
                'Danh mục',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: FinanceCategory.values.map((category) {
                  final (icon, _, label) = categoryAppearance(category);
                  return ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: _category == category
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
                    selected: _category == category,
                    showCheckmark: false,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _category = category),
                  );
                }).toList(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.pink),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('save-expense'),
                  onPressed: _saving || _sources == null ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 19),
                  label: Text(_saving ? 'Đang lưu…' : 'Lưu khoản chi'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
