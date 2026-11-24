import '../application/task_create_controller.dart';
import 'task_form_page.dart';

/// Form tạo dùng chung layout/validation với form sửa.
class TaskCreatePage extends TaskFormPage {
  const TaskCreatePage({
    super.key,
    required TaskCreateController controller,
    required super.initialDay,
    super.reminderPort,
  }) : super(controller: controller);
}
