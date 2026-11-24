import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/jar_repository.dart';
import '../models/jar_view_data.dart';

String _errorMessage(Object error) => error is FinanceRuleException
    ? error.message
    : 'Chưa lưu được thay đổi. Dữ liệu cũ được giữ nguyên, bạn thử lại nhé.';

class JarSheetFrame extends StatelessWidget {
  const JarSheetFrame({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    required this.busy,
  });
  final String title;
  final Widget body;
  final Widget action;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.9 - inset)
                  .clamp(100.0, double.infinity),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: body,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                  child: SizedBox(width: double.infinity, child: action),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteJarSheet extends StatefulWidget {
  const DeleteJarSheet({
    super.key,
    required this.repository,
    required this.overview,
    required this.jar,
    required this.moneyVisible,
  });
  final JarRepository repository;
  final JarOverview overview;
  final Jar jar;
  final bool moneyVisible;
  @override
  State<DeleteJarSheet> createState() => _DeleteJarSheetState();
}

class _DeleteJarSheetState extends State<DeleteJarSheet> {
  final _requestId = newRequestId();
  String? _recipient;
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    if (_busy || (widget.jar.allocationBps > 0 && _recipient == null)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.deleteJar(
        requestId: _requestId,
        jarId: widget.jar.id,
        expectedRevision: widget.overview.revision,
        transferRatioToJarId: _recipient,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => JarSheetFrame(
    title: 'Xóa hũ',
    busy: _busy,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bạn muốn xóa hũ “${widget.jar.title}”?',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tiền trả về phần chưa phân bổ',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        MoneyText(
          widget.jar.remainingAmount,
          visible: widget.moneyVisible,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tổng số dư tài khoản giữ nguyên. Lịch sử phân bổ và các khoản chi cũ vẫn được lưu.',
          style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
        ),
        if (widget.jar.allocationBps > 0) ...[
          const SizedBox(height: 20),
          Text(
            'Chuyển ${formatBps(widget.jar.allocationBps)} tỷ lệ sang hũ khác để tổng vẫn là 100%.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('delete-ratio-recipient'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Hũ nhận tỷ lệ'),
            items: [
              for (final jar in widget.overview.jars.where(
                (j) => j.id != widget.jar.id,
              ))
                DropdownMenuItem(
                  value: jar.id,
                  child: Text(
                    '${jar.title} · ${formatBps(jar.allocationBps)} → ${formatBps(jar.allocationBps + widget.jar.allocationBps)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _recipient = value;
                    _error = null;
                  }),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Hũ này sẽ biến mất khỏi danh sách hũ đang dùng và nguồn chi tiền.',
          style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.pink)),
        ],
      ],
    ),
    action: FilledButton.icon(
      key: const ValueKey('confirm-delete-jar'),
      style: FilledButton.styleFrom(backgroundColor: AppColors.pink),
      onPressed: _busy || (widget.jar.allocationBps > 0 && _recipient == null)
          ? null
          : _delete,
      icon: const Icon(Icons.delete_outline_rounded),
      label: Text(_busy ? 'Đang xóa…' : 'Xác nhận xóa'),
    ),
  );
}

class AddJarSheet extends StatefulWidget {
  const AddJarSheet({super.key, required this.repository});
  final JarRepository repository;
  @override
  State<AddJarSheet> createState() => _AddJarSheetState();
}

class _AddJarSheetState extends State<AddJarSheet> {
  final _requestId = newRequestId();
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  String _style = 'target';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.addJar(
        requestId: _requestId,
        title: _title.text,
        subtitle: _subtitle.text,
        styleKey: _style,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => JarSheetFrame(
    title: 'Thêm hũ mới',
    busy: _busy,
    body: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hũ mới bắt đầu với 0 ₫ và tỷ lệ 0%. Sau khi thêm, bạn có thể điều chỉnh tỷ lệ để hũ nhận tiền.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('new-jar-title'),
            controller: _title,
            enabled: !_busy,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên hũ',
              hintText: 'Ví dụ: Mua laptop',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Nhập tên hũ.' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('new-jar-description'),
            controller: _subtitle,
            enabled: !_busy,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Mục đích (không bắt buộc)',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Biểu tượng',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final key in [
                'target',
                'home',
                'savings',
                'education',
                'enjoyment',
                'investment',
                'giving',
              ])
                ChoiceChip(
                  label: Text(
                    jarStyle(key).$3,
                    style: const TextStyle(fontSize: 11),
                  ),
                  avatar: Icon(jarStyle(key).$1, size: 16),
                  selected: _style == key,
                  showCheckmark: false,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _style = key),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.pink),
              ),
            ),
        ],
      ),
    ),
    action: FilledButton.icon(
      key: const ValueKey('save-new-jar'),
      onPressed: _busy ? null : _save,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(_busy ? 'Đang lưu…' : 'Tạo hũ'),
    ),
  );
}

