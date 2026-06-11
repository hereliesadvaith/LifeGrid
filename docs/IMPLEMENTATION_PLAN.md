# Lifegrid — Implementation Plan

> Porting the `lifegrid.html` prototype to a Flutter app, local-first (no login),
> persisted with **raw sqflite**. This is a design/architecture doc — no code yet.

---

## 1. What we're building

A personal no-code database. The app is organized around a **bottom navigation bar**
(Google-Pay style — icon-only, no labels) with three destinations:

- **Home** — pick a model and log *records* into it with a type-aware form. (the data side)
- **Schema** — define *models* (e.g. `workouts`) and their typed *fields*. (the structure side)
- **Settings** — an editable profile (photo, first name, last name, email). Local-only for v1.

Both **Home** and **Schema** have a **search bar** at the top to filter the model list by name.

Field types (from the prototype): `STR`, `INT`, `FLOAT`, `DATE`, `BOOL`.

The core insight to preserve: **structure (Schema) is separate from data (Home)**,
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

CREATE TABLE field_values (        -- named `field_values`: `values` is a SQL reserved word
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
    profile.dart            # firstName, lastName, email, photo path/bytes
  state/
    app_store.dart          # ChangeNotifier wrapping the repository
    profile_store.dart      # ChangeNotifier for the Settings profile
  ui/
    home_shell.dart         # Scaffold + bottomNavigationBar + PageView (Home / Schema / Settings)
    home/
      home_tab.dart         # search bar + model list (record counts)
      records_page.dart     # drill-down: records for one model
      add_record_sheet.dart # dynamic, type-aware form
    schema/
      schema_tab.dart       # search bar + model list (field type chips)
      fields_page.dart      # drill-down: fields for one model
      new_model_sheet.dart
      add_field_sheet.dart  # name + type-grid picker
    settings/
      settings_tab.dart     # editable profile: avatar picker + name/email form
    widgets/                # shared cards, empty states, search bar, primary button, etc.
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
| `image_picker` | pick a profile photo on the Settings page |
| `shared_preferences` | persist the Settings profile (name/email + photo path) |

Keeping the dep list intentionally small to match the raw-sqflite spirit. The profile is
small, flat, and unrelated to the model data, so `shared_preferences` is a better fit than a
SQLite table; the picked photo is copied into the app's documents dir and only its path is stored.

---

## 5. Mapping the prototype → Flutter

| Prototype (HTML/CSS/JS) | Flutter |
|---|---|
| Swipe pager + icon-only bottom nav (Home / Schema / Settings) | `PageView` driven by a `BottomNavigationBar` (or a custom bar): `onTap` animates the page, `onPageChanged` updates the selected index. Icon-only items (`showSelectedLabels: false`), accent tint on the active icon. |
| Search bar atop Home / Schema | A `TextField` (pill-shaped, leading search icon) above each list; filters `models` by name (case-insensitive `contains`). UI-only filter over the in-memory list — see §7.4. |
| Settings profile (avatar + name/email + Save) | `settings_tab.dart`: a circular avatar (`CircleAvatar`, initials fallback) tapped to launch `image_picker`; `TextField`s for first/last/email; Save writes to `profile_store` → `shared_preferences`. |
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

1. **Foundation** — add deps, port theme tokens + typography, set up the `home_shell` (`PageView` + icon-only `BottomNavigationBar`) with three pages.
2. **Data layer** — `database.dart` (open + create tables), `field_type.dart`, `models_repository.dart` with full CRUD. Unit-test the repo against an in-memory DB.
3. **State** — `app_store.dart` (`ChangeNotifier`) exposing models, fields, records and mutation methods.
4. **Schema tab** — search bar → model list → new-model sheet → fields overlay → add/remove field sheet → delete model. Enforce the **schema-lock rule** (see §7.2): once a model has ≥1 record, field add/remove/edit is disabled in the UI (controls greyed out with a hint) and rejected in the repository.
5. **Home tab** — search bar → model list with counts → records overlay → dynamic record form for **both add and edit** (tap a record to edit) → delete record.
6. **Settings tab** — `profile_store` over `shared_preferences`; avatar picker (`image_picker`, initials fallback), first/last/email fields, Save.
7. **Polish** — empty states + no-search-results state, staggered animations, singular/plural labels, edge cases (model with no fields, locked-schema hint, etc.).

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
4. **Model-name search — IN. Record sort/filter — later.** Home and Schema each have a search
   bar that filters the *model list* by name (case-insensitive `contains`, UI-only over the
   in-memory list). Searching/sorting/filtering *within* a model's records is still v1-out; the
   schema (esp. the typed-value-column upgrade) is designed to support it without a rewrite.
5. **Reordering — later.** The `position` columns exist so drag-to-reorder can be added
   later; v1 just appends in creation order.
6. **Settings/profile — local-only.** First name, last name, email and a profile photo,
   persisted with `shared_preferences` (photo copied into the documents dir, path stored).
   It's purely cosmetic in v1 — no account, no sync, nothing keys off it. The fields are kept
   deliberately minimal so the page is a natural home for real account/sync settings later.

---

## 8. Out of scope for v1 (deliberately)

Auth/login, cloud sync, export/import, sharing, relations between models, computed/rollup
fields, and per-record search/sort/filter. The Settings profile is local-only and cosmetic
(no real account yet). All are natural follow-ups; none block a useful first version.
