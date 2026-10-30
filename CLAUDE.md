# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Context — read first

`claude-context/` holds dated session summaries (`YYYY-MM-DD-session-summary.md`) describing
recent work, decisions, and **open items / next steps**. At the start of every session, read
the most recent file(s) there to see what is going on with the app before making changes.
At the end of a session with significant work, add a new summary in the same format.

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
flutter build ios        # Build iOS
flutter build web        # Build web
flutter build windows    # Build Windows desktop
```

### Devices

```bash
flutter devices          # List connected devices and emulators
flutter emulators        # List available emulators (not yet running)
flutter emulators --launch <emulator_id>  # Start a specific emulator
```

### Running the app

```bash
flutter run              # Run on the single connected device (prompts if multiple)
flutter run -d <device_id>   # Run on a specific device (use ID from flutter devices)
flutter run -d emulator-5554 # Example: run on a specific Android emulator
flutter run --release    # Run release build (no debug overhead)
```

### Logs (clean output, no noise)

```bash
# PowerShell — show only Flutter/app lines
flutter logs 2>&1 | sls "flutter"

# adb — errors only (quietest option)
adb logcat flutter:E *:S

# adb — all Flutter log levels
adb logcat -s flutter
```

### Build and install APK on connected phone

```bash
# Build a release APK and install it directly on the connected phone
flutter build apk --release && adb install build\app\outputs\flutter-apk\app-release.apk

# Build only (file saved to build/app/outputs/flutter-apk/app-release.apk)
flutter build apk --release

# Install a previously built APK (replace existing app)
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### Connecting a phone over USB (one-time setup)

1. **Settings → About phone → tap "Build number" 7 times** — unlocks Developer options.
2. **Settings → Developer options → enable "USB debugging"**.
3. Connect with a **data** USB cable. Charge-only cables carry no data and the phone will never appear.
4. Accept the **"Allow USB debugging?"** prompt on the phone → tick *Always allow* → **Allow**.

Step 4 is the one that gets missed. Until it is accepted the device shows as `unauthorized`.

```bash
adb devices     # expect: "<serial>    device"
```

| `adb devices` output | Meaning |
|---|---|
| `<serial>  device` | Ready |
| `<serial>  unauthorized` | The on-phone prompt has not been accepted |
| empty list | Cable is charge-only, or USB debugging is off |

### Screenshots from a device

Capture the framebuffer straight off the phone or emulator as a pixel-perfect PNG:

```bash
adb exec-out screencap -p > screenshot.png
```

The command prints nothing — it silently writes `screenshot.png` into the current
directory. `screencap` runs **on the device** and encodes the PNG there; `exec-out`
streams those raw bytes back over USB and `>` redirects them to a file on the PC.
The result is the device's native resolution with no scaling or window chrome.

**Use `exec-out`, never `shell`.** `adb shell screencap -p > f.png` looks equivalent
but writes a **corrupt** PNG on Windows: `shell` runs in text mode and mangles
newline bytes inside the binary stream. `exec-out` is a raw binary channel.

```bash
# Timestamped, so captures don't overwrite each other (PowerShell)
adb exec-out screencap -p > "shot-$(Get-Date -Format 'HHmmss').png"

# Record video instead (Ctrl+C to stop), then pull it
adb shell screenrecord /sdcard/demo.mp4
adb pull /sdcard/demo.mp4
```

With both a phone and an emulator connected, `adb` errors with "more than one
device". Disambiguate with `-s`:

```bash
adb devices                                          # copy the serial
adb -s <serial> exec-out screencap -p > shot.png
```

Optional live mirroring / control from the PC: `winget install Genymobile.scrcpy`,
then run `scrcpy`. Not needed for screenshots — capture the framebuffer directly
instead, since screenshotting a mirror window is lossy.

## Development Workflow (good practices for every change)

1. **Develop on the `.dev` build** (`flutter run`, emulator or phone). It has its own
   database, so the real app's data is never at risk. See *Protecting Real Data* below.
2. **Test against sample data.** Settings → Data → Developer → *Load sample data* gives
   ~14 months of realistic history plus edge cases in ~2 s. Reload it whenever you
   want a known starting point.
