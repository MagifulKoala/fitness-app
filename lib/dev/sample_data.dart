import 'dart:math';

import 'package:uuid/uuid.dart';

import '../app_repositories.dart';
import '../core/app_logger.dart';
import '../db/database_helper.dart';
import '../models/exercise.dart';
import '../models/exercise_link.dart';
import '../models/exercise_log.dart';
import '../models/measurement.dart';
import '../models/measurement_entry.dart';
import '../models/set_child.dart';
import '../models/set_template.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../models/workout_plan_entry.dart';
import '../models/workout_session.dart';

/// Fills the database with a realistic dataset for manual testing.
///
/// Wipes all existing data first. Dates are relative to today, so every chart
/// filter (Day / Week / Month / Year / All) always has something to show. The
/// random seed is fixed, so every load produces the same shape of data.
///
/// Only reachable from debug builds (see `DataScreen`).
///
/// Deliberate edge cases:
/// - Farmer's Carry: in no workout and never logged (empty history/chart).
/// - Pull-up, Plank: bodyweight, weight 0 (flat avg-weight, zero volume).
/// - Dumbbell Curl: logged in lbs while everything else is kg.
/// - Bench Press: two logs on the same day (same-day aggregation).
/// - Mobility workout: no exercises. Draft plan: no entries.
/// - Push / Pull / Legs: Saturday has two workouts (Legs + Mobility); Sunday
///   is a rest day.
/// - Thigh: a single entry. Neck: no entries.
/// - History spans ~14 months, so All covers more than one Year window.
class SampleData {
  static const _uuid = Uuid();
  static const _historyDays = 420;
  static const _phaseSwitchDaysAgo = 182;

