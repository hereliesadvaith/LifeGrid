# LifeGrid — Implementation Plan

> Porting the `schema_app.html` prototype to a Flutter app, local-first (no login),
> persisted with **raw sqflite**. This is a design/architecture doc — no code yet.

---

## 1. What we're building

A personal no-code database. Two tabs:

- **Schemas** — define *models* (e.g. `workouts`) and their typed *fields*.
- **LifeGrid** — pick a model and log *records* into it with a type-aware form.

Field types (from the prototype): `STR`, `INT`, `FLOAT`, `DATE`, `BOOL`.

The core insight to preserve: **structure (Schemas) is separate from data (LifeGrid)**,
and the record form adapts to each field's type.

---

## 2. The key decision: how to store a dynamic schema in SQLite

The user defines tables at runtime, so we can't hardcode columns. Two strategies:

| Strategy | Idea | Verdict |
|---|---|---|
| **A. Dynamic DDL** | `CREATE TABLE` per model, `ALTER TABLE ADD COLUMN` per field | ❌ Fragile: SQLite can't easily drop/retype columns, user names need sanitizing (injection risk), migrations get ugly. |
| **B. Metadata + EAV** (recommended) | Fixed set of tables that *describe* the user's models and store values as rows | ✅ Safe, flexible, schema changes are just row inserts/deletes. |

We go with **B**. Proposed tables:

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE models (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL,
  position   INTEGER NOT NULL,
  created_at INTEGER NOT NULL          -- epoch millis
);

CREATE TABLE fields (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  model_id   INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
  name       TEXT    NOT NULL,
  type       TEXT    NOT NULL,          -- 'STR' | 'INT' | 'FLOAT' | 'DATE' | 'BOOL'
  position   INTEGER NOT NULL
);