3. **Keep the sample data in sync with the app.** `lib/dev/sample_data.dart` must
   reflect the app *as it currently is*. Whenever a change adds or alters a model
   field, table, screen or feature:
   - populate the new thing in `SampleData.load` with realistic values;
   - add its edge cases (empty, single item, zero, extreme or mixed units, etc.) and
     list them in the class doc comment;
   - extend `test/sample_data_test.dart` to assert the new data is there.
   Sample data that never exercises a feature cannot catch that feature's bugs.
4. **Schema changes** touch several places at once: bump the DB version and add a new
   `_onUpgrade` block, add the table to `clearAll()`, update the migration-history
   table below, update `SampleData` (and its bulk-write section if the table holds
   history), and check whether backups/exports in `ShareService` should include it.
5. **Write or update unit tests** for any new logic (see *Testing*). Put pure logic
   (aggregation, scales, date windows) in plain functions/classes so it can be tested
   without widgets.
6. **Before committing:** `flutter analyze` and `flutter test` must both be clean.
   For UI changes, also check the screen on the emulator in light and dark mode
   (screenshots: see *Screenshots from a device*).
7. Update this file for major changes, then commit (see *Commits and Version Control*).

## Testing

```bash
flutter test                         # everything (~seconds, no device needed)
flutter test test/repositories_test.dart
```

| File | Covers |
|---|---|
| `test/models_test.dart` | `toMap`/`fromMap` round-trips, volume / avg weight |
| `test/chart_filter_test.dart` | calendar windows, granularity, period keys, dots |
| `test/axis_scale_test.dart` | chart y-axis scaling and tick labels |
| `test/aggregation_test.dart` | log / measurement aggregation per granularity |
| `test/repositories_test.dart` | every repository against a real in-memory SQLite DB |
| `test/sample_data_test.dart` | sample data loads, is consistent and contains its edge cases |
| `test/progress_line_chart_test.dart` | chart widget renders 1–2 series and toggles |
| `test/plan_schedule_test.dart` | `planScheduleByDay` grouping, rest days, deleted workouts |
| `test/bottom_action_bar_test.dart` | Save bar stays above 0 / gesture / 3-button nav bar heights |

Database tests run on desktop SQLite via `sqflite_common_ffi`. `test/helpers/test_db.dart`
points `DatabaseHelper` at a fresh in-memory database per test
(`DatabaseHelper.pathOverride` + `resetForTesting()`), so tests never touch a real DB file.

## Architecture

Entry point is `lib/main.dart`. Repositories are injected at startup via `AppRepositories` (`lib/app_repositories.dart`), an `InheritedWidget` that makes all repos available anywhere in the tree. `SettingsRepository` is the exception — it is passed directly to `WorkoutApp` and not added to `AppRepositories` because it is a UI-level concern unrelated to workout data.

```
lib/
  main.dart                 ← app entry, DB init, repo injection, theme state
  app_repositories.dart     ← InheritedWidget holding all data repositories
  core/
    app_logger.dart         ← shared Logger instance (package:logger)
  dev/
    sample_data.dart        ← SampleData.load(): wipes DB and seeds test data (debug builds only)
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
    settings_repository.dart  ← app preferences (theme mode, backup folder/timestamp); excluded from clearAll
  screens/
    exercises/              ← ExerciseListScreen, ExerciseDetailScreen, ExerciseFormScreen,
                               AlternativesPickerScreen
    workouts/               ← WorkoutListScreen, WorkoutDetailScreen, WorkoutFormScreen,
                               WorkoutPlanDetailScreen (view), WorkoutPlanFormScreen (edit),
                               WorkoutSessionScreen
    body/                   ← MeasurementListScreen, MeasurementDetailScreen
    progress/               ← ProgressScreen, ExerciseProgressScreen, MeasurementProgressScreen
    settings/               ← SettingsScreen, DataScreen
  services/
    share_service.dart      ← static helpers for export/import/auto-backup (workout plans, exercise logs, full backup)
  widgets/                  ← SetRowWidget, LinkRowWidget, DatePickerField, ProgressLineChart, ChartFilterBar,
                               AxisScale (pure y-axis scaling used by ProgressLineChart),
                               BottomActionBar (Save button pinned above the system nav bar)
test/                       ← unit + widget tests (see Testing); helpers/test_db.dart = in-memory DB
```

