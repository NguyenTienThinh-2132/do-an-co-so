import '../core/cache/cache_database.dart';
import '../core/cache/sqlite_response_cache.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import '../app/theme/app_theme.dart';
import '../app/router/app_shell.dart';
import '../app/integration/finance_bindings.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../features/native_inbox/integration/android_tv3_bridge.dart';
import '../features/native_inbox/application/native_inbox_consumer.dart';
import '../features/native_inbox/domain/native_inbox_port.dart';
import '../features/native_inbox/presentation/native_inbox_page.dart';
import '../features/tasks/domain/ports/task_reminder_port.dart';
import '../features/tasks/application/task_reminder_editor_controller.dart';
import '../features/tasks/integration/reminder_task_repository.dart';
import '../features/tasks/integration/repository_task_reader.dart';
import '../features/assistant/application/assistant_controller.dart';
import '../features/assistant/data/fake_assistant_service.dart';
import '../features/assistant/presentation/assistant_page.dart';

import 'package:http/http.dart' as http;

import '../features/tasks/application/tasks_list_controller.dart';
import '../features/tasks/application/task_create_controller.dart';
import '../features/tasks/application/task_edit_controller.dart';
import '../features/tasks/application/task_details_controller.dart';
import '../features/tasks/application/task_status_controller.dart';
import '../features/tasks/application/task_delete_controller.dart';
import '../features/tasks/presentation/task_edit_page.dart';
import '../features/tasks/presentation/task_details_page.dart';
import '../features/tasks/domain/repositories/task_repository.dart';
import '../features/tasks/presentation/task_create_page.dart';
import '../features/tasks/data/datasources/task_remote_datasource.dart';
import '../features/tasks/data/repositories/http_task_repository.dart';
import '../features/tasks/domain/entities/task_query.dart';
import '../features/tasks/domain/entities/task_calendar_range.dart';
import '../features/tasks/presentation/tasks_day_page.dart';

void main() => runApp(const TasksDemoApp());

/// Chỉ router/composition root demo; không thay shell hoặc router của nhóm.
class TasksDemoApp extends StatefulWidget {
  const TasksDemoApp({super.key, this.repository, this.now, this.finance});
  final TaskRepository? repository;
  final FinanceBindings? finance;
  final DateTime Function()? now;
  @override
  State<TasksDemoApp> createState() => _TasksDemoAppState();
}

