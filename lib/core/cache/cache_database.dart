import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns a separate cache DB, never opens Native Inbox or a finance ledger.
/// The composition root creates one instance and closes it at the end.
class CacheDatabase {
  CacheDatabase({required String directory, DatabaseFactory? factory})
    : path = p.join(directory, fileName),
      _factory = factory ?? databaseFactory;

  /// A relative filename is resolved by sqflite inside the app database folder.
  /// Opening stays lazy, so the composition root needs no asynchronous UI bootstrap.
  CacheDatabase.inDefaultDirectory({DatabaseFactory? factory})
    : path = fileName,
      _factory = factory ?? databaseFactory;

  static const fileName = 'finai_read_cache.db';
  static const table = 'cache_entries';
  static const databaseVersion = 1;
  final String path;
  final DatabaseFactory _factory;
  Future<Database>? _opening;
  Future<void>? _closing;
  bool _closed = false;

  static Future<CacheDatabase> atDefaultLocation() async =>
      CacheDatabase(directory: await getDatabasesPath());

  Future<Database> get connection {
    if (_closed) return Future.error(StateError('Cache database is closed.'));
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          singleInstance: false,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE cache_entries (
            namespace TEXT NOT NULL,
            resource TEXT NOT NULL,
            query_key TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            saved_at_ms INTEGER NOT NULL,
            schema_version INTEGER NOT NULL CHECK (schema_version > 0),
            PRIMARY KEY (namespace, resource, query_key)
          )''');
          },
        ),
      );
    } catch (_) {
      _opening = null; // A later read can retry after an open failure.
      rethrow;
    }
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    final opening = _opening;
    if (opening == null) return;
    Database db;
    try {
      db = await opening;
    } catch (_) {
      return;
    }
    await db.close();
  }
}