## Data Model Summary

- **Exercise** — name, aliases (comma-separated in DB), notes, owns a **SetTemplate** (list of **SetChild**: reps, weight, unit), and a list of **ExerciseLink** (label, url) stored in a separate table
- **Exercise alternatives** — symmetric, non-transitive links between two exercises (`exercise_alternatives`,
  one row per pair with the smaller id in `exercise_a`, enforced by a CHECK). Not a field on `Exercise`;
  read/write via `ExerciseRepository.getAlternatives / addAlternative / removeAlternative / setAlternatives`.
  Deleting an exercise removes its links.
- **ExerciseLog** — snapshot of set data at log time (independent of future template edits)
- **Workout** — name, notes, ordered list of exercise IDs
- **WorkoutPlan** — name, list of **WorkoutPlanEntry** (workoutId + dayOfWeek 1–7)
- **WorkoutSession** — logs that a workout was performed on a date
- **Measurement** — name only; entries are separate **MeasurementEntry** (value, unit, date)
- **app_settings** — key/value table for app preferences (e.g. `theme_mode`, `backup_folder_path`, `backup_last_timestamp`)

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
- **Schema version: 4** — bump version and add a new `if (oldVersion < N)` block in `_onUpgrade` in `lib/db/database_helper.dart` for every schema change. Never edit earlier migration blocks.
- On first launch, a default **"Weight"** measurement is seeded automatically
- Dates stored as ISO 8601 strings; displayed as dd/MM/yy via `intl`
- `app_settings` table is intentionally excluded from `clearAll()` so user preferences (e.g. dark mode) survive a data wipe

### Migration history
| Version | Change |
|---|---|
| 1 | Initial schema (exercises, workouts, plans, sessions, measurements) |
| 2 | Added `app_settings` key-value table for app preferences |
| 3 | Added `exercise_links` table (id, exercise_id, url, label, sort_order) |
| 4 | Added `exercise_alternatives` table (exercise_a, exercise_b; PK pair, CHECK a < b) |

## Protecting Real Data on a Daily-Driver Phone

The phone used for development also holds **real workout history**. Two properties of
this project make that data easy to destroy by accident.

### 1. Both build types are signed with the local debug keystore

