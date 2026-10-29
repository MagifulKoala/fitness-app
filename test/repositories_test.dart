import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Exercise _exercise(String id, String name,
        {List<SetChild> sets = const [], List<ExerciseLink> links = const []}) =>
    Exercise(
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
      await repo.insert(_exercise('e1', 'Squat', sets: const [
        SetChild(id: 'a', reps: 5, weight: 100, unit: 'kg'),
        SetChild(id: 'b', reps: 3, weight: 110, unit: 'kg'),
      ], links: const [
        ExerciseLink(id: 'l1', label: 'First', url: 'https://1'),
        ExerciseLink(id: 'l2', label: '', url: 'https://2'),
      ]));

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
      expect((await repo.getAll()).map((e) => e.name), ['Arnold Press', 'Bench']);
      expect((await repo.search('ench')).map((e) => e.id), ['b']);
      expect(await repo.search('alias'), hasLength(2));
    });

    test('update replaces sets and links', () async {
      final repo = testRepositories().exerciseRepo;
      await repo.insert(_exercise('e', 'Row',
          sets: const [SetChild(id: 'a', reps: 8, weight: 50, unit: 'kg')],
          links: const [ExerciseLink(id: 'l', label: 'x', url: 'https://x')]));
      final ex = (await repo.getById('e'))!;
      await repo.update(ex.copyWith(
        name: 'Barbell Row',
        setTemplate: ex.setTemplate.copyWith(sets: const [
          SetChild(id: 'c', reps: 6, weight: 60, unit: 'kg'),
          SetChild(id: 'd', reps: 6, weight: 60, unit: 'kg'),
        ]),
        links: const [],
      ));

      final updated = (await repo.getById('e'))!;
      expect(updated.name, 'Barbell Row');
      expect(updated.setTemplate.sets, hasLength(2));
      expect(updated.links, isEmpty);
    });

    test('delete removes the exercise', () async {
      final repo = testRepositories().exerciseRepo;
      await repo.insert(_exercise('e', 'Curl'));
      await repo.delete('e');
      expect(await repo.getById('e'), isNull);
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
          DateTime(2026, 1, 1), DateTime(2026, 1, 10));
      expect(jan.map((l) => l.id), ['l1', 'l2']);

      expect(
          await repo.getByDateRange(DateTime(2030, 1, 1), DateTime(2030, 1, 2)),
          isEmpty);
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
      await repo.update(ExerciseLog(
        id: 'l',
        exerciseId: 'e',
        date: log.date,
        notes: 'edited',
        sets: const [
          SetChild(id: 'x', reps: 3, weight: 120, unit: 'kg'),
          SetChild(id: 'y', reps: 3, weight: 120, unit: 'kg'),
        ],
      ));
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
      await repo.insert(const Workout(
          id: 'w', name: 'Push', exerciseIds: ['c', 'a', 'b']));
      expect((await repo.getById('w'))!.exerciseIds, ['c', 'a', 'b']);

      await repo.update(const Workout(id: 'w', name: 'Push', exerciseIds: ['a']));
      expect((await repo.getById('w'))!.exerciseIds, ['a']);

      await repo.delete('w');
      expect(await repo.getAll(), isEmpty);
    });

    test('plan keeps entries; delete removes them', () async {
      final repo = testRepositories().planRepo;
      await repo.insert(const WorkoutPlan(id: 'p', name: 'PPL', entries: [
        WorkoutPlanEntry(id: 'e1', workoutId: 'w1', dayOfWeek: 1),
        WorkoutPlanEntry(id: 'e2', workoutId: 'w2', dayOfWeek: 3),
      ]));
      final plan = (await repo.getById('p'))!;
      expect(plan.entries.map((e) => e.dayOfWeek), containsAll([1, 3]));

      await repo.delete('p');
      expect(await repo.getById('p'), isNull);
    });
  });

  test('WorkoutSessionRepository returns newest first', () async {
    final repo = testRepositories().sessionRepo;
    await repo.insert(WorkoutSession(id: 'a', workoutId: 'w', date: DateTime(2026, 1, 1)));
    await repo.insert(WorkoutSession(id: 'b', workoutId: 'w', date: DateTime(2026, 2, 1)));
    await repo.insert(WorkoutSession(id: 'c', workoutId: 'x', date: DateTime(2026, 3, 1)));
    expect((await repo.getAll()).map((s) => s.id), ['c', 'b', 'a']);
    expect((await repo.getByWorkoutId('w')).map((s) => s.id), ['b', 'a']);
  });

  group('MeasurementRepository', () {
    test('entries CRUD and cascade on measurement delete', () async {
      final repo = testRepositories().measurementRepo;
      const m = Measurement(id: 'm', name: 'Waist');
      await repo.insertMeasurement(m);
      final entry = MeasurementEntry(
          id: 'e', measurementId: 'm', value: 90, unit: 'cm', date: DateTime(2026));
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

      await DatabaseHelper.instance.clearAll();

      expect(await repos.exerciseRepo.getAll(), isEmpty);
      expect(await repos.exerciseLogRepo.getAll(), isEmpty);
      expect((await repos.measurementRepo.getAllMeasurements()).single.name,
          'Weight');
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
