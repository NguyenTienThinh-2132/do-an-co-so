import 'dart:async';
import 'dart:convert';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const id = '850ca704-a7e5-437e-a206-0c42af3bf22d';
  final base = Uri.parse('https://example.test/api/');
  final start = DateTime.utc(2026, 11, 7, 2);
  final end = DateTime.utc(2026, 11, 7, 3);
  TaskDraft draft() =>
      TaskDraft(title: 'Báo cáo TV3', startAt: start, endAt: end);
  Map<String, Object?> fixture() => {
    'id': id,
    'title': 'Báo cáo TV3',
    'description': null,
    'categoryId': null,
    'startAt': start.toIso8601String(),
    'endAt': end.toIso8601String(),
    'priority': 'medium',
    'status': 'pending',
    'createdAt': start.toIso8601String(),
    'updatedAt': start.toIso8601String(),
  };
  http.Response jsonResponse(Object? body, [int status = 200]) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
  TaskRemoteDatasource source(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return TaskRemoteDatasource(client: client, baseUrl: base);
  }

  test('GET ID giữ prefix và đọc tiếng Việt UTF-8', () async {
    final api = source((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/api/tasks/$id');
      expect(request.headers['accept'], 'application/json');
      return jsonResponse(fixture());
    });
    final result = await api.getById(id);
    expect((result as Success<Task>).value.title, 'Báo cáo TV3');
  });

  test('GET list encode thời gian và đầy đủ bộ lọc', () async {
    final api = source((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/tasks');
      expect(request.url.queryParameters, {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'status': 'inProgress',
        'priority': 'high',
        'searchText': 'báo cáo %_&+?',
      });
      return jsonResponse([fixture()]);
    });
    final result = await api.list(
      TaskQuery(
        start: start,
        end: end,
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        searchText: 'báo cáo %_&+?',
      ),
    );
    expect((result as Success<List<Task>>).value.single.id, id);
  });

  test('List rỗng là thành công, không gửi bộ lọc bỏ trống', () async {
    final api = source((request) async {
      expect(
        request.url.queryParameters.keys,
        unorderedEquals(['start', 'end']),
      );
      return jsonResponse([]);
    });
    final result = await api.list(TaskQuery(start: start, end: end));
    expect((result as Success<List<Task>>).value, isEmpty);
  });

  test('POST chỉ gửi nội dung hợp đồng bằng JSON UTF-8', () async {
    final api = source((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/tasks');
      expect(
        request.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(jsonDecode(utf8.decode(request.bodyBytes)), {
        'title': 'Báo cáo TV3',
        'description': null,
        'categoryId': null,
        'startAt': start.toIso8601String(),
        'endAt': end.toIso8601String(),
        'priority': 'medium',
      });
      return jsonResponse(fixture(), 201);
    });
    expect(await api.create(draft()), isA<Success<Task>>());
  });

  test('PUT nội dung và PATCH trạng thái dùng đúng route/body', () async {
    final methods = <String>[];
    final api = source((request) async {
      methods.add(request.method);
      final body = jsonDecode(request.body);
      if (request.method == 'PUT') {
        expect(request.url.path, '/api/tasks/$id');
        expect(body, isNot(contains('status')));
      } else {
        expect(request.url.path, '/api/tasks/$id/status');
        expect(body, {'status': 'completed'});
      }
      return jsonResponse({...fixture(), 'status': 'completed'});
    });
    expect(await api.update(id, draft()), isA<Success<Task>>());
    final result = await api.setStatus(id, TaskStatus.completed);
    expect((result as Success<Task>).value.status, TaskStatus.completed);
    expect(methods, ['PUT', 'PATCH']);
  });

  test('DELETE 204 không parse JSON rỗng', () async {
    final api = source((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/tasks/$id');
      expect(request.body, isEmpty);
      return http.Response('', 204);
    });
    expect(await api.delete(id), isA<Success<void>>());
  });

  for (final entry in {
    400: AppFailureCode.validation,
    422: AppFailureCode.validation,
    401: AppFailureCode.permissionDenied,
    403: AppFailureCode.permissionDenied,
    404: AppFailureCode.notFound,
    409: AppFailureCode.conflict,
    429: AppFailureCode.unavailable,
    500: AppFailureCode.unavailable,
    503: AppFailureCode.unavailable,
  }.entries) {
    test('HTTP ${entry.key} ánh xạ lỗi an toàn', () async {
      final api = source(
        (_) async => http.Response('private SQL details', entry.key),
      );
      final result = await api.getById(id) as Failure<Task>;
      expect(result.failure.code, entry.value);
      expect(result.failure.message, isNot(contains('private SQL details')));
    });
  }

  test('Không chấp nhận status thành công ngoài hợp đồng', () async {
    final api = source((_) async => jsonResponse(fixture()));
    expect(
      (await api.create(draft()) as Failure<Task>).failure.code,
      AppFailureCode.unavailable,
    );
  });

  test('Mất kết nối trả unavailable, không lộ chi tiết client', () async {
    final api = source((_) async {
      throw http.ClientException('private URL details');
    });
    final result = await api.getById(id) as Failure<Task>;
    expect(result.failure.code, AppFailureCode.unavailable);
    expect(result.failure.message, isNot(contains('private URL details')));
  });

  test('Timeout trả unavailable và không retry thao tác ghi', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return pending.future;
    });
    addTearDown(client.close);
    final api = TaskRemoteDatasource(
      client: client,
      baseUrl: base,
      timeout: const Duration(milliseconds: 10),
    );
    final result = await api.create(draft()) as Failure<Task>;
    expect(result.failure.code, AppFailureCode.unavailable);
    expect(calls, 1);
    pending.complete(jsonResponse(fixture(), 201));
  });

  test('Lỗi server không tự retry POST', () async {
    var calls = 0;
    final api = source((_) async {
      calls++;
      return http.Response('', 503);
    });
    expect(await api.create(draft()), isA<Failure<Task>>());
    expect(calls, 1);
  });

  test('JSON/enum/UTF-8 sai đều thành unavailable', () async {
    for (final response in [
      http.Response('not-json', 200),
      jsonResponse({...fixture(), 'status': 'overdue'}),
      jsonResponse([fixture()]),
      http.Response.bytes([0xff], 200),
    ]) {
      final api = source((_) async => response);
      expect(
        (await api.getById(id) as Failure<Task>).failure.code,
        AppFailureCode.unavailable,
      );
    }
  });

  test('Không bỏ qua bản ghi hỏng trong list', () async {
    final api = source((_) async => jsonResponse([fixture(), null]));
    final result = await api.list(
      TaskQuery(start: start, end: end),
    ) as Failure<List<Task>>;
    expect(result.failure.code, AppFailureCode.unavailable);
  });

  test('ID rỗng/khoảng trắng không gọi HTTP', () async {
    final api = source((_) async {
      fail('Không được gọi HTTP.');
    });
    for (final invalidId in ['', ' ', ' id ']) {
      expect(
        (await api.getById(invalidId) as Failure<Task>).failure.code,
        AppFailureCode.validation,
      );
      expect(await api.update(invalidId, draft()), isA<Failure<Task>>());
      expect(
        await api.setStatus(invalidId, TaskStatus.pending),
        isA<Failure<Task>>(),
      );
      expect(await api.delete(invalidId), isA<Failure<void>>());
    }
  });

  test('ID không thể trở thành path/query khác', () async {
    const specialId = 'a/b?x#y';
    final api = source((request) async {
      expect(request.url.pathSegments, ['api', 'tasks', specialId]);
      expect(request.url.hasQuery, isFalse);
      expect(request.url.hasFragment, isFalse);
      return http.Response('', 400);
    });
    expect(await api.getById(specialId), isA<Failure<Task>>());
  });

  test('Phát hiện URL và timeout cấu hình sai', () {
    final client = MockClient((_) async => http.Response('', 200));
    addTearDown(client.close);
    for (final url in [
      '/relative',
      'ftp://example.test',
      'https://user:pass@example.test',
      'https://example.test?q=x',
      'https://example.test#fragment',
    ]) {
      expect(
        () => TaskRemoteDatasource(client: client, baseUrl: Uri.parse(url)),
        throwsArgumentError,
      );
    }
    expect(
      () => TaskRemoteDatasource(
        client: client,
        baseUrl: base,
        timeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test('Không đóng client được truyền từ bên ngoài', () async {
    final client = MockClient((_) async => jsonResponse(fixture()));
    addTearDown(client.close);
    final api = TaskRemoteDatasource(client: client, baseUrl: base);
    await api.getById(id);
    expect(
      (await client.get(Uri.parse('https://example.test/probe'))).statusCode,
      200,
    );
  });
}