  static Future<void> load(AppRepositories repos) async {
    final sw = Stopwatch()..start();
    final rnd = Random(42);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await DatabaseHelper.instance.clearAll();

    // ── Exercises ────────────────────────────────────────────────────────────
    final specs = <_ExSpec>[
      _ExSpec(
        'Bench Press',
        ['Flat Bench', 'BP'],
        [8, 8, 8, 8],
        60,
        1.25,
        links: [
          _link(
            'Form guide',
            'https://www.youtube.com/results?search_query=bench+press+form',
          ),
        ],
      ),
      _ExSpec('Overhead Press', ['OHP', 'Military Press'], [8, 8, 8], 35, 0.6),
      _ExSpec('Incline Dumbbell Press', ['Incline DB'], [10, 10, 10], 22, 0.4),
      _ExSpec('Triceps Pushdown', ['Cable Pushdown'], [12, 12, 12], 25, 0.3),
      _ExSpec('Lateral Raise', ['Side Raise'], [15, 15, 15], 8, 0.1),
      _ExSpec(
        'Deadlift',
        ['DL'],
        [5, 5, 5],
        100,
        2.0,
        notes: 'Reset each rep. Belt on the top set.',
        links: [
          _link('Technique article', 'https://en.wikipedia.org/wiki/Deadlift'),
          // Empty label: the UI should fall back to showing the URL.
          _link('', 'https://www.youtube.com/results?search_query=deadlift'),
        ],
      ),
      _ExSpec(
        'Barbell Row',
        ['Bent-over Row', 'BB Row'],
        [8, 8, 8, 8],
        50,
        1.0,
      ),
      _ExSpec('Pull-up', ['Chin-up', 'Pullups'], [8, 8, 8], 0, 0),
      _ExSpec('Lat Pulldown', [], [10, 10, 10], 45, 0.75),
      _ExSpec(
        'Dumbbell Curl',
        ['DB Curl', 'Bicep Curl'],
        [12, 12, 12],
        25,
        0.5,
        unit: 'lbs',
      ),
      _ExSpec('Squat', ['Back Squat'], [6, 6, 6, 6], 80, 2.0),
      _ExSpec('Romanian Deadlift', ['RDL'], [10, 10, 10], 60, 1.0),
      _ExSpec('Leg Press', [], [12, 12, 12], 120, 3.0),
      _ExSpec('Standing Calf Raise', ['Calves'], [15, 15, 15, 15], 40, 0.5),
      _ExSpec('Plank', [], [60, 60, 60], 0, 0, notes: 'Reps = seconds held.'),
      _ExSpec(
        "Farmer's Carry",
        ['Farmers Walk'],
        [1, 1],
        24,
        0,
        notes: 'Never logged and in no workout: empty-history edge case.',
      ),
    ];

    final ex = <String, _ExSpec>{};
    for (final s in specs) {
      await repos.exerciseRepo.insert(
        Exercise(
          id: s.id,
          name: s.name,
          aliases: s.aliases,
          notes: s.notes,
          setTemplate: SetTemplate(
            id: _uuid.v4(),
            sets: [
              for (final r in s.reps)
                SetChild(
                  id: _uuid.v4(),
                  reps: r,
                  weight: s.weightAt(0),
                  unit: s.unit,
                ),
            ],
          ),
          links: s.links,
        ),
      );
      ex[s.name] = s;
    }

    // ── Workouts ─────────────────────────────────────────────────────────────
    Workout workout(String name, List<String> exNames, [String? notes]) =>
        Workout(
          id: _uuid.v4(),
          name: name,
          exerciseIds: [for (final n in exNames) ex[n]!.id],
          notes: notes,
        );

    final push = workout('Push', [
      'Bench Press',
      'Overhead Press',
      'Incline Dumbbell Press',
      'Triceps Pushdown',
      'Lateral Raise',
    ]);
    final pull = workout('Pull', [
      'Deadlift',
      'Barbell Row',
      'Pull-up',
      'Lat Pulldown',
      'Dumbbell Curl',
    ]);
    final legs = workout('Legs', [
      'Squat',
      'Romanian Deadlift',
      'Leg Press',
      'Standing Calf Raise',
      'Plank',
    ]);
    final fullBody = workout('Full Body', [
      'Squat',
      'Bench Press',
      'Barbell Row',
      'Overhead Press',
      'Plank',
    ], 'Beginner phase, 3x per week.');
    final mobility = workout(
      'Mobility',
      [],
      'No exercises on purpose: empty-workout edge case.',
    );
    for (final w in [push, pull, legs, fullBody, mobility]) {
      await repos.workoutRepo.insert(w);
    }

    // ── Plans ────────────────────────────────────────────────────────────────
    WorkoutPlanEntry entry(Workout w, int day) =>
        WorkoutPlanEntry(id: _uuid.v4(), workoutId: w.id, dayOfWeek: day);

    final pplDays = {1: push, 2: pull, 3: legs, 4: push, 5: pull, 6: legs};
    final fullBodyDays = {1: fullBody, 3: fullBody, 5: fullBody};
    for (final plan in [
      WorkoutPlan(
        id: _uuid.v4(),
        name: 'Push / Pull / Legs',
        entries: [
          for (final e in pplDays.entries) entry(e.value, e.key),
          entry(mobility, 6),
        ],
      ),
      WorkoutPlan(
        id: _uuid.v4(),
        name: 'Full Body 3x',
        entries: [
          for (final e in fullBodyDays.entries) entry(e.value, e.key),
          entry(mobility, 7),
        ],
      ),
      WorkoutPlan(id: _uuid.v4(), name: 'Draft plan', entries: const []),
    ]) {
      await repos.planRepo.insert(plan);
    }

    // ── Training history ─────────────────────────────────────────────────────
    // Full Body 3x for the first ~8 months, then Push/Pull/Legs. Exercises
    // only in PPL therefore have ~6 months of history; Full Body ones ~14.
    // History rows are collected here and written in one batch at the end:
    // going through the repositories costs a transaction and a debug log per
    // row, which turns ~5000 inserts into a minute-long wait.
    const sessionNotes = [
      'Felt strong',
      'Short on time',
      'Gym was busy',
      'Bad sleep, kept it light',
    ];
    final sessions = <WorkoutSession>[];
    final logs = <ExerciseLog>[];
    final entries = <MeasurementEntry>[];
    for (var daysAgo = _historyDays; daysAgo >= 0; daysAgo--) {
      final day = today.subtract(Duration(days: daysAgo));
      final schedule = daysAgo > _phaseSwitchDaysAgo ? fullBodyDays : pplDays;
      // Always train today so the Day filter has data, even on a rest day.
      final w = schedule[day.weekday] ?? (daysAgo == 0 ? push : null);
      if (w == null) continue;
      if (daysAgo > 0 && rnd.nextDouble() < 0.15) continue; // missed session

      final at = DateTime(day.year, day.month, day.day, 18, rnd.nextInt(60));
      sessions.add(
        WorkoutSession(
          id: _uuid.v4(),
          workoutId: w.id,
          date: at,
          notes: rnd.nextDouble() < 0.1
              ? sessionNotes[rnd.nextInt(sessionNotes.length)]
              : null,
        ),
      );

      final weeks = (_historyDays - daysAgo) / 7;
      for (final id in w.exerciseIds) {
        final s = specs.firstWhere((s) => s.id == id);
        logs.add(_log(s, at, s.weightAt(weeks), rnd));
      }
    }

    // Second Bench Press log on the same day as an earlier one.
    final bench = ex['Bench Press']!;
    final sameDay = logs.reversed
        .firstWhere(
          (l) =>
              l.exerciseId == bench.id && today.difference(l.date).inDays >= 2,
        )
        .date
        .add(const Duration(hours: 2));
    logs.add(
      _log(
        bench,
        sameDay,
        bench.weightAt((_historyDays - today.difference(sameDay).inDays) / 7) *
            0.8,
        rnd,
        notes: 'Second session same day: tests aggregation.',
      ),
    );

    // ── Body measurements ────────────────────────────────────────────────────
    final measurements = await repos.measurementRepo.getAllMeasurements();
    final weight = measurements.firstWhere((m) => m.name == 'Weight');

    Future<Measurement> measurement(String name) async {
      final m = Measurement(id: _uuid.v4(), name: name);
      await repos.measurementRepo.insertMeasurement(m);
      return m;
    }

    void series(
      Measurement m,
      String unit,
      int everyDays,
      double from,
      double to,
      double noise,
    ) {
      for (var daysAgo = _historyDays; daysAgo >= 0; daysAgo -= everyDays) {
        final t = 1 - daysAgo / _historyDays;
        final v = from + (to - from) * t + (rnd.nextDouble() * 2 - 1) * noise;
        final d = today.subtract(Duration(days: daysAgo));
        entries.add(
          MeasurementEntry(
            id: _uuid.v4(),
            measurementId: m.id,
            value: double.parse(v.toStringAsFixed(1)),
            unit: unit,
            date: DateTime(d.year, d.month, d.day, 7, 30),
          ),
        );
      }
    }

    series(weight, 'kg', 3, 84, 78, 0.5);
    series(await measurement('Body Fat %'), '%', 7, 22, 17.5, 0.4);
    series(await measurement('Waist'), 'cm', 14, 90, 84, 0.6);
    series(await measurement('Chest'), 'cm', 30, 102, 105, 0.5);
    series(await measurement('Biceps'), 'cm', 30, 35, 37, 0.3);

    final thigh = await measurement('Thigh');
    final thighDay = today.subtract(const Duration(days: 10));
    entries.add(
      MeasurementEntry(
        id: _uuid.v4(),
        measurementId: thigh.id,
        value: 58,
        unit: 'cm',
        date: DateTime(thighDay.year, thighDay.month, thighDay.day, 7, 30),
      ),
    );
    await measurement('Neck');

    // ── Bulk write ───────────────────────────────────────────────────────────
    // Same rows the repositories' insert() methods write.
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final s in sessions) {
        batch.insert('workout_sessions', s.toMap());
      }
      for (final l in logs) {
        batch.insert('exercise_logs', l.toMap());
        for (final set in l.sets) {
          batch.insert('exercise_log_sets', set.toMap(logId: l.id));
        }
      }
      for (final e in entries) {
        batch.insert('measurement_entries', e.toMap());
      }
      await batch.commit(noResult: true);
    });

    log.i(
      '[SampleData] loaded ${specs.length} exercises, ${sessions.length} '
      'sessions, ${logs.length} logs, ${entries.length} measurement entries '
      'in ${sw.elapsedMilliseconds} ms',
    );
  }

  static ExerciseLog _log(
    _ExSpec s,
    DateTime at,
    double weight,
    Random rnd, {
    String? notes,
  }) {
    return ExerciseLog(
      id: _uuid.v4(),
      exerciseId: s.id,
      date: at,
      notes: notes,
      sets: [
        for (var i = 0; i < s.reps.length; i++)
          SetChild(
            id: _uuid.v4(),
            // Fatigue: the last set sometimes falls a rep or two short.
            reps: i == s.reps.length - 1 && rnd.nextDouble() < 0.4
                ? max(1, s.reps[i] - 1 - rnd.nextInt(2))
                : s.reps[i],
            weight: weight,
            unit: s.unit,
          ),
      ],
    );
  }

  static ExerciseLink _link(String label, String url) =>
      ExerciseLink(id: _uuid.v4(), label: label, url: url);
}

class _ExSpec {
  final String id = const Uuid().v4();
  final String name;
  final List<String> aliases;
  final List<int> reps;
  final double startWeight;
  final double weeklyGain;
  final String unit;
  final String? notes;
  final List<ExerciseLink> links;

  _ExSpec(
    this.name,
    this.aliases,
    this.reps,
    this.startWeight,
    this.weeklyGain, {
    this.unit = 'kg',
    this.notes,
    this.links = const [],
  });

  /// Linear progression with a 10% deload every 9th week, rounded to a
  /// plate-friendly step.
  double weightAt(double weeks) {
    if (startWeight == 0) return 0;
    var w = startWeight + weeklyGain * weeks;
    if (weeks.floor() % 9 == 8) w *= 0.9;
    final step = startWeight >= 40 ? 2.5 : 0.5;
    return (w / step).round() * step;
  }
}
