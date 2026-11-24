import '../../../core/types/result.dart';
import '../domain/entities/task.dart';
import '../domain/entities/task_draft.dart';
import 'task_form_controller.dart';

class TaskCreateController extends TaskFormController {
  TaskCreateController({required super.repository});
  @override
  Future<Result<Task>> persist(TaskDraft draft) => repository.create(draft);
}
