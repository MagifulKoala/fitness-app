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

Entry point is `lib/main.dart`. Repositories are injected at startup via `AppRepositories` (`lib/app_repositories.dart`), an `InheritedWidget` that makes all repos available anywhere in the tree.

```
lib/
  main.dart                 ← app entry, DB init, repo injection
  app_repositories.dart     ← InheritedWidget holding all repositories
  models/                   ← Dart data classes (Equatable, toMap/fromMap)
  db/                       ← DatabaseHelper singleton (sqflite schema + migrations)
  repositories/             ← one file per entity, all SQL queries live here
  screens/
    exercises/              ← ExerciseListScreen, ExerciseDetailScreen, ExerciseFormScreen
    workouts/               ← WorkoutListScreen, WorkoutDetailScreen, WorkoutFormScreen,
                               WorkoutPlanDetailScreen, WorkoutSessionScreen
    body/                   ← MeasurementListScreen, MeasurementDetailScreen
    progress/               ← ProgressScreen, ExerciseProgressScreen, MeasurementProgressScreen
  widgets/                  ← SetRowWidget, DatePickerField, ProgressLineChart, ProgressTable
```

## Data Model Summary

- **Exercise** — name, aliases (comma-separated in DB), notes, owns a **SetTemplate** (list of **SetChild**: reps, weight, unit)
- **ExerciseLog** — snapshot of set data at log time (independent of future template edits)
- **Workout** — name, notes, ordered list of exercise IDs
- **WorkoutPlan** — name, list of **WorkoutPlanEntry** (workoutId + dayOfWeek 1–7)
- **WorkoutSession** — logs that a workout was performed on a date
- **Measurement** — name only; entries are separate **MeasurementEntry** (value, unit, date)

Volume = sum(reps × weight) across all sets in a SetTemplate (adimensional).

## State Management

No external state management library. Repositories are passed via `AppRepositories` InheritedWidget. Screens reload data with `setState` after mutations.

## Packages

| Package | Purpose |
|---|---|
| `sqflite` | SQLite local database |
| `path_provider` | Locate device directory for DB file |
| `uuid` | Generate UUID v4 for all entity IDs |
| `fl_chart` | Line charts for progress views |
| `intl` | Date formatting (dd/MM/yy display, ISO 8601 storage) |
| `equatable` | Value equality for model classes |
| `logger` | Structured console logging (debug/info/warn/error) |

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
- Schema version: 1 — add migrations in `_onUpgrade` in `lib/db/database_helper.dart`
- On first launch, a default **"Weight"** measurement is seeded automatically
- Dates stored as ISO 8601 strings; displayed as dd/MM/yy via `intl`

## Linting

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with no custom overrides. Run `flutter analyze` before committing changes.


### Commits and Version Control

Use git to maintain a history of changes made. Currently the project isn't connected to a remote repo so pushing isn't necessary. "git add ." your changes and then "git commit -m ''" with a meaningful commit message that briefly shows the changes made.


## Recent Changes

- **Workout detail → exercise navigation**: Exercises listed in `WorkoutDetailScreen` are now tappable `ListTile`s with a chevron; tapping navigates to `ExerciseDetailScreen` (same view as the Exercises tab, including the Log FAB).
- **Date picker**: `DatePickerField` allows any date from 2000 to `DateTime(9999,12,31)`. Today always highlighted.
- **Android system nav bar**: Bottom sheets add `MediaQuery.viewPadding.bottom` to padding. `WorkoutSessionScreen` body wrapped in `SafeArea`.
- **Exercise log fix**: Log sets now get fresh UUIDs each time to prevent `UNIQUE constraint` violations on repeat logs.
- **Settings tab**: New bottom nav entry → `SettingsScreen` → `DataScreen` with "Clear all data" (confirmation alert, full screen refresh after wipe).
- **Progress tab refresh**: Uses `GlobalKey<ProgressScreenState>` so switching to the tab always fetches fresh data.
- **Progress table**: Scrolls vertically and horizontally. Chart line shows dots at every data point.
- **Edit/delete log entries**: Both `ExerciseProgressScreen` and `MeasurementProgressScreen` table views have an edit icon per row opening an edit sheet with dirty-state Save button and Delete with confirmation.
- **Logging**: `package:logger` added. All repositories log mutations at `d` level. Errors logged at `e` level with stack traces. `clearAll` logged at `w` level. Shared instance at `lib/core/app_logger.dart`.

### CLAUDE.md
Make sure to update the claude.md file with any major changes