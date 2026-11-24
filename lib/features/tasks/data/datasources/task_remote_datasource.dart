import 'task_availability_failure.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/types/app_failure.dart';
import '../../../../core/types/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/task_status.dart';
import '../mappers/task_api_mapper.dart';

/// Gọi API Tasks; không tự mở database hoặc đóng client do bên ngoài truyền vào.
///
/// Không tự retry thao tác ghi. Chưa cấu hình mạng Android.
class TaskRemoteDatasource {
  TaskRemoteDatasource({
    required this.client,
    required Uri baseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl,
       _timeout = timeout {
    if (!['http', 'https'].contains(baseUrl.scheme) ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError(
        'baseUrl phải là HTTP(S) URL không chứa credentials/query/fragment.',
      );
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Phải lớn hơn 0.');
    }
  }

  final http.Client client;
  final Uri _baseUrl;
  final Duration _timeout;

  Future<Result<List<Task>>> list(TaskQuery query) => _request(
    'GET',
    ['tasks'],
    expectedStatus: 200,
    query: TaskApiMapper.queryToParameters(query),
    decode: (response) => TaskApiMapper.listFromJson(_json(response)),
  );

  Future<Result<Task>> getById(String id) {
    if (!_validId(id)) return Future.value(_invalidId<Task>());
    return _request(
      'GET',
      ['tasks', id],
      expectedStatus: 200,
      decode: (response) => TaskApiMapper.fromJson(_json(response)),
    );
  }

  Future<Result<Task>> create(TaskDraft draft) => _request(
    'POST',
    ['tasks'],
    expectedStatus: 201,
    body: TaskApiMapper.draftToJson(draft),
    decode: (response) => TaskApiMapper.fromJson(_json(response)),
  );

  Future<Result<Task>> update(String id, TaskDraft draft) {
    if (!_validId(id)) return Future.value(_invalidId<Task>());
    return _request(
      'PUT',
      ['tasks', id],
      expectedStatus: 200,
      body: TaskApiMapper.draftToJson(draft),
      decode: (response) => TaskApiMapper.fromJson(_json(response)),
    );
  }

  Future<Result<Task>> setStatus(String id, TaskStatus status) {
    if (!_validId(id)) return Future.value(_invalidId<Task>());
    return _request(
      'PATCH',
      ['tasks', id, 'status'],
      expectedStatus: 200,
      body: {'status': status.name},
      decode: (response) => TaskApiMapper.fromJson(_json(response)),
    );
  }

  Future<Result<void>> delete(String id) {
    if (!_validId(id)) return Future.value(_invalidId<void>());
    return _request<void>(
      'DELETE',
      ['tasks', id],
      expectedStatus: 204,
      decode: (_) {},
    );
  }

  Future<Result<T>> _request<T>(
    String method,
    List<String> path, {
    required int expectedStatus,
    required T Function(http.Response) decode,
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final abort = Completer<void>();
    final uri = _baseUrl.replace(
      pathSegments: [
        ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...path,
      ],
      queryParameters: query,
    );
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    )..headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }

    Future<http.Response> send() async {
      final streamed = await client.send(request);
      return http.Response.fromStream(streamed);
    }

    try {
      final response = await send().timeout(
        _timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw TimeoutException('Tasks request timed out.');
        },
      );
      if (response.statusCode != expectedStatus) {
        return Failure<T>(_httpFailure(response.statusCode));
      }
      return Success<T>(decode(response));
    } on TimeoutException {
      return Failure<T>(
        const TaskAvailabilityFailure(
          message: 'Kết nối quá thời gian chờ. Vui lòng thử lại.',
        ),
      );
    } on http.ClientException {
      return Failure<T>(
        const TaskAvailabilityFailure(
          message: 'Không kết nối được máy chủ công việc.',
        ),
      );
    } on FormatException {
      return Failure<T>(
        const AppFailure(
          code: AppFailureCode.unavailable,
          message: 'Máy chủ trả dữ liệu công việc không hợp lệ.',
        ),
      );
    }
  }

  static Object? _json(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));
  static bool _validId(String id) => id.isNotEmpty && id == id.trim();

  static Failure<T> _invalidId<T>() => Failure<T>(
    const AppFailure(
      code: AppFailureCode.validation,
      message: 'ID công việc không được rỗng hoặc có khoảng trắng ở đầu/cuối.',
    ),
  );

  static AppFailure _httpFailure(int status) => switch (status) {
    400 || 422 => const AppFailure(
      code: AppFailureCode.validation,
      message: 'Dữ liệu hoặc bộ lọc công việc không hợp lệ.',
    ),
    401 || 403 => const AppFailure(
      code: AppFailureCode.permissionDenied,
      message: 'Không có quyền thực hiện thao tác công việc.',
    ),
    404 => const AppFailure(
      code: AppFailureCode.notFound,
      message: 'Không tìm thấy công việc.',
    ),
    409 => const AppFailure(
      code: AppFailureCode.conflict,
      message: 'Dữ liệu công việc bị xung đột.',
    ),
    >= 500 && <= 599 => const TaskAvailabilityFailure(
      message: 'Dịch vụ công việc tạm ngừng. Vui lòng thử lại.',
    ),
    _ => const AppFailure(
      code: AppFailureCode.unavailable,
      message: 'Dịch vụ công việc chưa sẵn sàng. Vui lòng thử lại.',
    ),
  };
}
