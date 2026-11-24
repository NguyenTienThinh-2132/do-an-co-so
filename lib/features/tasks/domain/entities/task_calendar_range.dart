import 'task.dart';
import 'task_query.dart';

enum TasksCalendarMode { day, week, month }

class TaskCalendarRange {
  TaskCalendarRange(DateTime anchor, TasksCalendarMode mode) {
    final d = anchor.toLocal();
    start = switch (mode) {
      TasksCalendarMode.day => DateTime(d.year, d.month, d.day),
      TasksCalendarMode.week => DateTime(
        d.year,
        d.month,
        d.day - d.weekday + 1,
      ),
      TasksCalendarMode.month => DateTime(d.year, d.month),
    };
    end = switch (mode) {
      TasksCalendarMode.day => DateTime(start.year, start.month, start.day + 1),
      TasksCalendarMode.week => DateTime(
        start.year,
        start.month,
        start.day + 7,
      ),
      TasksCalendarMode.month => DateTime(start.year, start.month + 1),
    };
  }
  late final DateTime start;
  late final DateTime end;
  List<DateTime> get days {
    final result = <DateTime>[];
    for (
      var day = start;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      result.add(day);
    }
    return List.unmodifiable(result);
  }

  TaskQuery queryLike(TaskQuery query) => TaskQuery(
    start: start,
    end: end,
    status: query.status,
    priority: query.priority,
    searchText: query.searchText,
  );

  static bool overlapsDay(Task task, DateTime date) =>
      task.startAt.isBefore(
        DateTime(date.year, date.month, date.day + 1).toUtc(),
      ) &&
      task.endAt.isAfter(DateTime(date.year, date.month, date.day).toUtc());

  static DateTime shift(
    DateTime anchor,
    TasksCalendarMode mode,
    int direction,
  ) {
    final d = anchor.toLocal();
    if (mode == TasksCalendarMode.month) {
      final first = DateTime(d.year, d.month + direction);
      final last = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(first.year, first.month, d.day > last ? last : d.day);
    }
    return DateTime(
      d.year,
      d.month,
      d.day + direction * (mode == TasksCalendarMode.week ? 7 : 1),
    );
  }
}