`android/app/build.gradle.kts` sets `release { signingConfig = signingConfigs.getByName("debug") }`.
The debug keystore (`~/.android/debug.keystore`) is **generated per machine**, so an
APK built on a different computer has a different signature than the one installed
on the phone. Android refuses to update across a signature change:

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE
```

The usual "fix" (`adb uninstall com.example.workout_app`) **deletes the app's
SQLite database along with it**. Never run that on the phone holding real data.

To keep in-place updates working across machines, copy `~/.android/debug.keystore`
from the original machine to the new one **before building**.

### 2. The in-app backup is not a restore path

`ShareService.saveFullBackup` and `autoBackupToFolder` write **human-readable `.txt`**,
and `exportLogs` writes JSON — but `importWorkoutPlan` is the **only** import function
in the codebase. There is no importer for logs, measurements, or a full backup.
`saveFullBackup` also covers only exercises (incl. their alternatives) and logs —
**measurements are not included in any backup at all**.

Treat the `.txt`/JSON exports as an archive, not a restore. The only faithful backup
is the raw SQLite file (`workout_app.db` in the app documents directory).

### Safe pattern: side-by-side dev build (implemented)

Debug builds use a different `applicationId` so they install **alongside** the real
app instead of replacing it. `android/app/build.gradle.kts` sets:

```kotlin
buildTypes {
    debug {
        applicationIdSuffix = ".dev"
    }
}
```

| Build type | applicationId | Home-screen label |
|---|---|---|
| release | `com.example.workout_app` | workout_app |
| debug | `com.example.workout_app.dev` | workout_app dev |

The label comes from `@string/app_name`, defined in `android/app/src/main/res/values/strings.xml`
and overridden for debug by `android/app/src/debug/res/values/strings.xml` — a
build-type source-set override, which avoids the duplicate-resource error that
`resValue` would cause alongside a declared string.

The dev build gets its own package, its own private data directory, and therefore its
own empty database. The production app and its history are never touched — no
signature clash, no uninstall, no data loss. `flutter run` targets the debug build by
default, so day-to-day development is safe automatically.

**`applicationIdSuffix` does not change the Kotlin namespace** — `MainActivity.kt`
stays in `com.example.workout_app`. Nothing else in the project keys off the
applicationId (no Firebase, no `google-services.json`), so the suffix is self-contained.

Building `--release` still produces the real package, so shipping to the phone is
unchanged. Note that a release build made on a machine whose `debug.keystore` differs
from the phone's installed copy still hits the signature clash described above.

Note that `adb shell run-as <pkg>` (the only way to read app-private files without
root) works **only on debuggable builds**, so the DB of an installed *release* build
cannot be pulled off a non-rooted phone.

## Theme / Dark Mode

- `WorkoutApp` (in `main.dart`) is a `StatefulWidget` that owns `_themeMode`.
- On startup, the saved preference is loaded asynchronously in `initState` via `SettingsRepository.getThemeMode()`, defaulting to `ThemeMode.light` until the read completes.
- The user toggles dark mode in **Settings → Display → Dark mode** (`SwitchListTile`).
- The callback propagates: `WorkoutApp._onThemeModeChanged` → `_MainShell` → `SettingsScreen`.
- `SettingsRepository.setThemeMode()` persists the change (fire-and-forget, no await needed).

## System Navigation Bar (edge-to-edge)

Since Android 15 the app draws **behind** the system nav bar. Its height depends on the user's
setting: a thin gesture handle (the emulator default) or the much taller **3-button bar**
(back / home / recents, e.g. the Samsung Galaxy A54). Anything at the bottom of a screen must
make room for it, or it hides under the buttons:

- **Primary actions (Save / Create)** go in `Scaffold.bottomNavigationBar: BottomActionBar(...)`
  (`lib/widgets/bottom_action_bar.dart`), never at the end of a scrolling list.
- **`ListView` with explicit `padding`** loses Flutter's automatic inset; add
  `MediaQuery.paddingOf(context).bottom` to the bottom padding (`ListView` with no `padding`
  handles it already).
- **Bottom sheets** add `MediaQuery.viewPaddingOf(context).bottom` to their padding.
- **Bar colour**: `MaterialApp.builder` in `main.dart` wraps the app in an
  `AnnotatedRegion<SystemUiOverlayStyle>` that makes the bar transparent, turns off Android's
  contrast scrim (it was a light-grey strip in dark mode) and picks icon brightness from the
  theme. The screen's own bottom colour (tab bar, `BottomActionBar`, background) shows through.
- **Test UI with 3-button nav** on the emulator:
  `adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton`
  (revert with `...navbar.gestural`).

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
- **Alternatives** (bottom of `ExerciseDetailScreen`): exercises to swap in when equipment is busy. Tap one
  to open its detail; swipe left to remove (Undo snackbar, cleared when leaving the screen); Add/Edit opens
  `AlternativesPickerScreen` (searchable checklist, current alternatives first). Linking A↔B shows each on
  the other's list; links are not transitive. The detail list has extra bottom padding so the Log FAB
  never covers the last alternative.
- **Links**: each exercise stores an ordered list of `ExerciseLink` (label + URL). Displayed as tappable tiles in the detail screen (opens system browser via `url_launcher`). Edited in the form screen with the same add/remove pattern as sets. URLs without a scheme get `https://` prepended on save.

### Workouts tab
- Two sub-tabs: **Workouts** (list → `WorkoutDetailScreen`) and **Plans** (list → `WorkoutPlanDetailScreen`).
- Plans follow the same view/edit split as workouts. `WorkoutPlanDetailScreen` is **read-only**: Mon–Sun cards
  listing each day's workouts (empty day = "Rest day", today's card outlined). Tapping a workout opens
  `WorkoutDetailScreen` → exercises → logs. AppBar: Edit (→ `WorkoutPlanFormScreen`), Export, Delete.
  The FAB on the Plans tab opens `WorkoutPlanFormScreen` directly to create a plan. Grouping logic is the
  pure function `planScheduleByDay` (entries pointing to a deleted workout are skipped).
