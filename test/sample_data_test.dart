import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/dev/sample_data.dart';

import 'helpers/test_db.dart';

/// Guards the dev sample data: it must load against the current schema and
/// keep providing the edge cases listed in `SampleData`'s doc comment.
/// Extend this whenever the sample data gains a new feature (see CLAUDE.md,
/// Development Workflow).
void main() {
  useInMemoryDatabase();

  test('loads a full, consistent dataset with its edge cases', () async {
    final repos = testRepositories();
    await SampleData.load(repos);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Exercises
    final exercises = await repos.exerciseRepo.getAll();
    final byName = {for (final e in exercises) e.name: e};
    expect(exercises.length, greaterThanOrEqualTo(15));
    expect(byName['Deadlift']!.links, hasLength(2));
    expect(
      byName['Deadlift']!.links.any((l) => l.label.isEmpty),
      isTrue,
      reason: 'a link without a label',
    );
    expect(byName['Dumbbell Curl']!.setTemplate.sets.first.unit, 'lbs');

    // Logs
    final logs = await repos.exerciseLogRepo.getAll();
    expect(logs.length, greaterThan(500));
    final ids = byName.values.map((e) => e.id).toSet();
    expect(
      logs.every((l) => ids.contains(l.exerciseId)),
      isTrue,
      reason: 'every log points at an existing exercise',
    );
    expect(logs.every((l) => l.sets.isNotEmpty), isTrue);

    final logsOf = {
      for (final e in exercises)
        e.name: logs.where((l) => l.exerciseId == e.id).toList(),
    };
    expect(logsOf["Farmer's Carry"], isEmpty, reason: 'never-logged exercise');
    expect(
      logsOf['Pull-up']!.every((l) => l.avgWeight == 0),
      isTrue,
      reason: 'bodyweight exercise',
    );
    expect(
      logsOf['Dumbbell Curl']!.every((l) => l.sets.first.unit == 'lbs'),
      isTrue,
    );

    final benchDays = logsOf['Bench Press']!
        .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
        .toList();
    expect(
      benchDays.length,
      greaterThan(benchDays.toSet().length),
      reason: 'two Bench Press logs on the same day',
    );

    expect(
      logs.any((l) => !l.date.isBefore(today)),
      isTrue,
      reason: 'something logged today, for the Day filter',
    );
    expect(
      today.difference(logs.first.date).inDays,
      greaterThan(365),
      reason: 'history spans more than one Year window',
    );

    // Workouts, plans, sessions
    final workouts = await repos.workoutRepo.getAll();
    expect(
      workouts.any((w) => w.exerciseIds.isEmpty),
      isTrue,
      reason: 'empty workout',
    );
    final workoutIds = workouts.map((w) => w.id).toSet();
    for (final w in workouts) {
      expect(w.exerciseIds.every(ids.contains), isTrue);
    }

    final plans = await repos.planRepo.getAll();
    expect(plans.length, greaterThanOrEqualTo(2));
    expect(plans.any((p) => p.entries.isEmpty), isTrue, reason: 'empty plan');
    expect(
      plans.any(
        (p) => p.entries.any(
          (a) => p.entries.any((b) => a != b && a.dayOfWeek == b.dayOfWeek),
        ),
      ),
      isTrue,
      reason: 'a plan day with two workouts',
    );
    for (final p in plans) {
      expect(p.entries.every((e) => workoutIds.contains(e.workoutId)), isTrue);
      expect(
        p.entries.every((e) => e.dayOfWeek >= 1 && e.dayOfWeek <= 7),
        isTrue,
      );
    }

    final sessions = await repos.sessionRepo.getAll();
    expect(sessions, isNotEmpty);
    expect(sessions.every((s) => workoutIds.contains(s.workoutId)), isTrue);

    // Measurements
    final measurements = await repos.measurementRepo.getAllMeasurements();
    final mByName = {for (final m in measurements) m.name: m};
    expect(
      mByName.keys,
      containsAll(['Weight', 'Body Fat %', 'Waist', 'Thigh', 'Neck']),
    );
    expect(
      measurements.where((m) => m.name == 'Weight'),
      hasLength(1),
      reason: 'reuses the seeded Weight instead of duplicating it',
    );
    expect(
      await repos.measurementRepo.getEntries(mByName['Weight']!.id),
      hasLength(greaterThan(100)),
    );
    expect(
      await repos.measurementRepo.getEntries(mByName['Thigh']!.id),
      hasLength(1),
    );
    expect(
      await repos.measurementRepo.getEntries(mByName['Neck']!.id),
      isEmpty,
    );
  });

  test('loading twice replaces the data instead of duplicating it', () async {
    final repos = testRepositories();
    await SampleData.load(repos);
    final first = (await repos.exerciseLogRepo.getAll()).length;
    await SampleData.load(repos);
    expect((await repos.exerciseLogRepo.getAll()).length, first);
    expect(await repos.exerciseRepo.getAll(), hasLength(16));
  });
}
