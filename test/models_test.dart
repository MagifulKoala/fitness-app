import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/exercise_link.dart';
import 'package:workout_app/models/exercise_log.dart';
import 'package:workout_app/models/measurement_entry.dart';
import 'package:workout_app/models/set_child.dart';
import 'package:workout_app/models/set_template.dart';
import 'package:workout_app/models/workout_plan_entry.dart';
import 'package:workout_app/models/workout_session.dart';

void main() {
  const sets = [
    SetChild(id: 's1', reps: 10, weight: 50, unit: 'kg'),
    SetChild(id: 's2', reps: 8, weight: 60, unit: 'kg'),
  ];

  group('volume and avg weight', () {
    test('SetTemplate.volume sums reps x weight', () {
      expect(const SetTemplate(id: 't', sets: sets).volume, 10 * 50 + 8 * 60);
    });

    test('ExerciseLog volume and avgWeight', () {
      final log = ExerciseLog(
          id: 'l', exerciseId: 'e', date: DateTime(2026, 1, 1), sets: sets);
      expect(log.volume, 980);
      expect(log.avgWeight, 55);
    });

    test('ExerciseLog with no sets is all zeros', () {
      final log = ExerciseLog(
          id: 'l', exerciseId: 'e', date: DateTime(2026, 1, 1), sets: const []);
      expect(log.volume, 0);
      expect(log.avgWeight, 0);
    });
  });

  group('toMap / fromMap round-trips', () {
    test('Exercise keeps aliases', () {
      const ex = Exercise(
        id: 'e',
        name: 'Bench Press',
        aliases: ['BP', 'Flat Bench'],
        notes: 'n',
        setTemplate: SetTemplate(id: 't', sets: sets),
        links: [ExerciseLink(id: 'k', label: 'L', url: 'https://x')],
      );
      final back = Exercise.fromMap(ex.toMap(), ex.setTemplate, ex.links);
      expect(back, ex);
    });

    test('Exercise with empty aliases string has no aliases', () {
      final ex = Exercise.fromMap(
        {'id': 'e', 'name': 'X', 'aliases': '', 'notes': null},
        const SetTemplate(id: 't', sets: []),
        const [],
      );
      expect(ex.aliases, isEmpty);
    });

    test('SetChild', () {
      final m = sets.first.toMap(logId: 'log');
      expect(m['log_id'], 'log');
      expect(m.containsKey('set_template_id'), isFalse);
      expect(SetChild.fromMap(m), sets.first);
    });

    test('ExerciseLink', () {
      const link = ExerciseLink(id: 'k', label: '', url: 'https://x');
      expect(
          ExerciseLink.fromMap(link.toMap(exerciseId: 'e', sortOrder: 0)), link);
    });

    test('ExerciseLog keeps date', () {
      final log = ExerciseLog(
          id: 'l',
          exerciseId: 'e',
          date: DateTime(2026, 3, 4, 18, 30),
          notes: 'n',
          sets: sets);
      expect(ExerciseLog.fromMap(log.toMap(), sets), log);
    });

    test('ExerciseLog keeps its workout; no workout stays null', () {
      final tagged = ExerciseLog(
          id: 'l',
          exerciseId: 'e',
          date: DateTime(2026, 3, 4),
          sets: sets,
          workoutId: 'w',
          workoutName: 'Push');
      final back = ExerciseLog.fromMap(tagged.toMap(), sets);
      expect(back, tagged);
      expect(back.workoutId, 'w');
      expect(back.workoutName, 'Push');

      final untagged = ExerciseLog(
          id: 'l', exerciseId: 'e', date: DateTime(2026, 3, 4), sets: sets);
      expect(ExerciseLog.fromMap(untagged.toMap(), sets).workoutId, isNull);
      expect(untagged, isNot(tagged));
    });

    test('MeasurementEntry', () {
      final e = MeasurementEntry(
          id: 'm1',
          measurementId: 'm',
          value: 80.5,
          unit: 'kg',
          date: DateTime(2026, 5, 6));
      expect(MeasurementEntry.fromMap(e.toMap()), e);
    });

    test('MeasurementEntry reads integer values from SQLite', () {
      final e = MeasurementEntry.fromMap({
        'id': 'm1',
        'measurement_id': 'm',
        'value': 80,
        'unit': 'kg',
        'date': '2026-05-06T00:00:00.000',
      });
      expect(e.value, 80.0);
    });

    test('WorkoutPlanEntry', () {
      const e = WorkoutPlanEntry(id: 'p1', workoutId: 'w', dayOfWeek: 7);
      expect(WorkoutPlanEntry.fromMap(e.toMap(planId: 'p')), e);
    });

    test('WorkoutSession', () {
      final s = WorkoutSession(
          id: 's', workoutId: 'w', date: DateTime(2026, 1, 2), notes: null);
      expect(WorkoutSession.fromMap(s.toMap()), s);
    });
  });
}
