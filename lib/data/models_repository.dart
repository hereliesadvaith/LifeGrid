import 'package:sqflite/sqflite.dart';

import '../models/app_model.dart';
import '../models/chart_def.dart';
import '../models/field_def.dart';
import '../models/record_entry.dart';
import 'database.dart';
import 'field_type.dart';

/// Thrown when a schema mutation is attempted on a model that already has records.
class SchemaLockedException implements Exception {
  const SchemaLockedException();
  @override
  String toString() =>
      'Schema is locked — delete all records to change fields.';
}

/// All persistence for models, fields, records and values.
class ModelsRepository {
  ModelsRepository({AppDatabase? db}) : _appDb = db ?? AppDatabase.instance;

  final AppDatabase _appDb;

  Future<Database> get _db => _appDb.database;

  // ---------------------------------------------------------------- models ---

  /// Load every model with its fields and a record count, ordered by position.
  Future<List<AppModel>> loadModels() async {
    final db = await _db;
    final modelRows = await db.query('models', orderBy: 'position ASC, id ASC');
    final out = <AppModel>[];
    for (final m in modelRows) {
      final id = m['id'] as int;
      final fieldRows = await db.query(
        'fields',
        where: 'model_id = ?',
        whereArgs: [id],
        orderBy: 'position ASC, id ASC',
      );
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM records WHERE model_id = ?',
        [id],
      );
      out.add(AppModel(
        id: id,
        name: m['name'] as String,
        position: m['position'] as int,
        fields: fieldRows.map(FieldDef.fromMap).toList(),
        recordCount: Sqflite.firstIntValue(countRows) ?? 0,
      ));
    }
    return out;
  }

  Future<int> createModel(String name) async {
    final db = await _db;
    final posRows =
        await db.rawQuery('SELECT COALESCE(MAX(position), -1) + 1 AS p FROM models');
    final position = Sqflite.firstIntValue(posRows) ?? 0;
    return db.insert('models', {
      'name': name,
      'position': position,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteModel(int modelId) async {
    final db = await _db;
    // FK ON DELETE CASCADE removes fields, records and values.
    await db.delete('models', where: 'id = ?', whereArgs: [modelId]);
  }

  // ---------------------------------------------------------------- fields ---

  Future<void> addField(int modelId, String name, FieldType type) async {
    final db = await _db;
    await _assertUnlocked(db, modelId);
    final posRows = await db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS p FROM fields WHERE model_id = ?',
      [modelId],
    );
    await db.insert('fields', {
      'model_id': modelId,
      'name': name,
      'type': type.code,
      'position': Sqflite.firstIntValue(posRows) ?? 0,
    });
  }

  Future<void> renameField(int modelId, int fieldId, String name) async {
    final db = await _db;
    await _assertUnlocked(db, modelId);
    await db.update('fields', {'name': name},
        where: 'id = ?', whereArgs: [fieldId]);
  }

  Future<void> deleteField(int modelId, int fieldId) async {
    final db = await _db;
    await _assertUnlocked(db, modelId);
    await db.delete('fields', where: 'id = ?', whereArgs: [fieldId]);
  }

  /// Schema-lock guard (plan §7.2): mutations rejected once any record exists.
  Future<void> _assertUnlocked(Database db, int modelId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM records WHERE model_id = ?',
      [modelId],
    );
    if ((Sqflite.firstIntValue(rows) ?? 0) > 0) {
      throw const SchemaLockedException();
    }
  }

  // --------------------------------------------------------------- records ---

  Future<List<RecordEntry>> loadRecords(int modelId) async {
    final db = await _db;
    final recRows = await db.query(
      'records',
      where: 'model_id = ?',
      whereArgs: [modelId],
      orderBy: 'id ASC',
    );
    if (recRows.isEmpty) return [];

    final fieldRows = await db.query('fields',
        where: 'model_id = ?', whereArgs: [modelId]);
    final typeByField = {
      for (final f in fieldRows)
        f['id'] as int: FieldType.fromCode(f['type'] as String)
    };

    final ids = recRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final valRows = await db.rawQuery(
      'SELECT record_id, field_id, value FROM field_values '
      'WHERE record_id IN ($placeholders)',
      ids,
    );
    final valuesByRecord = <int, Map<int, Object?>>{};
    for (final v in valRows) {
      final rid = v['record_id'] as int;
      final fid = v['field_id'] as int;
      final type = typeByField[fid];
      if (type == null) continue; // field deleted (shouldn't happen under lock)
      (valuesByRecord[rid] ??= {})[fid] = type.decode(v['value'] as String?);
    }

    return recRows
        .map((r) => RecordEntry(
              id: r['id'] as int,
              modelId: modelId,
              values: valuesByRecord[r['id'] as int] ?? {},
              createdAt: r['created_at'] as int,
              updatedAt: r['updated_at'] as int,
            ))
        .toList();
  }

  /// Insert a record. [values] maps field id -> typed Dart value.
  Future<int> addRecord(
    int modelId,
    List<FieldDef> fields,
    Map<int, Object?> values,
  ) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      final recordId = await txn.insert('records', {
        'model_id': modelId,
        'created_at': now,
        'updated_at': now,
      });
      await _writeValues(txn, recordId, fields, values);
      return recordId;
    });
  }

  /// Replace all values on an existing record (used by the edit form).
  Future<void> updateRecord(
    int recordId,
    List<FieldDef> fields,
    Map<int, Object?> values,
  ) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('field_values',
          where: 'record_id = ?', whereArgs: [recordId]);
      await _writeValues(txn, recordId, fields, values);
      await txn.update('records', {'updated_at': now},
          where: 'id = ?', whereArgs: [recordId]);
    });
  }

  Future<void> deleteRecord(int recordId) async {
    final db = await _db;
    await db.delete('records', where: 'id = ?', whereArgs: [recordId]);
  }

  Future<void> _writeValues(
    Transaction txn,
    int recordId,
    List<FieldDef> fields,
    Map<int, Object?> values,
  ) async {
    for (final f in fields) {
      final encoded = f.type.encode(values[f.id]);
      if (encoded == null) continue; // store nothing for empty/unset
      await txn.insert('field_values', {
        'record_id': recordId,
        'field_id': f.id,
        'value': encoded,
      });
    }
  }

  // ---------------------------------------------------------------- charts ---

  Future<List<ChartDef>> loadCharts() async {
    final db = await _db;
    final rows = await db.query('charts', orderBy: 'position ASC, id ASC');
    return rows.map(ChartDef.fromMap).toList();
  }

  Future<int> createChart({
    required int modelId,
    required ChartType type,
    required int groupFieldId,
    required PieStyle style,
    required String title,
  }) async {
    final db = await _db;
    final posRows = await db
        .rawQuery('SELECT COALESCE(MAX(position), -1) + 1 AS p FROM charts');
    return db.insert('charts', {
      'model_id': modelId,
      'type': type.code,
      'group_field': groupFieldId,
      'style': style.code,
      'title': title,
      'position': Sqflite.firstIntValue(posRows) ?? 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteChart(int chartId) async {
    final db = await _db;
    await db.delete('charts', where: 'id = ?', whereArgs: [chartId]);
  }
}
