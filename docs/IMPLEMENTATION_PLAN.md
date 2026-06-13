# Lifegrid — Dashboard & Charts Implementation Plan

> Porting the **Dashboard** additions from the `lifegrid.html` prototype to Flutter.
> Scope is *only* these updates: a Dashboard tab that holds user-created **charts**,
> a two-step "New chart" wizard, and a **pie/donut** chart (with bar/line stubbed for later).
> The base app (Home / Schema / Settings, sqflite, theme) already exists — this builds on it.

---

## 1. What we're adding

A fourth destination, **Dashboard** (first tab, index 0), that visualizes existing record
data as charts. The user composes a chart from data they already have:

- **Dashboard tab** — a list of chart cards; empty state when none. A floating `+ New chart`
  button (above the nav, like Schema's `+ New model`).
- **New chart wizard** — a bottom sheet with **two steps**:
  - **Step 1** — pick a **model** and a **chart type** (Pie live; Bar/Line shown as `SOON`).
    "Next" is disabled until both are chosen.
  - **Step 2** — model & type are now fixed (shown as a context subtitle, not re-pickable).
    Only the **type-specific config** appears: *group-by field*, *style*, *title*.
- **Pie/donut chart** — slices = distinct values of the group-by field, sized by record count.

The key extensibility goal: **adding bar/line later touches only a registry entry + two
branches** (config builder + renderer), nothing structural.

---

## 2. Chart definition — the data we persist

A chart is a small descriptor over an existing model. It does **not** copy data; it's
recomputed from records on every render.

```dart
// models/chart_def.dart
enum ChartType { pie, bar, line }      // bar/line declared now, unimplemented

enum PieStyle { donut, pie }

class ChartDef {
  final int id;
  final int modelId;        // FK -> models.id  (reference by id, NOT list index)
  final ChartType type;
  final int groupByFieldId; // FK -> fields.id
  final PieStyle style;     // pie-specific; ignored by other types for now
  final String title;
  final int position;       // for future reordering, mirrors models/fields
}
```

> **Why store `modelId`/`groupByFieldId`, not names or list indices.** The prototype kept a
> live object reference; in Flutter+sqflite the durable key is the row id. A chart can outlive
> a renamed field, and must degrade gracefully if its model/field was deleted (see §6).

### Persistence (sqflite)

One new table, same EAV spirit as the rest of the schema:

```sql
CREATE TABLE charts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  model_id      INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
  type          TEXT    NOT NULL,          -- 'pie' | 'bar' | 'line'
  group_field   INTEGER REFERENCES fields(id) ON DELETE SET NULL,
  style         TEXT,                       -- 'donut' | 'pie' (pie only)
  title         TEXT    NOT NULL,
  position      INTEGER NOT NULL,
  created_at    INTEGER NOT NULL
);
CREATE INDEX idx_charts_model ON charts(model_id);
```

- `ON DELETE CASCADE` on `model_id` — deleting a model removes its charts automatically.
- `group_field … ON DELETE SET NULL` — schema-lock means fields rarely vanish under a chart,
  but if it happens the chart survives and shows an "invalid field" note instead of crashing.
- Bump the DB version and add a migration that `CREATE TABLE charts` on upgrade.

---

## 3. Computing slices (the only real logic)

Pure function, no UI — easy to unit-test. Mirrors `computeSlices` in the prototype.

```dart
// data/chart_data.dart
class Slice { final String label; final int count; double pct; Color color; }
class ChartData { final List<Slice> slices; final int total; }

ChartData computePieData(AppModel model, FieldDef groupBy) {
  // tally records by the group-by value
  final counts = <String, int>{};
  for (final rec in model.records) {
    final v = rec.values[groupBy.id];
    final key = switch (groupBy.type) {
      _ when v == null || v == '' => '—',          // uncategorized
      FieldType.bool_            => (v == true || v == '1') ? 'true' : 'false',
      _                          => v.toString(),
    };
    counts.update(key, (n) => n + 1, ifAbsent: () => 1);
  }
  // sort desc by count, assign palette colors + percentages
  final slices = counts.entries
      .map((e) => Slice(label: e.key, count: e.value))
      .toList()..sort((a, b) => b.count.compareTo(a.count));
  final total = slices.fold(0, (s, x) => s + x.count);
  for (var i = 0; i < slices.length; i++) {
    slices[i].color = kChartPalette[i % kChartPalette.length];
    slices[i].pct   = total == 0 ? 0 : (slices[i].count / total * 100).round();
  }
  return ChartData(slices, total);
}
```

**Palette** — port verbatim from the prototype (`PALETTE`): accent red leads, then
white → greys. Put it in `theme/tokens.dart`:

```dart
const kChartPalette = [
  Color(0xFFD71921), Color(0xFFFFFFFF), Color(0xFF9A9A9A), Color(0xFF5E5E5E),
  Color(0xFFC98A8D), Color(0xFF3A3A3A), Color(0xFFE8E8E8), Color(0xFF7A7A7A),
];
```

---

## 4. Drawing the pie/donut — `CustomPainter` (no chart package)

Keeps the small-deps spirit. Matches the prototype's geometry (188×188, donut ring vs full
pie, 3px gaps, total in the donut hole).

