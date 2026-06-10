import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and creates on first run) the Lifegrid SQLite database.
///
/// Schema = metadata + EAV (see docs/IMPLEMENTATION_PLAN.md §2):
///   models -> fields -> records -> values
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'lifegrid.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE models (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        position   INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE fields (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        model_id   INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
        name       TEXT    NOT NULL,
        type       TEXT    NOT NULL,
        position   INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE records (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        model_id   INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE field_values (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL REFERENCES records(id) ON DELETE CASCADE,
        field_id  INTEGER NOT NULL REFERENCES fields(id)  ON DELETE CASCADE,
        value     TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_fields_model  ON fields(model_id)');
    await db.execute('CREATE INDEX idx_records_model ON records(model_id)');
    await db.execute('CREATE INDEX idx_values_record ON field_values(record_id)');
    await db.execute('CREATE INDEX idx_values_field  ON field_values(field_id)');
  }
}
