# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter workout/fitness tracking app targeting **Android** (primary). Cross-platform support configured for iOS, Web, Linux, macOS, Windows.

- Language: Dart ^3.11.4
- Framework: Flutter >=3.18.0

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint (uses flutter_lints)
flutter test             # Run all tests
flutter test test/foo_test.dart  # Run a single test file
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build appbundle  # Build Android App Bundle
flutter build ios        # Build iOS
flutter build web        # Build web
flutter build windows    # Build Windows desktop
```

## Architecture

Entry point is `lib/main.dart`. Repositories are injected at startup via `AppRepositories` (`lib/app_repositories.dart`), an `InheritedWidget` that makes all repos available anywhere in the tree. `SettingsRepository` is the exception — it is passed directly to `WorkoutApp` and not added to `AppRepositories` because it is a UI-level concern unrelated to workout data.

```
lib/
  main.dart                 ← app entry, DB init, repo injection, theme state
  app_repositories.dart     ← InheritedWidget holding all data repositories
  core/
    app_logger.dart         ← shared Logger instance (package:logger)
  models/                   ← Dart data classes (Equatable, toMap/fromMap)
  db/
    database_helper.dart    ← DatabaseHelper singleton (sqflite schema + migrations)
  repositories/
    exercise_repository.dart
    exercise_log_repository.dart
    workout_repository.dart
    workout_plan_repository.dart
    workout_session_repository.dart
    measurement_repository.dart
    settings_repository.dart  ← app preferences (theme mode); excluded from clearAll
  screens/
    exercises/              ← ExerciseListScreen, ExerciseDetailScreen, ExerciseFormScreen
    workouts/               ← WorkoutListScreen, WorkoutDetailScreen, WorkoutFormScreen,
                               WorkoutPlanDetailScreen, WorkoutSessionScreen
    body/                   ← MeasurementListScreen, MeasurementDetailScreen
    progress/               ← ProgressScreen, ExerciseProgressScreen, MeasurementProgressScreen
    settings/               ← SettingsScreen, DataScreen
  services/
    share_service.dart      ← static helpers for export/import (workout plans, exercise logs)
  widgets/                  ← SetRowWidget, LinkRowWidget, DatePickerField, ProgressLineChart, ChartFilterBar
