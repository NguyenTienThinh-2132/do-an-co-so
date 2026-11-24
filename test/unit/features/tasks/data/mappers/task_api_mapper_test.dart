import 'package:finai/features/tasks/data/mappers/task_api_mapper.dart';
import 'package:finai/features/tasks/domain/entities/task_draft.dart';
import 'package:finai/features/tasks/domain/entities/task_priority.dart';
import 'package:finai/features/tasks/domain/entities/task_query.dart';
import 'package:finai/features/tasks/domain/entities/task_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> fixture() => {
    'id': '850ca704-a7e5-437e-a206-0c42af3bf22d',
    'title': 'Viết báo cáo',
    'description': null,
    'categoryId': null,
    'startAt': '2026-11-07T02:00:00.000Z',
    'endAt': '2026-11-07T03:00:00.000Z',
    'priority': 'medium',
    'status': 'pending',
    'createdAt': '2026-11-06T10:00:00.000Z',
    'updatedAt': '2026-11-06T10:00:00.000Z',
  };

  test('Đọc response backend, enum và UTC', () {
    final task = TaskApiMapper.fromJson(fixture());
    expect(task.title, 'Viết báo cáo');
    expect(task.id, fixture()['id']);
    expect(task.description, isNull);
    expect(task.categoryId, isNull);
    expect(task.priority, TaskPriority.medium);
    expect(task.status, TaskStatus.pending);
    expect(task.startAt, DateTime.utc(2026, 11, 7, 2));
    for (final time in [
      task.startAt,
      task.endAt,
      task.createdAt,
      task.updatedAt,
    ]) {
      expect(time.isUtc, isTrue);
    }
  });

  test('Đọc trường nullable bị bỏ qua và trường API bổ sung', () {
    final json = fixture()
      ..remove('description')
      ..remove('categoryId');
    json['futureField'] = 'ignored';
    final task = TaskApiMapper.fromJson(json);
    expect(task.description, isNull);
    expect(task.categoryId, isNull);
  });

  test(
    'Version backend là trường bổ sung, Flutter Task hiện có vẫn đọc được',
    () {
      final task = TaskApiMapper.fromJson({...fixture(), 'version': 7});
      expect(task.id, fixture()['id']);
      expect(task.title, fixture()['title']);
      expect(task.status, TaskStatus.pending);
      expect(task.startAt, DateTime.utc(2026, 11, 7, 2));
    },
  );

  test('Giữ nội dung description và categoryId', () {
    final task = TaskApiMapper.fromJson(
      fixture()
        ..['description'] = 'Báo cáo TV3'
        ..['categoryId'] = 'study',
    );
    expect(task.description, 'Báo cáo TV3');
    expect(task.categoryId, 'study');
  });

  test('Chuyển offset thành đúng thời điểm UTC', () {
    final task = TaskApiMapper.fromJson(
      fixture()
        ..['startAt'] = '2026-11-07T09:00:00+07:00'
        ..['endAt'] = '2026-11-07T10:00:00+07:00',
    );
    expect(task.startAt, DateTime.utc(2026, 11, 7, 2));
    expect(task.endAt, DateTime.utc(2026, 11, 7, 3));
  });

  test('Hỗ trợ đầy đủ các enum đã chốt', () {
    for (final priority in TaskPriority.values) {
      for (final status in TaskStatus.values) {
        final task = TaskApiMapper.fromJson(
          fixture()
            ..['priority'] = priority.name
            ..['status'] = status.name,
        );
        expect(task.priority, priority);
        expect(task.status, status);
      }
    }
  });

  test('Từ chối root không phải JSON object', () {
    for (final input in [null, [], 'text', 1]) {
      expect(() => TaskApiMapper.fromJson(input), throwsFormatException);
    }
  });

  for (final field in [
    'id',
    'title',
    'startAt',
    'endAt',
    'priority',
    'status',
    'createdAt',
    'updatedAt',
  ]) {
    test('Thiếu/sai kiểu trường $field trả FormatException', () {
      expect(
        () => TaskApiMapper.fromJson(fixture()..remove(field)),
        throwsFormatException,
      );
      expect(
        () => TaskApiMapper.fromJson(fixture()..[field] = 123),
        throwsFormatException,
      );
    });
  }

  test('Không tự chọn enum mặc định khi response sai', () {
    for (final change in [
      {'priority': 'urgent'},
      {'status': 'overdue'},
      {'status': 'in_progress'},
    ]) {
      expect(
        () => TaskApiMapper.fromJson({...fixture(), ...change}),
        throwsFormatException,
      );
    }
  });

  test('Từ chối nullable sai kiểu', () {
    for (final field in ['description', 'categoryId']) {
      expect(
        () => TaskApiMapper.fromJson(fixture()..[field] = []),
        throwsFormatException,
      );
    }
  });

  test('Không chuẩn hóa ngầm ngày giờ sai hoặc thiếu múi giờ', () {
    for (final timestamp in [
      '2026-02-30T02:00:00Z',
      '2025-02-29T02:00:00Z',
      '2026-13-01T02:00:00Z',
      '2026-11-07T24:00:00Z',
      '2026-11-07T02:60:00Z',
      '2026-11-07T02:00:60Z',
      '2026-11-07T02:00:00+24:00',
      '2026-11-07T02:00:00+07:60',
      '2026-11-07T02:00:00',
      '2026-11-07',
      'not-a-date',
    ]) {
      expect(
        () => TaskApiMapper.fromJson(fixture()..['startAt'] = timestamp),
        throwsFormatException,
      );
    }
  });

  test('Bảo vệ quy tắc tên và end sau start của domain', () {
    for (final change in [
      {'title': '  '},
      {'endAt': fixture()['startAt']},
      {'endAt': '2026-11-07T01:00:00Z'},
    ]) {
      expect(
        () => TaskApiMapper.fromJson({...fixture(), ...change}),
        throwsFormatException,
      );
    }
  });

  test('Đọc danh sách và danh sách rỗng; không bỏ qua bản ghi hỏng', () {
    expect(TaskApiMapper.listFromJson([]), isEmpty);
    final tasks = TaskApiMapper.listFromJson([
      fixture(),
      fixture()..['id'] = 'second',
    ]);
    expect(tasks.map((task) => task.id), [fixture()['id'], 'second']);
    expect(() => TaskApiMapper.listFromJson({}), throwsFormatException);
    expect(
      () => TaskApiMapper.listFromJson([fixture(), null]),
      throwsFormatException,
    );
  });

  test('Draft chỉ gửi nội dung hợp đồng, enum và thời gian UTC', () {
    final payload = TaskApiMapper.draftToJson(
      TaskDraft(
        title: '  Báo cáo  ',
        description: 'TV3',
        categoryId: 'study',
        startAt: DateTime.parse('2026-11-07T09:00:00+07:00'),
        endAt: DateTime.parse('2026-11-07T10:00:00+07:00'),
        priority: TaskPriority.high,
      ),
    );
    expect(payload, {
      'title': 'Báo cáo',
      'description': 'TV3',
      'categoryId': 'study',
      'startAt': '2026-11-07T02:00:00.000Z',
      'endAt': '2026-11-07T03:00:00.000Z',
      'priority': 'high',
    });
  });

  test('Draft nullable được gửi null để PUT thay nội dung đúng', () {
    final payload = TaskApiMapper.draftToJson(
      TaskDraft(
        title: 'Báo cáo',
        startAt: DateTime.utc(2026, 11, 7, 2),
        endAt: DateTime.utc(2026, 11, 7, 3),
      ),
    );
    expect(payload['description'], isNull);
    expect(payload['categoryId'], isNull);
    expect(payload['priority'], 'medium');
    expect(payload.keys, isNot(contains('status')));
    expect(payload.keys, isNot(contains('id')));
    expect(payload.keys, isNot(contains('createdAt')));
    expect(payload.keys, isNot(contains('updatedAt')));
  });

  test('Query không gửi bộ lọc bỏ trống', () {
    expect(
      TaskApiMapper.queryToParameters(
        TaskQuery(
          start: DateTime.utc(2026, 11, 6, 17),
          end: DateTime.utc(2026, 11, 7, 17),
        ),
      ),
      {'start': '2026-11-06T17:00:00.000Z', 'end': '2026-11-07T17:00:00.000Z'},
    );
  });

  test('Query giữ toàn bộ bộ lọc và ký tự tìm kiếm qua Uri', () {
    final parameters = TaskApiMapper.queryToParameters(
      TaskQuery(
        start: DateTime.utc(2026, 11, 6, 17),
        end: DateTime.utc(2026, 11, 7, 17),
        status: TaskStatus.inProgress,
        priority: TaskPriority.low,
        searchText: '  báo cáo %_&+?  ',
      ),
    );
    expect(parameters['status'], 'inProgress');
    expect(parameters['priority'], 'low');
    expect(parameters['searchText'], 'báo cáo %_&+?');
    final uri = Uri.https('example.test', '/tasks', parameters);
    expect(uri.queryParameters['searchText'], 'báo cáo %_&+?');
  });
}
