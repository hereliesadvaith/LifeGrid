import 'package:flutter/foundation.dart';

import '../data/field_type.dart';
import '../data/models_repository.dart';
import '../models/app_model.dart';
import '../models/chart_def.dart';
import '../models/field_def.dart';
import '../models/record_entry.dart';

/// App-wide state backed by [ModelsRepository]. The two tabs share the model
/// list; drill-down pages fetch their own records on demand.
class AppStore extends ChangeNotifier {
  AppStore({ModelsRepository? repo})
      : _repo = repo ?? ModelsRepository();

  final ModelsRepository _repo;

  List<AppModel> _models = [];
  List<AppModel> get models => _models;

  List<ChartDef> _charts = [];
  List<ChartDef> get charts => _charts;

  bool _loading = true;
  bool get loading => _loading;

  Future<void> load() async {
    _models = await _repo.loadModels();
    _charts = await _repo.loadCharts();
    _loading = false;
    notifyListeners();
  }

  AppModel? modelById(int id) {
    for (final m in _models) {
      if (m.id == id) return m;
    }
    return null;
  }

  // --- models ---
  Future<void> createModel(String name) async {
    await _repo.createModel(name.trim());
    await load();
  }

  Future<void> deleteModel(int modelId) async {
    await _repo.deleteModel(modelId);
    await load();
  }

  // --- fields (subject to schema lock; repo throws if locked) ---
  Future<void> addField(int modelId, String name, FieldType type) async {
    await _repo.addField(modelId, name.trim(), type);
    await load();
  }

  Future<void> renameField(int modelId, int fieldId, String name) async {
    await _repo.renameField(modelId, fieldId, name.trim());
    await load();
  }

  Future<void> deleteField(int modelId, int fieldId) async {
    await _repo.deleteField(modelId, fieldId);
    await load();
  }

  // --- records ---
  Future<List<RecordEntry>> loadRecords(int modelId) =>
      _repo.loadRecords(modelId);

  Future<void> addRecord(
    int modelId,
    List<FieldDef> fields,
    Map<int, Object?> values,
  ) async {
    await _repo.addRecord(modelId, fields, values);
    await load(); // refresh counts / lock state
  }

  Future<void> updateRecord(
    int recordId,
    List<FieldDef> fields,
    Map<int, Object?> values,
  ) async {
    await _repo.updateRecord(recordId, fields, values);
    notifyListeners();
  }

  Future<void> deleteRecord(int recordId) async {
    await _repo.deleteRecord(recordId);
    await load(); // refresh counts / lock state
  }

  // --- charts ---
  Future<void> createChart({
    required int modelId,
    required ChartType type,
    required int groupFieldId,
    required PieStyle style,
    required String title,
  }) async {
    await _repo.createChart(
      modelId: modelId,
      type: type,
      groupFieldId: groupFieldId,
      style: style,
      title: title,
    );
    await load();
  }

  Future<void> deleteChart(int chartId) async {
    await _repo.deleteChart(chartId);
    await load();
  }
}
