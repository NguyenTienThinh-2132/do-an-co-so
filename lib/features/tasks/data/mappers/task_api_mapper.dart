import '../../domain/entities/task.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_priority.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/task_status.dart';

/// Chuyển dữ liệu API, không gửi HTTP và không phụ thuộc widget.
abstract final class TaskApiMapper {
  static Task fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Task phải là JSON object.');
    }
    try {
      return Task(
        id: _requiredString(data, 'id'),
        title: _requiredString(data, 'title'),
        description: _optionalString(data, 'description'),
        categoryId: _optionalString(data, 'categoryId'),
        startAt: _instant(data, 'startAt'),
        endAt: _instant(data, 'endAt'),
        priority: _enumValue(data, 'priority', TaskPriority.values),
        status: _enumValue(data, 'status', TaskStatus.values),
        createdAt: _instant(data, 'createdAt'),
        updatedAt: _instant(data, 'updatedAt'),
      );
    } on ArgumentError {
      throw const FormatException('Task vi phạm quy tắc tên hoặc thời gian.');
    }
  }

  static List<Task> listFromJson(Object? data) {
    if (data is! List) {
      throw const FormatException('Danh sách Task phải là JSON array.');
    }
    return List<Task>.unmodifiable(data.map(fromJson));
  }

  /// Hydrates a validated local draft using the same ISO/enum rules as the API.
  static TaskDraft draftFromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('TaskDraft must be an object.');
    }
    try {
      return TaskDraft(
        title: _requiredString(data, 'title'),
        description: _optionalString(data, 'description'),
        categoryId: _optionalString(data, 'categoryId'),
        startAt: _instant(data, 'startAt'),
        endAt: _instant(data, 'endAt'),
        priority: _enumValue(data, 'priority', TaskPriority.values),
      );
    } on ArgumentError {
      throw const FormatException('Invalid task draft.');
    }
  }

  /// Full read snapshot for SQLite cache; never use this for POST/PUT bodies.
  static Map<String, Object?> toJson(Task task) => {
    'id': task.id,
    'title': task.title,
    'description': task.description,
    'categoryId': task.categoryId,
    'startAt': task.startAt.toUtc().toIso8601String(),
    'endAt': task.endAt.toUtc().toIso8601String(),
    'priority': task.priority.name,
    'status': task.status.name,
    'createdAt': task.createdAt.toUtc().toIso8601String(),
    'updatedAt': task.updatedAt.toUtc().toIso8601String(),
  };

  /// Chỉ gửi nội dung được phép tạo/sửa; không gửi ID, status hoặc timestamps.
  static Map<String, Object?> draftToJson(TaskDraft draft) => {
    'title': draft.title,
    'description': draft.description,
    'categoryId': draft.categoryId,
    'startAt': draft.startAt.toUtc().toIso8601String(),
    'endAt': draft.endAt.toUtc().toIso8601String(),
    'priority': draft.priority.name,
  };

  /// Truyền kết quả cho Uri.queryParameters; không tự ghép/encode URL.
  static Map<String, String> queryToParameters(TaskQuery query) => {
    'start': query.start.toUtc().toIso8601String(),
    'end': query.end.toUtc().toIso8601String(),
    if (query.status != null) 'status': query.status!.name,
    if (query.priority != null) 'priority': query.priority!.name,
    if (query.searchText.isNotEmpty) 'searchText': query.searchText,
  };

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Trường $field phải là chuỗi không rỗng.');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Trường $field phải là chuỗi hoặc null.');
    }
    return value;
  }

  static T _enumValue<T extends Enum>(
    Map<String, dynamic> data,
    String field,
    List<T> values,
  ) {
    final name = _requiredString(data, field);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Trường $field có giá trị không hỗ trợ.');
  }

  static final _isoTimestamp = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$',
  );

  static DateTime _instant(Map<String, dynamic> data, String field) {
    final text = _requiredString(data, field);
    final match = _isoTimestamp.firstMatch(text);
    if (match == null) {
      throw FormatException('Trường $field phải là ISO timestamp có múi giờ.');
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6]!);
    final zone = match[8]!;
    final invalidZone =
        zone != 'Z' &&
        (int.parse(zone.substring(1, 3)) > 23 ||
            int.parse(zone.substring(4, 6)) > 59);
    // DateTime.tryParse có thể tự chuẩn hóa ngày sai, nên kiểm tra trước.
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        invalidZone) {
      throw FormatException('Trường $field có ngày giờ không hợp lệ.');
    }
    final instant = DateTime.tryParse(text);
    if (instant == null) {
      throw FormatException('Trường $field có ngày giờ không hợp lệ.');
    }
    return instant.toUtc();
  }
}
