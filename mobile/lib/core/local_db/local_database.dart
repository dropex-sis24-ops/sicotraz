import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

/// Punto único de acceso a SQLite para el funcionamiento offline-first.
class LocalDatabase {
  LocalDatabase._();

  static Database? _instance;

  static Future<Database> get instance async {
    final existing = _instance;
    if (existing != null) return existing;

    final directory = await getDatabasesPath();
    final database = await openDatabase(
      '$directory/sicotraz.db',
      version: DatabaseSchema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        final batch = db.batch();
        for (final statement in DatabaseSchema.statements) {
          batch.execute(statement);
        }
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, from, _) async {
        if (from < 2) {
          await db.execute('ALTER TABLE usuario ADD COLUMN area_id INTEGER');
        }
        if (from < 3) {
          await db.execute(DatabaseSchema.statements[15]);
          await db.execute(DatabaseSchema.statements[16]);
        }
      },
    );

    _instance = database;
    return database;
  }

  static Future<void> close() async {
    final database = _instance;
    if (database == null) return;
    await database.close();
    _instance = null;
  }
}
