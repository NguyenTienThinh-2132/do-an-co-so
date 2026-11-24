import 'package:flutter/material.dart';

import '../application/assistant_controller.dart';
import '../domain/assistant_models.dart';

/// Chuyển bố cục chatAI.html; các thao tác tài chính/OCR/voice chưa triển khai.
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, required this.controller});
  final AssistantController controller;
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  AssistantScenario _scenario = AssistantScenario.success;
  @override
  void initState() {
    super.initState();
    _input.addListener(_onInput);
    widget.controller.addListener(_onChat);
  }

  void _onInput() {
    if (mounted) setState(() {});
  }

  void _onChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send([String? suggestion]) {
    if (widget.controller.send(
      suggestion ?? _input.text,
      scenario: _scenario,
    )) {
      _input.clear();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChat);
    _input.removeListener(_onInput);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FD),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F7FD),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trợ lý FinAI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Chế độ mô phỏng',
                style: TextStyle(fontSize: 12, color: Color(0xFF630ED4)),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<AssistantScenario>(
              tooltip: 'Kịch bản mẫu',
              initialValue: _scenario,
              onSelected: controller.replying
                  ? null
                  : (value) => setState(() => _scenario = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: AssistantScenario.success,
                  child: Text('Bình thường'),
                ),
                PopupMenuItem(
                  value: AssistantScenario.slow,
                  child: Text('Chậm'),
                ),
                PopupMenuItem(
                  value: AssistantScenario.error,
                  child: Text('Lỗi thử nghiệm'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (controller.messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 44,
                              color: Color(0xFF630ED4),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Hỏi FinAI về công việc của bạn',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Mẫu chỉ đọc TaskReader, chưa dùng LLM hoặc dữ liệu tài chính.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    for (final message in controller.messages)
                      Align(
                        alignment: message.role == ChatRole.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: message.role == ChatRole.user
                                ? const Color(0xFF630ED4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SelectableText(
                            message.text,
                            style: TextStyle(
                              color: message.role == ChatRole.user
                                  ? Colors.white
                                  : const Color(0xFF181445),
                            ),
                          ),
                        ),
                      ),
                    if (controller.replying)
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Đang trả lời…')),
                          TextButton(
                            onPressed: controller.cancel,
                            child: const Text('Dừng'),
                          ),
                        ],
                      ),
                    if (controller.failure != null)
                      Card(
                        color: const Color(0xFFFFDAD6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text(
                                'Chưa trả lời được. Bạn có thể thử lại.',
                              ),
                              TextButton(
                                onPressed: controller.retry,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final text in [
                      'Việc trong khoảng này',
                      'Việc ưu tiên cao',
                      'Tiến độ',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(text),
                          onPressed: controller.replying
                              ? null
                              : () => _send(text),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('assistant-input'),
                        controller: _input,
                        enabled: !controller.replying,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Hỏi về công việc…',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('assistant-send'),
                      tooltip: 'Gửi',
                      onPressed:
                          controller.replying || _input.text.trim().isEmpty
                          ? null
                          : () => _send(),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
