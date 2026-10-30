import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_app/db/database_helper.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/exercise_link.dart';
import 'package:workout_app/models/exercise_log.dart';
import 'package:workout_app/models/measurement.dart';
import 'package:workout_app/models/measurement_entry.dart';
import 'package:workout_app/models/set_child.dart';
import 'package:workout_app/models/set_template.dart';
import 'package:workout_app/models/workout.dart';
import 'package:workout_app/models/workout_plan.dart';
import 'package:workout_app/models/workout_plan_entry.dart';
import 'package:workout_app/models/workout_session.dart';
import 'package:workout_app/repositories/settings_repository.dart';

import 'helpers/test_db.dart';

Exercise _exercise(
  String id,
  String name, {
  List<SetChild> sets = const [],
  List<ExerciseLink> links = const [],
}) => Exercise(
  id: id,
  name: name,
  aliases: const ['alias'],
  setTemplate: SetTemplate(id: 't-$id', sets: sets),
  links: links,
);

ExerciseLog _log(String id, String exerciseId, DateTime date) => ExerciseLog(
  id: id,
  exerciseId: exerciseId,
  date: date,
  sets: [SetChild(id: 's-$id', reps: 5, weight: 100, unit: 'kg')],
);

void main() {
  useInMemoryDatabase();

  test('a fresh database seeds the default Weight measurement', () async {
    final repos = testRepositories();
    final ms = await repos.measurementRepo.getAllMeasurements();
    expect(ms.map((m) => m.name), ['Weight']);
  });

  group('ExerciseRepository', () {
    test('insert + getById round-trips sets and ordered links', () async {
      final repo = testRepositories().exerciseRepo;
      await repo.insert(
        _exercise(
          'e1',
          'Squat',
          sets: const [
            SetChild(id: 'a', reps: 5, weight: 100, unit: 'kg'),
            SetChild(id: 'b', reps: 3, weight: 110, unit: 'kg'),
          ],
          links: const [
            ExerciseLink(id: 'l1', label: 'First', url: 'https://1'),
            ExerciseLink(id: 'l2', label: '', url: 'https://2'),
          ],
        ),
      );

      final ex = (await repo.getById('e1'))!;
      expect(ex.name, 'Squat');
      expect(ex.aliases, ['alias']);
      expect(ex.setTemplate.sets.map((s) => s.reps), [5, 3]);
      expect(ex.links.map((l) => l.label), ['First', '']);
    });

    test('getAll sorts by name; search matches name and alias', () async {
      final repo = testRepositories().exerciseRepo;
      await repo.insert(_exercise('b', 'Bench'));
      await repo.insert(_exercise('a', 'Arnold Press'));
      expect((await repo.getAll()).map((e) => e.name), [
        'Arnold Press',
        'Bench',
      ]);
      expect((await repo.search('ench')).map((e) => e.id), ['b']);
      expect(await repo.search('alias'), hasLength(2));
    });

    test('update replaces sets and links', () async {
      final repo = testRepositories().exerciseRepo;
      await repo.insert(
        _exercise(
          'e',
          'Row',
          sets: const [SetChild(id: 'a', reps: 8, weight: 50, unit: 'kg')],
          links: const [ExerciseLink(id: 'l', label: 'x', url: 'https://x')],
        ),
      );
      final ex = (await repo.getById('e'))!;
      await repo.update(
        ex.copyWith(
          name: 'Barbell Row',
          setTemplate: ex.setTemplate.copyWith(
            sets: const [
              SetChild(id: 'c', reps: 6, weight: 60, unit: 'kg'),
              SetChild(id: 'd', reps: 6, weight: 60, unit: 'kg'),
            ],
          ),
          links: const [],
        ),
      );

      final updated = (await repo.getById('e'))!;
      expect(updated.name, 'Barbell Row');
      expect(updated.setTemplate.sets, hasLength(2));
      expect(updated.links, isEmpty);
    });

    test('delete removes the exercise, its logs and workout slots, '
        'and leaves other exercises alone', () async {
      final repos = testRepositories();
      final repo = repos.exerciseRepo;
      await repo.insert(
        _exercise(
          'e',
          'Curl',
          sets: const [SetChild(id: 'a', reps: 8, weight: 10, unit: 'kg')],
          links: const [ExerciseLink(id: 'l', label: 'x', url: 'https://x')],
        ),
      );
      await repo.insert(
        _exercise(
          'keep',
          'Squat',
          sets: const [SetChild(id: 'b', reps: 5, weight: 100, unit: 'kg')],
        ),
      );
      await repos.exerciseLogRepo.insert(_log('l1', 'e', DateTime(2026, 1, 1)));
      await repos.exerciseLogRepo.insert(_log('l2', 'e', DateTime(2026, 1, 2)));
      await repos.exerciseLogRepo.insert(
        _log('k1', 'keep', DateTime(2026, 1, 1)),
      );
      await repos.workoutRepo.insert(
        const Workout(id: 'w', name: 'Arms', exerciseIds: ['e', 'keep']),
      );
      await repo.addAlternative('e', 'keep');

      await repo.delete('e');

      expect(await repo.getById('e'), isNull);
      expect(await repos.exerciseLogRepo.getByExerciseId('e'), isEmpty);
      expect((await repos.workoutRepo.getById('w'))!.exerciseIds, ['keep']);

      // No orphaned rows anywhere.
      final db = await DatabaseHelper.instance.database;
      Future<int> count(String sql) async =>
          (await db.rawQuery(sql)).first.values.first as int;
      expect(
        await count(
          "SELECT COUNT(*) FROM exercise_log_sets "
          "WHERE log_id IN ('l1','l2')",
        ),
        0,
      );
      expect(
        await count(
          'SELECT COUNT(*) FROM set_children WHERE '
          'set_template_id NOT IN (SELECT id FROM set_templates)',
        ),
        0,
      );
      expect(
        await count(
          "SELECT COUNT(*) FROM exercise_links "
          "WHERE exercise_id = 'e'",
        ),
        0,
      );
      expect(await count('SELECT COUNT(*) FROM exercise_alternatives'), 0);
      expect(await repo.getAlternatives('keep'), isEmpty);

      // The other exercise is untouched.
      final kept = (await repo.getById('keep'))!;
      expect(kept.setTemplate.sets, hasLength(1));
      expect(await repos.exerciseLogRepo.getByExerciseId('keep'), hasLength(1));
    });
  });

  group('Exercise alternatives', () {
    Future<List<String>> altNames(String id) async => [
      for (final e in await testRepositories().exerciseRepo.getAlternatives(id))
        e.name,
    ];

    Future<void> seed() async {
      final repo = testRepositories().exerciseRepo;
      // Ids deliberately not in name order, to exercise the pair ordering.
      await repo.insert(_exercise('z', 'Squat'));
      await repo.insert(_exercise('m', 'Smith Squat'));
      await repo.insert(_exercise('a', 'Leg Press'));
      await repo.insert(_exercise('q', 'Hack Squat'));
    }

    test('a link shows up on both exercises', () async {
      await seed();
      final repo = testRepositories().exerciseRepo;
      await repo.addAlternative('z', 'm');

      expect(await altNames('z'), ['Smith Squat']);
      expect(await altNames('m'), ['Squat']);
    });

    test('linking twice, either way round, or to itself is a no-op', () async {
      await seed();
      final repo = testRepositories().exerciseRepo;
      await repo.addAlternative('z', 'm');
      await repo.addAlternative('m', 'z');
      await repo.addAlternative('z', 'z');

      expect(await repo.getAllAlternativePairs(), hasLength(1));
      expect(await altNames('z'), ['Smith Squat']);
    });

    test('links are not transitive; results are sorted by name', () async {
      await seed();
      final repo = testRepositories().exerciseRepo;
      await repo.addAlternative('m', 'z');
      await repo.addAlternative('m', 'a');

      expect(await altNames('m'), ['Leg Press', 'Squat']);
      expect(await altNames('z'), ['Smith Squat']);
      expect(await altNames('a'), ['Smith Squat']);
    });

    test('remove works from either side', () async {
      await seed();
      final repo = testRepositories().exerciseRepo;
      await repo.addAlternative('z', 'm');
      await repo.removeAlternative('m', 'z');

      expect(await altNames('z'), isEmpty);
      expect(await altNames('m'), isEmpty);
    });

    test(
      'setAlternatives replaces the list and updates the other side',
      () async {
        await seed();
        final repo = testRepositories().exerciseRepo;
        await repo.setAlternatives('z', ['m', 'a']);
        expect(await altNames('z'), ['Leg Press', 'Smith Squat']);
        expect(await altNames('a'), ['Squat']);

        // Unlinked exercises lose the back-link; links not involving z stay.
        await repo.addAlternative('a', 'q');
        await repo.setAlternatives('z', ['q', 'z']);
        expect(await altNames('z'), ['Hack Squat']);
        expect(await altNames('m'), isEmpty);
        expect(await altNames('a'), ['Hack Squat']);
        expect(await altNames('q'), ['Leg Press', 'Squat']);
      },
    );

    test('upgrading a v3 database adds the alternatives table', () async {
      final dir = await Directory.systemTemp.createTemp('workout_db');
      final path = '${dir.path}/v3.db';
      try {
        // A database as an older app version (schema v3) left it.
        final old = await openDatabase(
          path,
          version: 3,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE exercises (id TEXT PRIMARY KEY, '
              'name TEXT NOT NULL, aliases TEXT, notes TEXT)',
            );
          },
        );
        await old.close();

        DatabaseHelper.pathOverride = path;
        await DatabaseHelper.resetForTesting();
        final db = await DatabaseHelper.instance.database;
        expect(await db.getVersion(), 4);

        final repo = testRepositories().exerciseRepo;
        await repo.addAlternative('x', 'y');
        expect(await repo.getAllAlternativePairs(), [('x', 'y')]);
      } finally {
        await DatabaseHelper.resetForTesting();
        DatabaseHelper.pathOverride = inMemoryDatabasePath;
        await dir.delete(recursive: true);
      }
    });
  });

  group('ExerciseLogRepository', () {
    test('insert, query by exercise and date range', () async {
      final repos = testRepositories();
      await repos.exerciseRepo.insert(_exercise('e', 'Squat'));
      final repo = repos.exerciseLogRepo;
      await repo.insert(_log('l1', 'e', DateTime(2026, 1, 1, 18)));
      await repo.insert(_log('l2', 'e', DateTime(2026, 1, 10, 18)));
      await repo.insert(_log('l3', 'e', DateTime(2026, 2, 1, 18)));

      final all = await repo.getByExerciseId('e');
      expect(all, hasLength(3));
      expect(all.first.sets.single.weight, 100);

      // `to` is inclusive of the whole day.
      final jan = await repo.getByDateRange(
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 10),
      );
      expect(jan.map((l) => l.id), ['l1', 'l2']);

      expect(
        await repo.getByDateRange(DateTime(2030, 1, 1), DateTime(2030, 1, 2)),
        isEmpty,
      );
    });

    test('logging the same sets twice does not collide', () async {
      final repo = testRepositories().exerciseLogRepo;
      await repo.insert(_log('l1', 'e', DateTime(2026, 1, 1)));
      await repo.insert(_log('l2', 'e', DateTime(2026, 1, 1)));
      expect(await repo.getAll(), hasLength(2));
    });

    test('update replaces sets; delete removes the log', () async {
      final repo = testRepositories().exerciseLogRepo;
      final log = _log('l', 'e', DateTime(2026, 1, 1));
      await repo.insert(log);
      await repo.update(
        ExerciseLog(
          id: 'l',
          exerciseId: 'e',
          date: log.date,
          notes: 'edited',
          sets: const [
            SetChild(id: 'x', reps: 3, weight: 120, unit: 'kg'),
            SetChild(id: 'y', reps: 3, weight: 120, unit: 'kg'),
          ],
        ),
      );
      final updated = (await repo.getAll()).single;
      expect(updated.notes, 'edited');
      expect(updated.sets, hasLength(2));

      await repo.delete('l');
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('WorkoutRepository and WorkoutPlanRepository', () {
    test('workout keeps exercise order; update and delete', () async {
      final repo = testRepositories().workoutRepo;
      await repo.insert(
        const Workout(id: 'w', name: 'Push', exerciseIds: ['c', 'a', 'b']),
      );
      expect((await repo.getById('w'))!.exerciseIds, ['c', 'a', 'b']);

      await repo.update(
        const Workout(id: 'w', name: 'Push', exerciseIds: ['a']),
      );
      expect((await repo.getById('w'))!.exerciseIds, ['a']);

      await repo.delete('w');
      expect(await repo.getAll(), isEmpty);
    });

    test('reordering exercises persists the new order', () async {
      final repo = testRepositories().workoutRepo;
      const w = Workout(
        id: 'w',
        name: 'Legs',
        exerciseIds: ['a', 'b', 'c', 'd'],
      );
      await repo.insert(w);

      // Drag 'd' to the top, then 'a' (now 2nd) to the bottom.
      await repo.update(w.copyWith(exerciseIds: ['d', 'a', 'b', 'c']));
      await repo.update(w.copyWith(exerciseIds: ['d', 'b', 'c', 'a']));

      expect((await repo.getById('w'))!.exerciseIds, ['d', 'b', 'c', 'a']);
      expect((await repo.getAll()).single.exerciseIds, ['d', 'b', 'c', 'a']);
    });

    test('plan keeps entries; delete removes them', () async {
      final repo = testRepositories().planRepo;
      await repo.insert(
        const WorkoutPlan(
          id: 'p',
          name: 'PPL',
          entries: [
            WorkoutPlanEntry(id: 'e1', workoutId: 'w1', dayOfWeek: 1),
            WorkoutPlanEntry(id: 'e2', workoutId: 'w2', dayOfWeek: 3),
          ],
        ),
      );
      final plan = (await repo.getById('p'))!;
      expect(plan.entries.map((e) => e.dayOfWeek), containsAll([1, 3]));

      await repo.delete('p');
      expect(await repo.getById('p'), isNull);
    });
  });

  test('WorkoutSessionRepository returns newest first', () async {
    final repo = testRepositories().sessionRepo;
    await repo.insert(
      WorkoutSession(id: 'a', workoutId: 'w', date: DateTime(2026, 1, 1)),
    );
    await repo.insert(
      WorkoutSession(id: 'b', workoutId: 'w', date: DateTime(2026, 2, 1)),
    );
    await repo.insert(
      WorkoutSession(id: 'c', workoutId: 'x', date: DateTime(2026, 3, 1)),
    );
    expect((await repo.getAll()).map((s) => s.id), ['c', 'b', 'a']);
    expect((await repo.getByWorkoutId('w')).map((s) => s.id), ['b', 'a']);
  });

  group('MeasurementRepository', () {
    test('entries CRUD and cascade on measurement delete', () async {
      final repo = testRepositories().measurementRepo;
      const m = Measurement(id: 'm', name: 'Waist');
      await repo.insertMeasurement(m);
      final entry = MeasurementEntry(
        id: 'e',
        measurementId: 'm',
        value: 90,
        unit: 'cm',
        date: DateTime(2026),
      );
      await repo.insertEntry(entry);
      await repo.updateEntry(entry.copyWith(value: 88.5));
      expect((await repo.getEntries('m')).single.value, 88.5);

      await repo.deleteMeasurement('m');
      expect(await repo.getEntries('m'), isEmpty);
      expect((await repo.getAllMeasurements()).map((x) => x.name), ['Weight']);
    });
  });

  group('clearAll', () {
    test('wipes data, re-seeds Weight, keeps app settings', () async {
      final repos = testRepositories();
      final settings = SettingsRepository(DatabaseHelper.instance);
      await settings.setThemeMode(ThemeMode.dark);
      await repos.exerciseRepo.insert(_exercise('e', 'Squat'));
      await repos.exerciseLogRepo.insert(_log('l', 'e', DateTime(2026)));
      await repos.exerciseRepo.insert(_exercise('f', 'Leg Press'));
      await repos.exerciseRepo.addAlternative('e', 'f');

      await DatabaseHelper.instance.clearAll();

      expect(await repos.exerciseRepo.getAll(), isEmpty);
      expect(await repos.exerciseLogRepo.getAll(), isEmpty);
      expect(await repos.exerciseRepo.getAllAlternativePairs(), isEmpty);
      expect(
        (await repos.measurementRepo.getAllMeasurements()).single.name,
        'Weight',
      );
      expect(await settings.getThemeMode(), ThemeMode.dark);
    });
  });

  test('SettingsRepository round-trips backup settings', () async {
    final settings = SettingsRepository(DatabaseHelper.instance);
    expect(await settings.getThemeMode(), ThemeMode.light);
    expect(await settings.getBackupFolderPath(), isNull);

    await settings.setBackupFolderPath('/backups');
    final ts = DateTime(2026, 10, 29, 12, 30);
    await settings.setBackupLastTimestamp(ts);
    expect(await settings.getBackupFolderPath(), '/backups');
    expect(await settings.getBackupLastTimestamp(), ts);

    await settings.setBackupFolderPath(null);
    expect(await settings.getBackupFolderPath(), isNull);
  });
}