```dart
// ui/dashboard/widgets/donut_painter.dart
class DonutPainter extends CustomPainter {
  final ChartData data;
  final bool donut;          // true = ring + center total, false = filled pie
  // For each slice: sweep = fraction * 2π, minus a tiny gap; start at -π/2 (12 o'clock).
  // donut -> strokeWidth ~34 on r≈70; pie -> a filled wedge to center (Path.arcTo + lineTo).
}
```

- **Donut:** `Canvas.drawArc(rect, start, sweep, false, strokePaint)` with
  `strokeCap = StrokeCap.butt`, one paint per slice color, a 3px angular gap between slices.
  Paint the total count + "RECORDS" in the hole with a `Text`/`TextPainter` (Doto font).
- **Pie:** same sweeps but `drawArc(..., true, fillPaint)` (wedges to center), no hole text.
- Wrap in an `AspectRatio(1)` / `SizedBox(188)` centered in the card.

**Legend** is plain widgets, not painted: a `Column` of rows
`[colored dot] name … pct% … count`, mono font, hairline dividers — straight port of
`buildLegend`.

---

## 5. UI structure

```
lib/ui/dashboard/
  dashboard_tab.dart            # list of ChartCard + empty state + "+ New chart" bar
  widgets/
    chart_card.dart             # header (title/subtitle/delete) + body switch on type
    donut_painter.dart          # CustomPainter (pie/donut)
    chart_legend.dart           # legend rows
  new_chart_sheet.dart          # the 2-step wizard (PageView or step-index state)
```

### Dashboard tab
- `PageTitleHeader('Dashboard')` (reuse existing widget) + a count chip.
- `ListView` of `ChartCard`s, or the empty state (`◔` glyph, "No charts yet…").
- The `+ New chart` action lives in `home_shell`'s bottom-bar area, shown only when the
  Dashboard page is active — mirror how the Schema page toggles its `+ New model` bar.

### ChartCard
- Header: title, subtitle `model · type · by field`, a `×` delete (confirm → repo delete).
- Body switches on `chart.type`:
  - `pie` → `computePieData` then `DonutPainter` + `ChartLegend`
    (or a "No records yet" note when `total == 0`).
  - `bar`/`line` → a "coming soon" placeholder.
  - model/field missing → "This model was deleted." / "Field no longer exists."

### New chart wizard (two steps)
Hold `step` (1|2) + draft selections in a `StatefulWidget` (or a small `ChangeNotifier`).
A `PageView` with physics disabled, or just conditional widgets keyed on `step`.

- **Step 1**
  - Model list → selectable cards (`models` from the store; show rec/field counts).
  - Chart-type grid from the registry (§7); `SOON` types are disabled/greyed.
  - `Next` button `enabled: model != null && type != null`.
- **Step 2**
  - Back button → `step = 1`; subtitle shows `model.name · typeLabel`.
  - **Config built by type** (§7): pie → group-by field chips + Donut/Pie segmented toggle +
    title field (defaults to model name).
  - `Create chart` → build `ChartDef`, persist via repo, refresh dashboard, close sheet.

---

## 6. Edge cases (match the prototype)

- **No models** → Step 1 model area shows "No models yet — create one in Schema first."
- **Model with no fields** → Step 2 group-by shows "This model has no fields…".
- **Model with 0 records** → card renders the header + "No records to chart yet."
- **Model deleted after chart created** → `CASCADE` removes the chart row; in-memory list
  drops it on next load. (If you cache charts in the store, prune on model delete.)
- **Group-by field deleted** → `SET NULL`; card shows an "invalid field" note, offers delete.

---

## 7. Extensibility — adding Bar / Line later

Three localized touch-points, nothing else:

1. **Registry** — flip `soon: false` for the type (the Flutter equivalent of `CHART_TYPES`):
   ```dart
   const kChartTypes = [
     (key: ChartType.pie,  code: 'PIE',  label: 'Pie / donut', soon: false),
     (key: ChartType.bar,  code: 'BAR',  label: 'Bar',         soon: true ),
     (key: ChartType.line, code: 'LINE', label: 'Line',        soon: true ),
   ];
   ```
2. **Config builder** — add a branch in the step-2 builder that renders that type's controls
   (e.g. bar might add an *aggregate* picker: count vs. sum-of-numeric-field).
3. **Renderer** — add a branch in `ChartCard` (and a new painter, e.g. `BarPainter`).

`ChartDef` already carries `type`; persistence already stores it. No schema/UI plumbing
changes — that's the whole point of the two-step split (generic step 1, type-specific step 2).

---

## 8. Build order

1. **Schema** — `charts` table + DB version bump + migration; `ChartDef` model.
2. **Repo/state** — chart CRUD in the repository; expose `charts` + mutations on `app_store`.
3. **Compute + paint** — `computePieData`, `DonutPainter`, `ChartLegend` (unit-test compute).
4. **Dashboard tab** — list/empty state + wire the `+ New chart` bar in `home_shell`.
5. **Wizard** — two-step sheet (step 1 model+type, step 2 pie config) → create + persist.
6. **Polish** — edge-case notes, staggered card animation, delete confirm.

---

## 9. Out of scope (for these updates)

Bar/line rendering, per-slice tap/drill-down, sum/avg aggregates (count only for now),
chart reordering (column exists), and editing an existing chart (delete + recreate for v1).
All are natural follow-ups enabled by the structure above.
