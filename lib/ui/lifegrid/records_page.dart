import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_model.dart';
import '../../models/record_entry.dart';
import '../../state/app_store.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../schemas/fields_page.dart';
import '../widgets/chips.dart';
import '../widgets/common.dart';
import '../widgets/dotted_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/rise_in.dart';
import 'record_form_sheet.dart';

/// Drill-down from the Lifegrid tab: the records of one model. Add via the
/// bottom bar, tap a record to edit, swipe-less × to delete.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.modelId});
  final int modelId;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<RecordEntry>? _records;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final records = await context.read<AppStore>().loadRecords(widget.modelId);
    if (mounted) setState(() => _records = records);
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
                          breadcrumb: 'Lifegrid · Data',
                          title: model.name,
                          subtitle: plural(model.recordCount, 'record'),
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
            'This model has no fields. Define its fields in Schemas before adding data.',
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
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 130),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => RiseIn(
        index: i,
        child: _RecordCard(
          model: model,
          record: records[i],
          index: i,
          onTap: () => _editRecord(context, model, records[i]),
          onDelete: () => _deleteRecord(records[i]),
        ),
      ),
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
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  final AppModel model;
  final RecordEntry record;
  final int index;
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
                Text((index + 1).toString().padLeft(2, '0'),
                    style: AppText.display(size: 15, weight: FontWeight.w900)),
                const SizedBox(width: 12),
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
