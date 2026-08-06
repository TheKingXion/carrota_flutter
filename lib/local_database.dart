import "dart:convert";

import "package:path/path.dart" as path;
import "package:sqflite/sqflite.dart";

abstract class StatePersistence {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> state);
  Future<void> close();
}

class SqliteStatePersistence implements StatePersistence {
  static const databaseName = "carrota_local.db";
  static const databaseVersion = 1;

  Database? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;

    final databasePath = path.join(await getDatabasesPath(), databaseName);
    final database = await openDatabase(
      databasePath,
      version: databaseVersion,
      onCreate: (database, version) async {
        await database.execute("""
          CREATE TABLE app_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            schema_version INTEGER NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        """);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        // Las futuras migraciones se agregan aquí sin borrar datos locales.
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    final database = await _open();
    final rows = await database.query(
      "app_state",
      columns: ["payload"],
      where: "id = ?",
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final payload = rows.first["payload"];
    if (payload is! String || payload.isEmpty) return null;
    return jsonDecode(payload) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    final database = await _open();
    await database.transaction((transaction) async {
      await transaction.insert(
        "app_state",
        {
          "id": 1,
          "schema_version": databaseVersion,
          "payload": jsonEncode(state),
          "updated_at": DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}

class MemoryStatePersistence implements StatePersistence {
  Map<String, dynamic>? state;

  @override
  Future<Map<String, dynamic>?> load() async {
    final current = state;
    if (current == null) return null;
    return jsonDecode(jsonEncode(current)) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    this.state = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  }

  @override
  Future<void> close() async {}
}
