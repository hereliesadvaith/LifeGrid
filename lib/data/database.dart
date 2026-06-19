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
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
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
    await _createCharts(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCharts(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE charts ADD COLUMN date_filter TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE charts ADD COLUMN date_field INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE charts ADD COLUMN sum_field INTEGER');
    }
    if (oldVersion < 6) {
      // To-do chart config. SET NULL isn't expressible via ALTER ADD COLUMN in
      // SQLite, so these added columns carry no FK action; deletes are guarded
      // in the UI (the render path treats a missing field as "deleted").
      await db.execute('ALTER TABLE charts ADD COLUMN label_field INTEGER');
      await db.execute('ALTER TABLE charts ADD COLUMN done_field INTEGER');
      await db.execute('ALTER TABLE charts ADD COLUMN tag_field INTEGER');
    }
  }

  /// Dashboard charts — descriptors over an existing model (see plan §2).
  /// `group_field` is SET NULL (not CASCADE) so a chart survives a deleted field
  /// and can show an "invalid field" note instead of vanishing silently.
  Future<void> _createCharts(Database db) async {
    await db.execute('''
      CREATE TABLE charts (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        model_id    INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
        type        TEXT    NOT NULL,
        group_field INTEGER REFERENCES fields(id) ON DELETE SET NULL,
        style       TEXT,
        title       TEXT    NOT NULL,
        position    INTEGER NOT NULL,
        created_at  INTEGER NOT NULL,
        date_filter TEXT,
        date_field  INTEGER REFERENCES fields(id) ON DELETE SET NULL,
        sum_field   INTEGER REFERENCES fields(id) ON DELETE SET NULL,
        label_field INTEGER REFERENCES fields(id) ON DELETE SET NULL,
        done_field  INTEGER REFERENCES fields(id) ON DELETE SET NULL,
        tag_field   INTEGER REFERENCES fields(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_charts_model ON charts(model_id)');
  }
}
