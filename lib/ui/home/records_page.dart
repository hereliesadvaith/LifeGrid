import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/field_type.dart';
import '../../models/app_model.dart';
import '../../models/field_def.dart';
import '../../models/record_entry.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../schema/fields_page.dart';
import '../widgets/chips.dart';
import '../widgets/common.dart';
import '../widgets/dotted_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/rise_in.dart';
import 'record_form_sheet.dart';

/// Sentinel sort key meaning "by date added" (records have no field for this).
const int _kSortByDateAdded = -1;

/// How many records to reveal per page in the list view's infinite scroll.
const int _kPageSize = 20;

/// Drill-down from the Home tab: the records of one model. Add via the
/// bottom bar, tap a record to edit, swipe-less × to delete.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.modelId});
  final int modelId;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<RecordEntry>? _records;

  /// Field id to sort by, or [_kSortByDateAdded] for insertion/creation order.
  int _sortFieldId = _kSortByDateAdded;

  /// Ascending when true; "date added" defaults to descending (newest first).
  bool _sortAsc = false;

  /// Number of records currently revealed (grows as the user scrolls).
  int _visibleCount = _kPageSize;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await context.read<AppStore>().loadRecords(widget.modelId);
    if (mounted) setState(() => _records = records);
  }

  void _changeSort(int fieldId) {
    setState(() {
      if (fieldId == _sortFieldId) {
        _sortAsc = !_sortAsc; // re-selecting the active field flips direction
      } else {
        _sortFieldId = fieldId;
        // Sensible default direction: newest-first for date added, A→Z for fields.
        _sortAsc = fieldId != _kSortByDateAdded;
      }
      _visibleCount = _kPageSize; // restart paging from the top after a re-sort
    });
  }

  /// Returns the records sorted by the active key/direction. Unset values always
  /// sink to the bottom regardless of direction; ties break by id for stability.
  List<RecordEntry> _sorted(AppModel model, List<RecordEntry> records) {
    if (_sortFieldId == _kSortByDateAdded) {
      final out = [...records]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return _sortAsc ? out : out.reversed.toList();
    }
    final FieldDef field =
        model.fields.firstWhere((f) => f.id == _sortFieldId);
    final out = [...records]
      ..sort((a, b) {
        final va = a.value(field.id);
        final vb = b.value(field.id);
        if (va == null || vb == null) {
          if (va == null && vb == null) return a.id.compareTo(b.id);
          return va == null ? 1 : -1; // nulls last, both directions
        }
        var c = _compareTyped(va, vb, field.type);
        if (c == 0) c = a.id.compareTo(b.id);
        return _sortAsc ? c : -c;
      });
    return out;
  }

  int _compareTyped(Object a, Object b, FieldType type) {
    switch (type) {
      case FieldType.int_:
        return (a as int).compareTo(b as int);
      case FieldType.float:
        return (a as double).compareTo(b as double);
      case FieldType.bool_:
        return ((a as bool) ? 1 : 0).compareTo((b as bool) ? 1 : 0);
      case FieldType.date:
        final da = DateTime.tryParse(a.toString());
        final db = DateTime.tryParse(b.toString());
        if (da != null && db != null) return da.compareTo(db);
        return a.toString().compareTo(b.toString());
      case FieldType.str:
        return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final model = store.modelById(widget.modelId);

    if (model == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final hasFields = model.fields.isNotEmpty;
    final records = _records ?? const [];

    return Scaffold(
      body: DottedBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: T.maxWidth),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: T.pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OverlayHeader(
                          breadcrumb: 'Home · Data',
                          title: model.name,
                          subtitle: plural(model.recordCount, 'record'),
                        ),
                        if (hasFields && records.isNotEmpty)
                          _SortBar(
                            fields: model.fields,
                            sortFieldId: _sortFieldId,
                            ascending: _sortAsc,
                            onSelect: _changeSort,
                          ),
                        Expanded(child: _body(context, model, hasFields, records)),
                      ],
                    ),
                  ),
                  if (hasFields)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomBar(
                        child: PrimaryButton(
                          label: 'Add record',
                          plus: true,
                          onPressed: () => _addRecord(context, store, model),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppModel model,
    bool hasFields,
    List<RecordEntry> records,
  ) {
    if (!hasFields) {
      return EmptyState(
        glyph: '!',
        title: 'No structure yet',
        message:
            'This model has no fields. Define its fields in Schema before adding data.',
        action: GhostButton(
          label: 'Define fields ›',
          onPressed: () {
            Navigator.of(context).pushReplacement(
              slideRoute(FieldsPage(modelId: model.id)),
            );
          },
        ),
      );
    }
    if (_records == null) return const SizedBox.shrink();
    if (records.isEmpty) {
      return const EmptyState(
        glyph: '▢',
        title: 'No data yet',
        message: 'Add your first record to start filling this model.',
      );
    }

    final sorted = _sorted(model, records);
    final visible = _visibleCount.clamp(0, sorted.length);
    final hasMore = visible < sorted.length;

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 130),
      itemCount: visible + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i >= visible) {
          // Footer: reaching it means the user scrolled to the end — reveal the
          // next page after this frame. Appended rows push it back off-screen,
          // so it loads exactly one page per scroll rather than all at once.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _visibleCount < sorted.length) {
              setState(() => _visibleCount += _kPageSize);
            }
          });
          return const _LoadMoreFooter();
        }
        return RiseIn(
          index: i,
          child: _RecordCard(
            model: model,
            record: sorted[i],
            onTap: () => _editRecord(context, model, sorted[i]),
            onDelete: () => _deleteRecord(sorted[i]),
          ),
        );
      },
    );
  }

  Future<void> _addRecord(BuildContext context, AppStore store, AppModel model) async {
    final saved = await showRecordFormSheet(context: context, store: store, model: model);
    if (saved == true) _reload();
  }

  Future<void> _editRecord(BuildContext context, AppModel model, RecordEntry r) async {
    final saved = await showRecordFormSheet(
      context: context,
      store: context.read<AppStore>(),
      model: model,
      existing: r,
    );
    if (saved == true) _reload();
  }

  Future<void> _deleteRecord(RecordEntry r) async {
    await context.read<AppStore>().deleteRecord(r.id);
    _reload();
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.model,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final AppModel model;
  final RecordEntry record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fields = model.fields;
    final primary = fields.first;
    final rest = fields.skip(1).take(3).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.rField),
          border: Border.all(color: T.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    primary.type.format(record.value(primary.id)),
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 16, weight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18, color: T.textDim),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in rest)
                      KvChip(label: f.name, value: f.type.format(record.value(f.id))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Right-aligned "Sort by" pill that opens a menu of fields (plus "Date added").
/// Re-selecting the active key flips the direction; the chip shows the arrow.
class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.fields,
    required this.sortFieldId,
    required this.ascending,
    required this.onSelect,
  });

  final List<FieldDef> fields;
  final int sortFieldId;
  final bool ascending;
  final ValueChanged<int> onSelect;

  String get _activeLabel {
    if (sortFieldId == _kSortByDateAdded) return 'Date added';
    final match = fields.where((f) => f.id == sortFieldId);
    return match.isEmpty ? 'Date added' : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<int>(
            tooltip: 'Sort records',
            color: T.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(T.rField),
              side: const BorderSide(color: T.line),
            ),
            onSelected: onSelect,
            itemBuilder: (_) => [
              _item(_kSortByDateAdded, 'Date added'),
              for (final f in fields) _item(f.id, f.name),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(T.rChip),
                border: Border.all(color: T.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SORT',
                      style: AppText.mono(
                          size: 10, color: T.textDim, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  Text(_activeLabel,
                      style: AppText.ui(size: 13, weight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14, color: T.textMid),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<int> _item(int id, String label) {
    final selected = id == sortFieldId;
    return PopupMenuItem<int>(
      value: id,
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppText.ui(
                    size: 14,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? T.text : T.textMid)),
          ),
          if (selected)
            Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 15, color: T.accent),
        ],
      ),
    );
  }
}

/// Subtle footer shown while more records remain to be revealed on scroll.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: T.textDim),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          T.pad, 16, T.pad, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [T.bg, T.bg, Colors.transparent],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