CREATE TABLE records (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  model_id   INTEGER NOT NULL REFERENCES models(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE values (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id  INTEGER NOT NULL REFERENCES records(id) ON DELETE CASCADE,
  field_id   INTEGER NOT NULL REFERENCES fields(id)  ON DELETE CASCADE,
  value      TEXT                       -- canonical string form, NULL if empty
);

CREATE INDEX idx_fields_model  ON fields(model_id);
CREATE INDEX idx_records_model ON records(model_id);
CREATE INDEX idx_values_record ON values(record_id);
CREATE INDEX idx_values_field  ON values(field_id);
```

**Value encoding** (single `TEXT` column, cast in Dart on read):
- `STR` → as-is
- `INT` / `FLOAT` → number as string (`"100.5"`); sort in SQL with `CAST(value AS REAL)`
- `DATE` → ISO `YYYY-MM-DD`
- `BOOL` → `"0"` / `"1"`
- empty/unset → store `NULL` (the prototype stored `""`; `NULL` is cleaner for sorting/filtering)

> Upgrade path if/when sort & filter get heavy: split `value` into typed columns
> (`value_num REAL`, `value_text TEXT`, `value_date TEXT`). Single column is fine for v1.

`ON DELETE CASCADE` everywhere means deleting a model wipes its fields, records, and
values automatically — and removing a field cleans up its orphaned values.

---

## 3. Project structure

```
lib/
  main.dart                 # app entry, theme, root PageView
  theme/
    tokens.dart             # colors, radii, spacing from CSS :root vars
    typography.dart         # Doto / Space Grotesk / Space Mono text styles
  data/
    database.dart           # sqflite open + schema creation + migrations
    field_type.dart         # FieldType enum + parse/encode/format helpers
    models_repository.dart   # CRUD: models, fields, records, values
  models/                   # plain Dart domain objects
    app_model.dart          # id, name, List<FieldDef>, recordCount
    field_def.dart          # id, name, FieldType, position
    record_entry.dart       # id, Map<fieldId, dynamic> values
  state/
    app_store.dart          # ChangeNotifier wrapping the repository
  ui/
    home_page.dart          # tabs + PageView (LifeGrid / Schemas)
    lifegrid/
      lifegrid_tab.dart     # model list (record counts)
      records_page.dart     # drill-down: records for one model
      add_record_sheet.dart # dynamic, type-aware form
    schemas/
      schemas_tab.dart      # model list (field type chips)
      fields_page.dart      # drill-down: fields for one model
      new_model_sheet.dart
      add_field_sheet.dart  # name + type-grid picker
    widgets/                # shared cards, empty states, primary button, etc.
```

---

## 4. Dependencies

| Package | Why |
|---|---|
| `sqflite` | local SQLite (chosen) |
| `path` / `path_provider` | resolve the DB file location |
| `provider` | lightweight state (optional — could use plain `ValueNotifier`) |
| `google_fonts` | Doto, Space Grotesk, Space Mono without bundling files |
| `intl` | date formatting/parsing |

Keeping the dep list intentionally small to match the raw-sqflite spirit.

---

## 5. Mapping the prototype → Flutter

| Prototype (HTML/CSS/JS) | Flutter |
|---|---|
| Swipe pager + animated underline tabs | `PageView` + custom header row with an `AnimatedAlign`/`AnimatedPositioned` underline driven by page offset |
| Record / model cards | Custom `Container` widgets in a `ListView` |
| Drill-down overlays (slide in from right) | `Navigator.push` with a `SlideTransition` route (matches `translateX(100%)`) |
| Bottom sheets (new model / add field / add record) | `showModalBottomSheet` (rounded top, scrim) |
| Type grid selection | Selectable cards via `StatefulWidget` / `ToggleButtons`-style custom grid |
| Dynamic record form (add **and edit**) | Build a column of fields from `model.fields`; per type: `TextFormField` (`keyboardType` numeric/decimal), date picker (`showDatePicker`), `Switch` for BOOL. Same widget pre-filled from an existing record = edit mode. |
| Tapping a record | Opens the record in the form view, pre-filled, in edit mode (Save updates, bumps `updated_at`) |
| `rise` keyframe / `:active` scale | `AnimatedOpacity` + staggered delays; `AnimatedScale` or `InkWell` feedback |
| CSS design tokens (`:root`) | `theme/tokens.dart` constants + `ThemeData` |

Design tokens to carry over verbatim: bg `#000`, surface `#0c0c0c`, line `#262626`,
accent `#d71921`, card radius `16`, chip radius `999`, the dotted-grid background.

---

## 6. Build phases (suggested order)

1. **Foundation** — add deps, port theme tokens + typography, set up the two-tab `PageView` shell.
2. **Data layer** — `database.dart` (open + create tables), `field_type.dart`, `models_repository.dart` with full CRUD. Unit-test the repo against an in-memory DB.
3. **State** — `app_store.dart` (`ChangeNotifier`) exposing models, fields, records and mutation methods.
4. **Schemas tab** — model list → new-model sheet → fields overlay → add/remove field sheet → delete model. Enforce the **schema-lock rule** (see §7.2): once a model has ≥1 record, field add/remove/edit is disabled in the UI (controls greyed out with a hint) and rejected in the repository.
5. **LifeGrid tab** — model list with counts → records overlay → dynamic record form for **both add and edit** (tap a record to edit) → delete record.
6. **Polish** — empty states, staggered animations, singular/plural labels, edge cases (model with no fields, locked-schema hint, etc.).

---

## 7. Decisions (resolved)

1. **Editing — IN.** Records are editable via a **form view**: tapping a record opens the
   same dynamic form used for "add", pre-filled with its current values; saving updates the
   row and bumps `updated_at`. Field names are also editable while the schema is unlocked
   (see below).
2. **Schema lock — strict.** A model's schema (its fields) can only be changed **while it has
   zero records**. The moment a model has ≥1 record, adding/removing/renaming/retyping fields
   is forbidden. This is enforced in **two places**:
   - **UI** — field add/remove/edit controls are disabled with a short hint
     ("Schema is locked — delete all records to change fields").
   - **Repository** — mutation methods check `recordCount == 0` and throw otherwise, so the
     rule can't be bypassed.

   This rule deletes the entire "what happens to existing data on schema change" problem:
   structure is frozen before any data depends on it.
3. **Validation — IN.** The record form rejects non-parseable `INT`/`FLOAT`/`DATE` input
   before saving (inline error, save blocked), so stored values stay clean for future
   sorting/aggregation. Empty optional values store `NULL`.
4. **Sort / filter / search — later.** Not in v1. The schema (esp. the typed-value-column
   upgrade) is designed to support it without a rewrite.
5. **Reordering — later.** The `position` columns exist so drag-to-reorder can be added
   later; v1 just appends in creation order.

---

## 8. Out of scope for v1 (deliberately)

Auth/login, cloud sync, export/import, sharing, relations between models, computed/rollup
fields. All are natural follow-ups; none block a useful first version.
