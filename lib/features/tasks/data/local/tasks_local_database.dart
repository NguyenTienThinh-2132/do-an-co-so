import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Feature-owned database: task projection and outbox commit together.
/// It never opens finai_read_cache.db or the Native Inbox database.
class TasksLocalDatabase {
  TasksLocalDatabase({required String directory, DatabaseFactory? factory})
    : path = p.join(directory, fileName),
      _factory = factory ?? databaseFactory;
  TasksLocalDatabase.inDefaultDirectory({DatabaseFactory? factory})
    : path = fileName,
      _factory = factory ?? databaseFactory;
  static const fileName = 'finai_tasks_local.db';
  static const version = 1;
  final String path;
  final DatabaseFactory _factory;
  Future<Database>? _opening;
  Future<void>? _closing;
  bool _closed = false;
  Future<Database> get connection {
    if (_closed) return Future.error(StateError('Tasks database is closed.'));
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE tasks_local (
            namespace TEXT NOT NULL CHECK (length(trim(namespace)) > 0),
            task_id TEXT NOT NULL,
            local_json TEXT NOT NULL,
            local_deleted INTEGER NOT NULL DEFAULT 0 CHECK (local_deleted IN (0,1)),
            server_json TEXT,
            server_version INTEGER CHECK (server_version > 0),
            server_deleted INTEGER NOT NULL DEFAULT 0 CHECK (server_deleted IN (0,1)),
            PRIMARY KEY (namespace, task_id),
            CHECK ((server_version IS NULL AND server_json IS NULL AND server_deleted=0)
              OR (server_version IS NOT NULL AND (
                (server_deleted=0 AND server_json IS NOT NULL)
                OR (server_deleted=1 AND server_json IS NULL))))
          )''');
            await db.execute('''CREATE TABLE task_outbox (
            sequence INTEGER PRIMARY KEY AUTOINCREMENT,
            namespace TEXT NOT NULL,
            operation_id TEXT NOT NULL,
            task_id TEXT NOT NULL,
            kind TEXT NOT NULL CHECK (kind IN ('create','update','setStatus','delete')),
            operation_json TEXT NOT NULL,
            base_version INTEGER CHECK (base_version > 0),
            depends_on_operation_id TEXT,
            queued_at_ms INTEGER NOT NULL,
            state TEXT NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','sending','synced','conflict','failed')),
            attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
            frozen_request_json TEXT,
            last_failure_code TEXT CHECK (last_failure_code IN ('validation','notFound','conflict','permissionDenied','unavailable')),
            next_retry_at_ms INTEGER,
            ack_version INTEGER CHECK (ack_version > 0),
            ack_response_json TEXT,
            UNIQUE (namespace, operation_id),
            FOREIGN KEY (namespace, task_id) REFERENCES tasks_local(namespace, task_id) ON DELETE RESTRICT,
            FOREIGN KEY (namespace, depends_on_operation_id) REFERENCES task_outbox(namespace, operation_id) ON DELETE RESTRICT,
            CHECK (operation_id <> depends_on_operation_id),
            CHECK ((kind='create' AND base_version IS NULL AND depends_on_operation_id IS NULL)
              OR (kind<>'create' AND (
                (base_version IS NOT NULL AND depends_on_operation_id IS NULL)
                OR (base_version IS NULL AND depends_on_operation_id IS NOT NULL)))),
            CHECK (state <> 'sending' OR (attempt_count >= 1 AND frozen_request_json IS NOT NULL)),
            CHECK (state <> 'synced' OR (ack_version IS NOT NULL AND ack_response_json IS NOT NULL))
          )''');
            await db.execute(
              'CREATE INDEX task_outbox_task_order ON task_outbox(namespace, task_id, sequence)',
            );
            await db.execute(
              'CREATE INDEX task_outbox_pending ON task_outbox(namespace, state, sequence)',
            );
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    if (_opening == null) return;
    Database db;
    try {
      db = await _opening!;
    } catch (_) {
      return;
    }
    await db.close();
  }
}
