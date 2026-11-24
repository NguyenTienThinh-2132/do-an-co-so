import '../../../core/types/app_failure.dart';
import '../../tasks/domain/entities/task_query.dart';

enum ChatRole { user, assistant }

enum AssistantScenario { success, slow, error }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
}

class AssistantRequest {
  AssistantRequest({
    required String text,
    required this.query,
    this.scenario = AssistantScenario.success,
  }) : text = text.trim() {
    if (this.text.isEmpty) throw ArgumentError('Tin nhắn không được rỗng.');
  }
  final String text;
  final TaskQuery query;
  final AssistantScenario scenario;
}

sealed class AssistantEvent {
  const AssistantEvent();
}

class AssistantText extends AssistantEvent {
  const AssistantText(this.text);
  final String text;
}

class AssistantDone extends AssistantEvent {
  const AssistantDone();
}

class AssistantError extends AssistantEvent {
  const AssistantError(this.failure);
  final AppFailure failure;
}

abstract interface class AssistantService {
  Stream<AssistantEvent> reply(AssistantRequest request);
}
