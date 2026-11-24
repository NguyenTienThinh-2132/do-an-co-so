import 'dart:math';

import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/task_create_controller.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const url = String.fromEnvironment('TV3_TASKS_API_BASE_URL');
T value<T>(Result<T> result) => (result as Success<T>).value;

void main() {
  test('create controller lưu vào PostgreSQL và dọn fixture', () async {
    final base = Uri.parse(url);
    expect(base.scheme, 'http');
    expect(base.host, '127.0.0.1');
    expect(base.userInfo, isEmpty);
    expect(base.hasQuery || base.hasFragment, isFalse);
    expect(['', '/', '/api'].contains(base.path), isTrue);
    final nonce = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final marker = 'TV3 Create form $nonce';
    final query = TaskQuery(
      start: DateTime.utc(2046, 1, 2),
      end: DateTime.utc(2046, 1, 3),
      searchText: marker,
    );
    final client = http.Client();
    final source = TaskRemoteDatasource(client: client, baseUrl: base);
    final repository = HttpTaskRepository(datasource: source);
    final controller = TaskCreateController(repository: repository);
    try {
      final created = await controller.submit(
        TaskDraft(
          title: marker,
          description: 'Fixture tự dọn',
          startAt: DateTime.utc(2046, 1, 2, 9),
          endAt: DateTime.utc(2046, 1, 2, 10),
        ),
      );
      expect(created, isA<Task>());
      expect(controller.failure, isNull);
      expect(controller.saving, isFalse);
      final loaded = value(await source.getById(created!.id));
      expect(loaded.title, marker);
      expect(loaded.description, 'Fixture tự dọn');
      expect(value(await source.list(query)).single.id, created.id);
    } finally {
      controller.dispose();
      repository.dispose();
      try {
        for (final task in value(
          await source.list(query),
        ).where((task) => task.title == marker)) {
          expect(await source.delete(task.id), isA<Success<void>>());
        }
        expect(value(await source.list(query)), isEmpty);
      } finally {
        client.close();
      }
    }
  }, skip: url.isEmpty ? 'Cần backend demo và TV3_TASKS_API_BASE_URL' : false);
}
