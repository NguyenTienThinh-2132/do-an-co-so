import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/types/app_failure.dart';
import '../../tasks/domain/entities/task_query.dart';
import '../domain/assistant_models.dart';

class AssistantController extends ChangeNotifier {
  AssistantController({
    required this.service,
    required this.query,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final AssistantService service;
  TaskQuery query;
  void updateQuery(TaskQuery value) {
    if (!_disposed) query = value;
  }

  final DateTime Function() _now;
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool _replying = false;
  bool get replying => _replying;
  AppFailure? _failure;
  AppFailure? get failure => _failure;
  AssistantRequest? _failedRequest;
  StreamSubscription<AssistantEvent>? _subscription;
  int _generation = 0;
  int _id = 0;
  bool _disposed = false;

  bool send(
    String text, {
    AssistantScenario scenario = AssistantScenario.success,
  }) {
    if (_disposed || _replying || text.trim().isEmpty) return false;
    final request = AssistantRequest(
      text: text,
      query: query,
      scenario: scenario,
    );
    _messages.add(
      ChatMessage(
        id: (++_id).toString(),
        role: ChatRole.user,
        text: request.text,
        createdAt: _now().toUtc(),
      ),
    );
    _start(request);
    return true;
  }

  void retry() {
    if (_disposed || _replying || _failedRequest == null) return;
    // Kịch bản lỗi cố định được retry bằng success, không tự lặp lỗi vô hạn.
    final old = _failedRequest!;
    _start(AssistantRequest(text: old.text, query: old.query));
  }

  void _start(AssistantRequest request) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    final generation = ++_generation;
    _replying = true;
    _failure = null;
    _failedRequest = null;
    notifyListeners();
    var response = '';
    try {
      _subscription = service
          .reply(request)
          .listen(
            (event) {
              if (_disposed || generation != _generation || !_replying) return;
              switch (event) {
                case AssistantText(:final text):
                  response += text;
                case AssistantDone():
                  if (response.isNotEmpty) {
                    _messages.add(
                      ChatMessage(
                        id: (++_id).toString(),
                        role: ChatRole.assistant,
                        text: response,
                        createdAt: _now().toUtc(),
                      ),
                    );
                  }
                  _replying = false;
                case AssistantError(:final failure):
                  _failure = failure;
                  _failedRequest = request;
                  _replying = false;
              }
              notifyListeners();
            },
            onError: (Object _) {
              if (!_disposed && generation == _generation && _replying) {
                _fail(request);
              }
            },
            onDone: () {
              if (!_disposed && generation == _generation && _replying) {
                _fail(request);
              }
            },
          );
    } catch (_) {
      _fail(request);
    }
  }

  void _fail(AssistantRequest request) {
    if (_disposed || !_replying) return;
    _replying = false;
    _failedRequest = request;
    _failure = const AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Chưa nhận được câu trả lời. Hãy thử lại.',
    );
    notifyListeners();
  }

  void cancel() {
    if (_disposed || !_replying) return;
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _replying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
