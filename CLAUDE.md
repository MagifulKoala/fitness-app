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

## Database Notes

- DB file: `workout_app.db` in the app documents directory
- Schema version: 1 — add migrations in `_onUpgrade` in `lib/db/database_helper.dart`
- On first launch, a default **"Weight"** measurement is seeded automatically
- Dates stored as ISO 8601 strings; displayed as dd/MM/yy via `intl`

## Linting

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with no custom overrides. Run `flutter analyze` before committing changes.