class _TasksDemoAppState extends State<TasksDemoApp>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _shell = GlobalKey<AppShellState>();
  final _calendarVersion = ValueNotifier<int>(0);
  NativeInboxConsumer? _inbox;
  NativeInboxPort? _nativePort;
  TaskReminderPort? _reminderPort;
  TaskReminderCoordinator? _reminders;
  http.Client? _client;
  TasksCalendarMode _mode = TasksCalendarMode.day;
  late DateTime _selectedDate;
  bool _focusWeekDay = false;
  HttpTaskRepository? _ownedRepository;
  CacheDatabase? _taskCacheDatabase;
  late final TaskRepository _repository;
  late final TasksListController _controller;
  late final TasksListController _dailyController;
  late final TaskCreateController _createController;
  late final TaskStatusController _statusController;
  late final TaskDeleteController _deleteController;

  @override
  void initState() {
    super.initState();
    final now = widget.now?.call() ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    _selectedDate = day;
    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      _client = http.Client();
      const url = String.fromEnvironment(
        'TASKS_API_BASE_URL',
        defaultValue: 'http://127.0.0.1:3000',
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _taskCacheDatabase = CacheDatabase.inDefaultDirectory();
      }
      const cacheScope = String.fromEnvironment(
        'TASKS_CACHE_SCOPE',
        defaultValue: 'finai-native18-v1',
      );
      final endpoint = url.replaceFirst(RegExp(r'/+$'), '');
      _ownedRepository = HttpTaskRepository(
        cache: _taskCacheDatabase == null
            ? null
            : SqliteResponseCache(database: _taskCacheDatabase!),
        cacheNamespace: '$cacheScope|$endpoint|tasks-list-v1',
        datasource: TaskRemoteDatasource(
          client: _client!,
          baseUrl: Uri.parse(url),
        ),
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        const native = AndroidTV3Bridge();
        _nativePort = native;
        _reminderPort = native;
        _reminders = TaskReminderCoordinator(port: native);
        _repository = ReminderTaskRepository(
          delegate: _ownedRepository!,
          reminders: _reminders!,
        );
        _inbox = NativeInboxConsumer(
          port: native,
          handle: (event) async {
            if (event.kind != 'taskOpen') return false;
            final id = event.data['taskId'];
            if (id is! String ||
                id.isEmpty ||
                _navigator.currentState == null) {
              return false;
            }
            _shell.currentState?.selectTab(3);
            unawaited(
              _navigator.currentState!.pushNamed<void>(
                Uri(pathSegments: ['', 'tasks', id]).toString(),
              ),
            );
            return true;
          },
        );
        WidgetsBinding.instance.addObserver(this);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inbox?.start();
        });
      } else {
        _repository = _ownedRepository!;
      }
    }
    final query = TaskQuery(
      start: day,
      end: DateTime(day.year, day.month, day.day + 1),
    );
    _createController = TaskCreateController(repository: _repository);
    _statusController = TaskStatusController(repository: _repository);
    _deleteController = TaskDeleteController(repository: _repository);
    _dailyController = TasksListController(
      repository: _repository,
      query: query,
    )..load();
    _controller = TasksListController(repository: _repository, query: query);
    _controller.addListener(_syncDailyQuery);
    _controller.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ownedRepository?.refresh();
      unawaited(_inbox?.recover());
    }
  }

  void _calendar({
    DateTime? date,
    TasksCalendarMode? mode,
    bool focus = false,
  }) {
    setState(() {
      _selectedDate = date ?? _selectedDate;
      _mode = mode ?? _mode;
      _focusWeekDay = focus;
    });
    _calendarVersion.value++;
    _controller.setQuery(
      TaskCalendarRange(
        _selectedDate,
        _mode,
      ).queryLike(_controller.state.query),
    );
  }

  void _syncDailyQuery() {
    final selected = _controller.state.query;
    final daily = _dailyController.state.query;
    if (daily.start == selected.start && daily.end == selected.end) return;
    _dailyController.setQuery(
      TaskQuery(start: selected.start, end: selected.end),
    );
  }

  Widget _tasksPage(BuildContext context) => TasksDayPage(
    controller: _controller,
    mode: _mode,
    selectedDate: _selectedDate,
    focusWeekDay: _focusWeekDay,
    onShowWholeWeek: () => _calendar(),
    onModeChanged: (mode) => _calendar(mode: mode),
    onDateSelected: (date) => _calendar(date: date, focus: true),
    onPrevious: () =>
        _calendar(date: TaskCalendarRange.shift(_selectedDate, _mode, -1)),
    onNext: () =>
        _calendar(date: TaskCalendarRange.shift(_selectedDate, _mode, 1)),
    dailyController: _dailyController,
    statusController: _statusController,
    deleteController: _deleteController,
    now: widget.now,
    onAssistant: () {
      if (widget.finance != null) {
        _shell.currentState?.selectTab(2);
      } else {
        Navigator.pushNamed(context, '/assistant');
      }
    },
    onInbox: () => Navigator.pushNamed(context, '/native-inbox'),
    reminderChanges: _reminders,
    hasReminderWarning: () => _reminders?.hasWarnings ?? false,
    retryReminderSync: () => unawaited(_reminders?.retryAll()),
    onCreate: () => Navigator.pushNamed(context, '/tasks/new'),
    onEdit: (id) => Navigator.pushNamed(
      context,
      Uri(pathSegments: ['', 'tasks', id, 'edit']).toString(),
    ),
    onOpen: (id) => Navigator.pushNamed(
      context,
      Uri(pathSegments: ['', 'tasks', id]).toString(),
    ),
  );

  Route<void> _route(RouteSettings settings) {
    final parts = Uri.tryParse(settings.name ?? '/tasks')?.pathSegments;
    WidgetBuilder builder;
    if (parts != null && parts.isEmpty && widget.finance != null) {
      builder = (_) => AppShell(
        key: _shell,
        dashboardReader: widget.finance!.dashboardReader,
        expenseWriter: widget.finance!.expenseWriter,
        jarRepository: widget.finance!.jars,
        clock: widget.now,
        tasksBuilder: (context) => ValueListenableBuilder(
          valueListenable: _calendarVersion,
          builder: (context, _, _) => _tasksPage(context),
        ),
        assistantBuilder: (_) => ValueListenableBuilder(
          valueListenable: _calendarVersion,
          builder: (_, _, _) => _AssistantRoute(
            repository: _repository,
            query: TaskCalendarRange(_selectedDate, _mode).queryLike(
              TaskQuery(
                start: _controller.state.query.start,
                end: _controller.state.query.end,
              ),
            ),
          ),
        ),
      );
    } else if (parts != null &&
        (parts.isEmpty || (parts.length == 1 && parts.first == 'tasks'))) {
      builder = (context) => ValueListenableBuilder(
        valueListenable: _calendarVersion,
        builder: (context, _, _) => _tasksPage(context),
      );
    } else if (parts != null &&
        parts.length == 1 &&
        parts[0] == 'native-inbox') {
      builder = (_) =>
          NativeInboxPage(port: _nativePort, permissions: _reminderPort);
    } else if (parts != null && parts.length == 1 && parts[0] == 'assistant') {
      builder = (_) => _AssistantRoute(
        repository: _repository,
        query: TaskCalendarRange(_selectedDate, _mode).queryLike(
          TaskQuery(
            start: _controller.state.query.start,
            end: _controller.state.query.end,
          ),
        ),
      );
    } else if (parts != null &&
        parts.length == 2 &&
        parts[0] == 'tasks' &&
        parts[1] == 'new') {
      _createController.reset();
      builder = (_) => TaskCreatePage(
        controller: _createController,
        reminderPort: _reminderPort,
        initialDay: _selectedDate,
      );
    } else if (parts != null && parts.length == 2 && parts[0] == 'tasks') {
      builder = (_) => _RecordRoute(
        repository: _repository,
        taskId: parts[1],
        edit: false,
        reminderPort: _reminderPort,
      );
    } else if (parts != null &&
        parts.length == 3 &&
        parts[0] == 'tasks' &&
        parts[2] == 'edit') {
      builder = (_) =>
          _RecordRoute(repository: _repository, taskId: parts[1], edit: true);
    } else {
      builder = (context) => Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy màn hình')),
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/tasks',
              (_) => false,
            ),
            child: const Text('Trở về Công việc'),
          ),
        ),
      );
    }
    return MaterialPageRoute<void>(settings: settings, builder: builder);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncDailyQuery);
    _controller.dispose();
    _dailyController.dispose();
    _createController.dispose();
    _statusController.dispose();
    _deleteController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _inbox?.dispose();
    _reminders?.dispose();
    _ownedRepository?.dispose();
    final cacheDatabase = _taskCacheDatabase;
    if (cacheDatabase != null) {
      unawaited(
        (_ownedRepository?.cacheSettled ?? Future<void>.value())
            .then((_) => cacheDatabase.close())
            .catchError((Object _) {}),
      );
    }
    _client?.close();
    _calendarVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: _navigator,
    localizationsDelegates: widget.finance == null
        ? null
        : GlobalMaterialLocalizations.delegates,
    supportedLocales: widget.finance == null
        ? const [Locale('en')]
        : const [Locale('vi'), Locale('en')],
    locale: widget.finance == null ? null : const Locale('vi'),
    theme: widget.finance != null
        ? AppTheme.light
        : ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
            ),
          ),
    onGenerateRoute: _route,
    onGenerateInitialRoutes: (name) => [
      _route(RouteSettings(name: widget.finance == null ? '/tasks' : '/')),
      if (name != '/' && (widget.finance != null || name != '/tasks'))
        _route(RouteSettings(name: name)),
    ],
  );
}