int? parseBps(String text) {
  if (!RegExp(r'^\d{1,3}([.,]\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.replaceAll(',', '.').split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 || parts[1].isEmpty
          ? 0
          : int.parse(parts[1].padRight(2, '0')));
}

String bpsInput(int value) => value % 100 == 0
    ? '${value ~/ 100}'
    : '${value ~/ 100},${(value % 100).toString().padLeft(2, '0')}';

class AllocationRatiosSheet extends StatefulWidget {
  const AllocationRatiosSheet({
    super.key,
    required this.repository,
    required this.overview,
  });
  final JarRepository repository;
  final JarOverview overview;
  @override
  State<AllocationRatiosSheet> createState() => _AllocationRatiosSheetState();
}

class _AllocationRatiosSheetState extends State<AllocationRatiosSheet> {
  final _requestId = newRequestId();
  late final Map<String, TextEditingController> _fields = {
    for (final jar in widget.overview.jars)
      jar.id: TextEditingController(text: bpsInput(jar.allocationBps)),
  };
  bool _busy = false;
  String? _error;
  int get _total =>
      _fields.values.fold(0, (sum, field) => sum + (parseBps(field.text) ?? 0));
  bool get _valid =>
      _total == 10000 &&
      _fields.values.every((field) => parseBps(field.text) != null);
  int _maxFor(String id) =>
      10000 -
      _fields.entries
          .where((entry) => entry.key != id)
          .fold<int>(
            0,
            (sum, entry) => sum + (parseBps(entry.value.text) ?? 0),
          );
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.setAllocations(
        {
          for (final entry in _fields.entries)
            entry.key: parseBps(entry.value.text)!,
        },
        expectedRevision: widget.overview.revision,
        requestId: _requestId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => JarSheetFrame(
    title: 'Chỉnh tỷ lệ phân bổ',
    busy: _busy,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lilac,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đã chia: ${formatBps(_total)}',
                key: const ValueKey('ratios-total'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Còn được chia: ${formatBps(10000 - _total)}',
                key: const ValueKey('ratios-remaining'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Giảm tỷ lệ một hũ để dành phần cho hũ khác. Tổng phải đúng 100% mới áp dụng; tiền đã có trong hũ được giữ nguyên.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        for (final jar in widget.overview.jars)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 13, right: 10),
                    child: Text(
                      jar.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: TextField(
                    key: ValueKey('ratio-${jar.id}'),
                    controller: _fields[jar.id],
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        final parsed = parseBps(newValue.text);
                        return parsed != null && parsed <= _maxFor(jar.id)
                            ? newValue
                            : oldValue;
                      }),
                    ],
                    decoration: InputDecoration(
                      suffixText: '%',
                      helperText: 'Tối đa ${formatBps(_maxFor(jar.id))}',
                      helperMaxLines: 2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.pink)),
      ],
    ),
    action: FilledButton(
      key: const ValueKey('save-ratios'),
      onPressed: _busy || !_valid ? null : _save,
      child: Text(_busy ? 'Đang lưu…' : 'Áp dụng tỷ lệ'),
    ),
  );
}

class AllocateMoneySheet extends StatefulWidget {
  const AllocateMoneySheet({
    super.key,
    required this.repository,
    required this.overview,
    required this.moneyVisible,
  });
  final JarRepository repository;
  final JarOverview overview;
  final bool moneyVisible;
  @override
  State<AllocateMoneySheet> createState() => _AllocateMoneySheetState();
}

class _AllocateMoneySheetState extends State<AllocateMoneySheet> {
  final _amount = TextEditingController();
  final _requestId =
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 30).toRadixString(36)}';
  bool _busy = false;
  String? _error;
  int get _value => int.tryParse(_amount.text) ?? 0;
  bool get _valid =>
      _value > 0 &&
      _value <= widget.overview.unallocated &&
      widget.overview.totalBps == 10000;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.allocate(
        amount: _value,
        requestId: _requestId,
        expectedRevision: widget.overview.revision,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _valid
        ? splitAllocation(_value, widget.overview.jars)
        : <String, int>{};
    return JarSheetFrame(
      title: 'Phân bổ thêm tiền',
      busy: _busy,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lấy từ tiền chưa phân bổ. Tổng số dư Trang chủ không thay đổi.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          const Text(
            'Có thể phân bổ',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          MoneyText(
            widget.overview.unallocated,
            visible: widget.moneyVisible,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('allocation-amount'),
            controller: _amount,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: const InputDecoration(
              labelText: 'Số tiền muốn phân bổ',
              hintText: 'Ví dụ: 1000000',
              suffixText: 'VND',
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (text) {
              final value = int.tryParse(text ?? '');
              if (value == null || value <= 0) return 'Nhập số tiền lớn hơn 0.';
              if (value > widget.overview.unallocated) {
                return 'Vượt số tiền chưa phân bổ hiện có.';
              }
              return null;
            },
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 20),
          const Text(
            'Xem trước cách chia',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final jar in widget.overview.jars)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${jar.title} · ${formatBps(jar.allocationBps)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: MoneyText(
                      preview[jar.id] ?? 0,
                      visible: widget.moneyVisible,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_valid)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tổng: ${widget.moneyVisible ? formatVnd(_value) : '••••••'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.pink),
              ),
            ),
        ],
      ),
      action: FilledButton(
        key: const ValueKey('confirm-allocation'),
        onPressed: _busy || !_valid ? null : _save,
        child: Text(_busy ? 'Đang phân bổ…' : 'Xác nhận phân bổ'),
      ),
    );
  }
}