```

## Data Model Summary

- **Exercise** — name, aliases (comma-separated in DB), notes, owns a **SetTemplate** (list of **SetChild**: reps, weight, unit), and a list of **ExerciseLink** (label, url) stored in a separate table
- **ExerciseLog** — snapshot of set data at log time (independent of future template edits)
- **Workout** — name, notes, ordered list of exercise IDs
- **WorkoutPlan** — name, list of **WorkoutPlanEntry** (workoutId + dayOfWeek 1–7)
- **WorkoutSession** — logs that a workout was performed on a date
- **Measurement** — name only; entries are separate **MeasurementEntry** (value, unit, date)
- **app_settings** — key/value table for app preferences (e.g. `theme_mode = 'dark'|'light'`)

Volume = sum(reps × weight) across all sets in a SetTemplate (adimensional).

## State Management

No external state management library. Repositories are passed via `AppRepositories` InheritedWidget. Screens reload data with `setState` after mutations. Theme mode is owned by `_WorkoutAppState` in `main.dart` and propagated down via widget parameters.

## Packages

| Package | Purpose |
|---|---|
| `sqflite` | SQLite local database |
| `sqflite_common_ffi` | SQLite FFI driver for Windows/Linux desktop |
| `path_provider` | Locate device directory for DB file |
| `uuid` | Generate UUID v4 for all entity IDs |
| `fl_chart` | Line charts for progress views |
| `intl` | Date formatting (dd/MM/yy display, ISO 8601 storage) |
| `equatable` | Value equality for model classes |
| `logger` | Structured console logging (debug/info/warn/error) |
| `share_plus` | Android share sheet for exporting files |
| `file_picker` | File picker for importing JSON files and saving backups |
| `url_launcher` | Open URLs in the system browser (exercise links) |

## Logging

A shared `Logger` instance lives at `lib/core/app_logger.dart` — import and use `log.d/i/w/e` anywhere.

| Level | Usage |
|---|---|
| `log.d` | Normal mutations (insert, update, delete) in repositories |
| `log.w` | Significant irreversible actions (clearAll) |
| `log.e` | Caught exceptions — always pass `error:` and `stackTrace:` |

Filter on device with:
```powershell
flutter logs 2>&1 | sls "flutter"   # PowerShell
```
```bash
adb logcat flutter:E *:S            # errors only
```

## Database Notes

- DB file: `workout_app.db` in the app documents directory
- **Schema version: 3** — bump version and add a new `if (oldVersion < N)` block in `_onUpgrade` in `lib/db/database_helper.dart` for every schema change. Never edit earlier migration blocks.
- On first launch, a default **"Weight"** measurement is seeded automatically
- Dates stored as ISO 8601 strings; displayed as dd/MM/yy via `intl`
- `app_settings` table is intentionally excluded from `clearAll()` so user preferences (e.g. dark mode) survive a data wipe

### Migration history
| Version | Change |
|---|---|
| 1 | Initial schema (exercises, workouts, plans, sessions, measurements) |
| 2 | Added `app_settings` key-value table for app preferences |
| 3 | Added `exercise_links` table (id, exercise_id, url, label, sort_order) |

## Theme / Dark Mode

- `WorkoutApp` (in `main.dart`) is a `StatefulWidget` that owns `_themeMode`.
- On startup, the saved preference is loaded asynchronously in `initState` via `SettingsRepository.getThemeMode()`, defaulting to `ThemeMode.light` until the read completes.
- The user toggles dark mode in **Settings → Display → Dark mode** (`SwitchListTile`).
- The callback propagates: `WorkoutApp._onThemeModeChanged` → `_MainShell` → `SettingsScreen`.
- `SettingsRepository.setThemeMode()` persists the change (fire-and-forget, no await needed).

## FAB Hero Tags

Every `FloatingActionButton` in the app sets `heroTag: null`. The main shell uses an `IndexedStack` which keeps all tab screens mounted simultaneously, so multiple FABs exist in the widget tree at once. Without unique tags Flutter throws a "multiple heroes with the same tag" assertion at navigation time.

## Linting

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with no custom overrides. Run `flutter analyze` before committing changes.

## Commits and Version Control

Use git to maintain a history of changes made. Currently the project isn't connected to a remote repo so pushing isn't necessary. `git add .` your changes and then `git commit -m ''` with a meaningful commit message that briefly describes the changes made.

## Feature Overview

### Exercises tab
- List of all exercises; tap to open `ExerciseDetailScreen` (shows links, set template, log history).
- FAB opens `ExerciseFormScreen` (create/edit name, aliases, notes, links, set template).
- From `ExerciseDetailScreen`, the Log FAB opens a log sheet to record a session.
- **Links**: each exercise stores an ordered list of `ExerciseLink` (label + URL). Displayed as tappable tiles in the detail screen (opens system browser via `url_launcher`). Edited in the form screen with the same add/remove pattern as sets. URLs without a scheme get `https://` prepended on save.

### Workouts tab
- Two sub-tabs: **Workouts** (list → `WorkoutDetailScreen`) and **Plans** (list → `WorkoutPlanDetailScreen`).
- `WorkoutDetailScreen` lists exercises as tappable tiles that navigate to `ExerciseDetailScreen`.
- `WorkoutFormScreen` (create/edit): exercise list sorts currently-included exercises to the top on load; order stays stable while the user toggles checkboxes. Includes a search bar filtering by name and alias.
- `WorkoutSessionScreen`: log that a workout was performed on a given date.

### Body tab
- List of measurements (e.g. Weight, Body Fat %); tap to open `MeasurementDetailScreen`.
- `MeasurementDetailScreen` shows entry history table and a line chart; supports adding, editing, and deleting entries.

### Progress tab
- **Exercises sub-tab**: searchable list of all exercises (filters by name and alias) → `ExerciseProgressScreen`.
  - Line chart with Avg Weight and Volume series; tapping a dot opens a log detail panel (edit/delete).
  - Time filter bar: Day / Week / Month / Year / All / Custom. Granularity auto-adjusts (raw → daily → weekly → monthly). `All` filter uses adaptive granularity based on the actual data span so all logs are visible.
  - Data table (Weight and Volume sub-tabs) shows raw individual log entries within the selected window, with edit/delete per row.
- **Body sub-tab**: searchable list of all measurements (filters by name) → `MeasurementProgressScreen`.
  - Same filter bar and adaptive granularity as the exercise screen.
  - Single-series line chart; table shows raw entries within the selected window with edit/delete.
- Tab state is refreshed whenever the Progress tab is selected (via `GlobalKey<ProgressScreenState>`).

