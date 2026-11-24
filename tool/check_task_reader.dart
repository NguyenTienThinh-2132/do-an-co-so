import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:finai/features/tasks/data/repositories/http_task_repository.dart';
import 'package:finai/features/tasks/domain/entities/task.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:finai/features/tasks/domain/ports/task_dto.dart';
import 'package:finai/features/tasks/integration/fake_task_reader.dart';
import 'package:finai/features/tasks/integration/repository_task_reader.dart';

T success<T>(Result<T> result) => switch (result) {
  Success<T>(:final value) => value,
  Failure<T>() => throw StateError('Operation failed'),
};
void check(bool condition) {
  if (!condition) throw StateError('Contract mismatch');
}

DateTime at(int hour) => DateTime.utc(2044, 1, 2, hour);
Map<String, Object?> fields(TaskDto t) => {
  'id': t.id,
  'title': t.title,
  'description': t.description,
  'categoryId': t.categoryId,
  'startAt': t.startAt.toIso8601String(),
  'endAt': t.endAt.toIso8601String(),
  'priority': t.priority.name,
  'status': t.status.name,
  'createdAt': t.createdAt.toIso8601String(),
  'updatedAt': t.updatedAt.toIso8601String(),
};
bool same(List<TaskDto> actual, List<TaskDto> expected) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    final a = fields(actual[i]);
    final b = fields(expected[i]);
    if (a.keys.any((key) => a[key] != b[key])) return false;
  }
  return true;
}

Future<void> run(Uri base) async {
  if (base.scheme != 'http' ||
      base.host != '127.0.0.1' ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      (base.path.isNotEmpty && base.path != '/')) {
    throw ArgumentError('Only local TV3 demo is allowed');
  }
  final random = Random.secure();
  final nonce = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final marker = 'TV3 Reader probe $nonce ';
  final client = http.Client();
  final datasource = TaskRemoteDatasource(client: client, baseUrl: base);
  final repository = HttpTaskRepository(datasource: datasource);
  final reader = RepositoryTaskReader(repository: repository);
  final allQuery = TaskQuery(start: at(0), end: at(24), searchText: marker);
  final cleanupQuery = TaskQuery(start: at(0), end: at(24), searchText: marker);
  final created = <Task>[];
  final specs = <({String title, int start, int end, TaskPriority priority})>[
    (title: 'HỌC kế hoạch', start: 8, end: 13, priority: TaskPriority.medium),
    (title: 'Học Flutter A', start: 10, end: 12, priority: TaskPriority.high),
    (title: 'Học Flutter B', start: 10, end: 11, priority: TaskPriority.low),
    (
      title: r'Học 100%_\Flutter',
      start: 11,
      end: 12,
      priority: TaskPriority.medium,
    ),
    (title: 'Trước', start: 8, end: 9, priority: TaskPriority.medium),
    (title: 'Sau', start: 12, end: 13, priority: TaskPriority.medium),
  ];
  try {
    check(success(await reader.getTasks(allQuery)).isEmpty);
    for (final spec in specs) {
      created.add(
        success(
          await repository.create(
            TaskDraft(
              title: marker + spec.title,
              description: 'Fixture TaskReader demo',
              startAt: at(spec.start),
              endAt: at(spec.end),
              priority: spec.priority,
            ),
          ),
        ),
      );
    }
    created[0] = success(
      await repository.setStatus(created[0].id, TaskStatus.completed),
    );
    final fake = FakeTaskReader(fixtures: created.map(TaskDto.fromTask));
    final middle = [created[1], created[2]]
      ..sort((a, b) => a.id.compareTo(b.id));
    final ordered = [
      created[0],
      ...middle,
      created[3],
    ].map((t) => t.id).toList();
    final cases = <({String name, TaskQuery query, List<String> ids})>[
      (
        name: 'overlap + tie-break id',
        query: TaskQuery(start: at(9), end: at(12), searchText: marker),
        ids: ordered,
      ),
      (
        name: 'status',
        query: TaskQuery(
          start: at(9),
          end: at(12),
          searchText: marker,
          status: TaskStatus.completed,
        ),
        ids: [created[0].id],
      ),
      (
        name: 'priority',
        query: TaskQuery(
          start: at(9),
          end: at(12),
          searchText: marker,
          priority: TaskPriority.high,
        ),
        ids: [created[1].id],
      ),
      (
        name: 'trim + case insensitive',
        query: TaskQuery(
          start: at(9),
          end: at(12),
          searchText: '  ${marker.toUpperCase()}hỌc  ',
        ),
        ids: ordered,
      ),
      (
        name: 'accent sensitive',
        query: TaskQuery(start: at(9), end: at(12), searchText: '${marker}hoc'),
        ids: [],
      ),
      (
        name: 'literal percent underscore backslash',
        query: TaskQuery(
          start: at(9),
          end: at(12),
          searchText: marker + r'Học 100%_\',
        ),
        ids: [created[3].id],
      ),
      (
        name: 'AND',
        query: TaskQuery(
          start: at(9),
          end: at(12),
          searchText: '${marker}Học Flutter',
          status: TaskStatus.pending,
          priority: TaskPriority.high,
        ),
        ids: [created[1].id],
      ),
      (
        name: 'empty',
        query: TaskQuery(start: at(15), end: at(16), searchText: marker),
        ids: [],
      ),
      (
        name: 'timezone offset',
        query: TaskQuery(
          start: DateTime.parse('2044-01-02T16:00:00+07:00'),
          end: DateTime.parse('2044-01-02T19:00:00+07:00'),
          searchText: marker,
        ),
        ids: ordered,
      ),
    ];
    for (final scenario in cases) {
      final actual = success(await reader.getTasks(scenario.query));
      final simulated = success(await fake.getTasks(scenario.query));
      check(actual.map((t) => t.id).join(',') == scenario.ids.join(','));
      check(simulated.map((t) => t.id).join(',') == scenario.ids.join(','));
      check(same(actual, simulated));
      stdout.writeln('PASS: ${scenario.name}');
    }
    // Không dùng cache: đọc lại sau thay đổi thông qua repository.
    created[1] = success(
      await repository.setStatus(created[1].id, TaskStatus.completed),
    );
    final completed = success(
      await reader.getTasks(
        TaskQuery(
          start: at(9),
          end: at(12),
          searchText: marker,
          status: TaskStatus.completed,
        ),
      ),
    );
    check(completed.length == 2 && completed.last.id == created[1].id);
    stdout.writeln('PASS: fresh read after mutation');
  } finally {
    repository.dispose();
    try {
      // Quét marker ngẫu nhiên của lần thử để dọn cả trường hợp response tạo bị mất.
      final remaining = success(await datasource.list(cleanupQuery));
      for (final t in remaining.where((t) => t.title.startsWith(marker))) {
        success(await datasource.delete(t.id));
      }
      check(success(await datasource.list(cleanupQuery)).isEmpty);
      stdout.writeln('PASS: fixture cleanup verified');
    } finally {
      client.close();
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/check_task_reader.dart http://127.0.0.1:PORT',
    );
    exitCode = 64;
    return;
  }
  try {
    await run(Uri.parse(args.single));
    stdout.writeln('TASK_READER_REAL_RESULT: PASS');
  } catch (_) {
    stderr.writeln('TASK_READER_REAL_RESULT: FAIL (no raw data logged)');
    exitCode = 1;
  }
}