- `WorkoutDetailScreen` lists exercises as tappable tiles that navigate to `ExerciseDetailScreen`.
  **Drag to reorder**: drag the ≡ handle (or long-press anywhere on a row) in a `ReorderableListView`
  (`onReorderItem`). The new order is saved immediately via `WorkoutRepository.update`, which rewrites
  `workout_exercises.sort_order` inside one transaction.
- `WorkoutFormScreen` (create/edit): exercise list sorts currently-included exercises to the top on load; order stays stable while the user toggles checkboxes. Includes a search bar filtering by name and alias.
- `WorkoutSessionScreen`: log that a workout was performed on a given date.

### Body tab
- List of measurements (e.g. Weight, Body Fat %); tap to open `MeasurementDetailScreen`.
- `MeasurementDetailScreen` shows entry history table and a line chart; supports adding, editing, and deleting entries.

### Progress tab
- **Exercises sub-tab**: searchable list of all exercises (filters by name and alias) → `ExerciseProgressScreen`.
  - Line chart with Avg Weight and Volume series; tapping a dot opens a log detail panel (edit/delete).
  - **Dual y-axes**: each visible series is scaled independently (`AxisScale.fit`) and plotted normalized to 0..1. The first visible series labels the left axis and the second the right, each tinted in its line colour. Every scale has exactly 4 round-valued intervals, so the gridlines line up and labels never collide. Large values are abbreviated (`40k`).
  - Time filter bar: Day / Week / Month / Year / All / Custom. Filter windows are **calendar-aligned** (Week = Mon–Sun of current week, Month = 1st–last day of current month, Year = Jan 1–Dec 31). Granularity auto-adjusts for any filter with 2+ data points (raw → daily → weekly → monthly). `All` uses adaptive granularity based on the actual data span.
  - X-axis labels are granularity-aware: monthly view shows "MMM", weekly shows "W1 Jan", other views show "dd/MM".
  - When only one aggregated point exists, the dot is always shown.
  - Data table (Weight and Volume sub-tabs) shows raw individual log entries within the selected window, with edit/delete per row.
- **Body sub-tab**: searchable list of all measurements (filters by name) → `MeasurementProgressScreen`.
  - Same filter bar, calendar-aligned windows, adaptive granularity, and axis labels as the exercise screen.
  - Single-series line chart; table shows raw entries within the selected window with edit/delete.
- Tab state is refreshed whenever the Progress tab is selected (via `GlobalKey<ProgressScreenState>`).

### Settings tab
- **Display** section: Dark mode toggle (persisted via `SettingsRepository`).
- **Data** section:
  - **Auto backup**: user picks a folder once via `FilePicker.getDirectoryPath()`; path stored in `app_settings`. On every app launch, `ShareService.autoBackupToFolder` runs silently (fire-and-forget in `main()`), writing `workout_backup.txt` to that folder (always overwrites — no accumulation). `DataScreen` shows last backup timestamp and a "Backup now" button. Picking a folder triggers an immediate backup.
  - **Share**: Export workout plan (JSON), Export exercise logs (JSON + human-readable .txt, with period picker), Import workout plan (from JSON file).
  - **Save backup**: dumps all exercises (aliases, notes, set template) and all logs per exercise to a human-readable `.txt` file at a user-chosen location via `FilePicker.saveFile` (Storage Access Framework — no extra permissions needed). On success, updates the last backup timestamp (same as auto-backup) so `DataScreen` reflects it.
  - **Manage data**: "Clear all data" — confirmation dialog, wipes all workout/exercise/measurement data, re-seeds default Weight measurement, preserves app preferences.
  - **Developer → Load sample data** (only when `kDebugMode`, i.e. the `.dev` build; compiled out of release): confirmation dialog, then `SampleData.load` wipes all data and seeds ~14 months of history — 16 exercises, 5 workouts, 3 plans, ~1100 logs, 7 measurements. Deterministic (`Random(42)`) with dates relative to today, so every chart filter has data. Includes deliberate edge cases (never-logged exercise, bodyweight weight-0 exercises, an lbs exercise, two logs on one day, empty workout/plan, single-entry and no-entry measurements) — listed in the class doc comment. History rows are written in one batched transaction (~2 s); going through the repositories took ~56 s.