### Settings tab
- **Display** section: Dark mode toggle (persisted via `SettingsRepository`).
- **Data** section:
  - **Share**: Export workout plan (JSON), Export exercise logs (JSON + human-readable .txt, with period picker), Import workout plan (from JSON file).
  - **Save backup**: dumps all exercises (aliases, notes, set template) and all logs per exercise to a human-readable `.txt` file at a user-chosen location via `FilePicker.saveFile` (Storage Access Framework — no extra permissions needed).
  - **Manage data**: "Clear all data" — confirmation dialog, wipes all workout/exercise/measurement data, re-seeds default Weight measurement, preserves app preferences.

### Share / Import (trainer ↔ client workflow)
File-based data exchange via `ShareService` (`lib/services/share_service.dart`):
- **Export workout plan**: from Settings → Data → Share, or from the plan's edit screen AppBar. Produces a self-contained JSON with exercises and set templates. Recipient imports it via "Import workout plan".
- **Export exercise logs**: Settings → Data → Share → Export logs. Period picker (Last 7 days / Last 30 days / Custom). Shares both `.json` (machine-readable) and `.txt` (human-readable grouped by date).
- **Import workout plan**: picks a `.json` file, deduplicates exercises by name (case-insensitive), always creates new Workout and WorkoutPlan objects with fresh UUIDs.

## Recent Changes

- **Exercise links**: Each exercise now has an ordered list of links (label + URL). Stored in `exercise_links` table (schema v3). Tappable tiles in `ExerciseDetailScreen` open the system browser. Managed in `ExerciseFormScreen` with the same add/remove/edit pattern as sets. `url_launcher` added; Android `<queries>` block updated for http/https. `LinkRowWidget` added to `lib/widgets/`.
- **Save backup**: Settings → Data → Save backup. Writes a plain-text file (exercises section + logs-per-exercise section) to a user-chosen location via `FilePicker.saveFile`. Uses `ExerciseLogRepository.getAll()`.
- **Progress chart fix**: `ProgressLineChart` was not updating when the filter changed because `_series` was only set in `initState`. Added `didUpdateWidget` to sync series on widget update.

- **Dark mode**: Settings → Display → Dark mode toggle. Persisted in `app_settings` SQLite table (schema v2). Survives data wipes. Theme owned by `WorkoutApp` state and loaded async on startup.
- **Progress search bars**: Both the Exercises and Body sub-tabs on the Progress screen now have a search bar that filters the list in real time (exercises match on name and aliases; measurements match on name).
- **Workout form search + sort**: Exercise picker in `WorkoutFormScreen` shows currently-included exercises first (sorted once at load, stable during toggling) and has a search bar filtering by name and alias.
- **FAB hero tag fix**: All `FloatingActionButton`s set `heroTag: null` to prevent a Flutter assertion caused by the `IndexedStack` keeping multiple FABs in the tree simultaneously.
- **Workout detail → exercise navigation**: Exercises listed in `WorkoutDetailScreen` are tappable `ListTile`s navigating to `ExerciseDetailScreen`.
- **Date picker**: `DatePickerField` allows any date from 2000 to `DateTime(9999,12,31)`. Today always highlighted.
- **Android system nav bar**: Bottom sheets add `MediaQuery.viewPadding.bottom` to padding. `WorkoutSessionScreen` body wrapped in `SafeArea`.
- **Exercise log fix**: Log sets get fresh UUIDs each time to prevent `UNIQUE constraint` violations on repeat logs.
- **Edit/delete log entries**: Both `ExerciseProgressScreen` and `MeasurementProgressScreen` table views have an edit icon per row opening an edit sheet with dirty-state Save button and Delete with confirmation.
- **Logging**: `package:logger` added. All repositories log mutations at `d` level. Errors at `e` level with stack traces. `clearAll` at `w` level.
- **File-based sharing**: `share_plus` + `file_picker` packages added. `ShareService` handles export/import of workout plans and exercise logs. Export entry points: plan edit AppBar and Settings → Data → Share. System nav bar padding fixed on all bottom sheets using `MediaQuery.viewPaddingOf(context).bottom`.
- **Exercise log repository**: `getByDateRange()` added. Both `getByExerciseId` and `getByDateRange` use a batch `WHERE log_id IN (...)` query via `rawQuery` to avoid N+1 set fetches.
- **Progress chart time filter**: `ChartFilterBar` widget (`lib/widgets/chart_filter_bar.dart`) with Day/Week/Month/Year/All/Custom chips added to both progress screens. Granularity auto-adjusts per filter; `All` uses adaptive granularity based on actual data span. Dots hidden for dense views (year/all with large span) but always shown when only 1 aggregated point exists. Table view shows raw individual entries within the selected window.

### CLAUDE.md
Make sure to update this file with any major changes.