class _RecordRoute extends StatefulWidget {
  const _RecordRoute({
    required this.repository,
    required this.taskId,
    required this.edit,
    this.reminderPort,
  });
  final TaskRepository repository;
  final String taskId;
  final bool edit;
  final TaskReminderPort? reminderPort;
  @override
  State<_RecordRoute> createState() => _RecordRouteState();
}

class _RecordRouteState extends State<_RecordRoute> {
  TaskEditController? _editor;
  TaskDetailsController? _details;
  TaskReminderEditorController? _reminderEditor;
  @override
  void initState() {
    super.initState();
    if (widget.edit) {
      _editor = TaskEditController(
        repository: widget.repository,
        taskId: widget.taskId,
      )..load();
    } else {
      _details = TaskDetailsController(
        repository: widget.repository,
        taskId: widget.taskId,
      );
      _details!.addListener(_syncReminder);
      _details!.load();
    }
  }

  void _syncReminder() {
    final task = _details?.task;
    if (task == null || !mounted) return;
    _reminderEditor ??= TaskReminderEditorController(
      port: widget.reminderPort,
      initialAt: task.startAt,
    );
    unawaited(_reminderEditor!.load(task.id, task.startAt));
    setState(() {});
  }

  Future<void> _edit() async {
    await Navigator.pushNamed(
      context,
      Uri(pathSegments: ['', 'tasks', widget.taskId, 'edit']).toString(),
    );
    if (mounted) await _details!.load();
  }

  @override
  void dispose() {
    _editor?.dispose();
    _details?.removeListener(_syncReminder);
    _details?.dispose();
    _reminderEditor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.edit
      ? TaskEditPage(controller: _editor!)
      : TaskDetailsPage(
          controller: _details!,
          onEdit: _edit,
          reminderController: _reminderEditor,
        );
}

class _AssistantRoute extends StatefulWidget {
  const _AssistantRoute({required this.repository, required this.query});
  final TaskRepository repository;
  final TaskQuery query;
  @override
  State<_AssistantRoute> createState() => _AssistantRouteState();
}

class _AssistantRouteState extends State<_AssistantRoute> {
  late final AssistantController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AssistantController(
      service: FakeAssistantService(
        tasks: RepositoryTaskReader(repository: widget.repository),
      ),
      query: widget.query,
    );
  }

  @override
  void didUpdateWidget(covariant _AssistantRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updateQuery(widget.query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AssistantPage(controller: _controller);
}