### Share / Import (trainer ↔ client workflow)
File-based data exchange via `ShareService` (`lib/services/share_service.dart`):
- **Export workout plan**: from Settings → Data → Share, or from the plan view screen AppBar. Produces a self-contained JSON with exercises and set templates. Recipient imports it via "Import workout plan".
- **Export exercise logs**: Settings → Data → Share → Export logs. Period picker (Last 7 days / Last 30 days / Custom). Shares both `.json` (machine-readable) and `.txt` (human-readable grouped by date).
- **Import workout plan**: picks a `.json` file, deduplicates exercises by name (case-insensitive), always creates new Workout and WorkoutPlan objects with fresh UUIDs.

## Recent Changes

- **Exercise alternatives** (schema v4): symmetric links between exercises, shown and edited at the bottom
  of the exercise detail screen. Included in the text backups; not in workout-plan exports. Sample data
  has a hub (Lat Pulldown ↔ Pull-up, Barbell Row) that is deliberately non-transitive.
- **Reorder exercises in a workout**: drag handle (≡) on each row of `WorkoutDetailScreen`; order
  persists immediately. `WorkoutRepository.update` is now transactional.
- **System nav bar follows the theme**: transparent, no grey scrim, icon colour per light/dark mode.
- **Save buttons hidden by the 3-button nav bar (fix)**: on phones using 3-button navigation the
  Save/Create button at the end of the workout, exercise and plan forms sat under the system bar.
  It is now pinned in a `BottomActionBar`, always visible. Workout/exercise detail lists and the
  progress chart/table also reserve the nav-bar inset. See *System Navigation Bar*.
- **Plan view mode**: tapping a plan now opens a read-only `WorkoutPlanDetailScreen` (weekly schedule; tap a
  workout to open it). The old edit screen is now `WorkoutPlanFormScreen`, reached via the Edit icon or the
  Plans FAB. Export/Delete moved to the view screen. Sample data: PPL Saturday has two workouts.
- **Unit test suite**: 61 tests under `test/` (models, chart windows/granularity, axis scale, aggregation, all repositories on in-memory SQLite, sample data, chart widget). Logger is silenced in tests via `test/flutter_test_config.dart`. `aggregateLogs`/`aggregateEntries` are now public `@visibleForTesting`; `DatabaseHelper` gained `pathOverride`/`resetForTesting()`.
- **Progress chart dual axes**: Avg Weight was squashed flat because it shared one scale with Volume (~60 vs ~40000), and the top y labels overlapped ("40517.5" over "40000.0"). Each series now has its own scale and axis; see `lib/widgets/axis_scale.dart`.
- **Development workflow** section added to this file.
- **Sample data for testing**: Settings → Data → Developer → Load sample data (debug builds only). See `lib/dev/sample_data.dart`.
- **Calendar-aligned chart filter windows**: `windowStart`/`windowEnd` in `ChartFilterBar` now use calendar boundaries — Week = Mon–Sun of current week, Month = 1st–last day of current month, Year = Jan 1–Dec 31 — instead of rolling N-day windows.
- **Granularity-aware x-axis labels**: `ProgressLineChart` now accepts a `granularity` parameter. Monthly view labels as "MMM", weekly as "W1 Jan", others as "dd/MM".
- **Adaptive granularity for all filters**: Both progress screens apply adaptive granularity (based on the data span) whenever there are 2+ filtered data points, not just for the "All" filter.
- **Single-point dot always shown**: When only one aggregated point exists in the chart, `showDots` is forced to `true` regardless of the density setting.
- **Simplified empty chart state**: Replaced the verbose "Not enough data…" hint with "No data in this period." Chart now renders with 1+ points (was 2+).
- **Save backup updates timestamp**: `ShareService.saveFullBackup` returns `bool` (true = saved, false = cancelled/error). `DataScreen` now updates the last backup timestamp on success, consistent with auto-backup.
- **Auto backup**: Settings → Data → Auto backup. User picks a folder once; on every app launch the app silently writes `workout_backup.txt` there (overwrites). `SettingsRepository` stores `backup_folder_path` and `backup_last_timestamp`. `ShareService.autoBackupToFolder` handles the write without any UI dependency. `SettingsRepository` is now threaded through `_MainShell` → `SettingsScreen` → `DataScreen`.
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
