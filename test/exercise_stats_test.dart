import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/core/exercise_stats.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/exercise_log.dart';
import 'package:workout_app/models/set_child.dart';
import 'package:workout_app/models/set_template.dart';
import 'package:workout_app/models/workout.dart';
import 'package:workout_app/widgets/exercise_stats_card.dart';

SetChild _set(int reps, double weight, [String unit = 'kg']) =>
    SetChild(id: 's$reps-$weight', reps: reps, weight: weight, unit: unit);

ExerciseLog _log(
  String id,
  DateTime date,
  List<SetChild> sets, {
  String? workoutId,
  String? workoutName,
}) => ExerciseLog(
  id: id,
  exerciseId: 'e',
  date: date,
  sets: sets,
  workoutId: workoutId,
  workoutName: workoutName,
);

const _push = Workout(id: 'push', name: 'Push', exerciseIds: ['e']);
const _upper = Workout(id: 'upper', name: 'Upper', exerciseIds: ['e']);
final _workouts = {'push': _push, 'upper': _upper};

// Leg-extension style history: heavy when fresh (Upper), light after
// squats (Push), a deleted Rehab workout, and one untagged old log.
final _logs = [
  _log('old', DateTime(2026, 1, 1), [_set(10, 40)]),
  _log('u1', DateTime(2026, 2, 1), [_set(10, 80), _set(10, 80)],
      workoutId: 'upper', workoutName: 'Upper'),
  _log('p1', DateTime(2026, 3, 1), [_set(10, 20), _set(8, 22.5)],
      workoutId: 'push', workoutName: 'Push'),
  _log('r1', DateTime(2026, 4, 1), [_set(12, 5)],
      workoutId: 'rehab', workoutName: 'Rehab'),
  _log('p2', DateTime(2026, 5, 1), [_set(10, 25), _set(10, 25), _set(10, 25)],
      workoutId: 'push', workoutName: 'Old Push name'),
];

void main() {
  group('WorkoutFilter', () {
    test('all / none / one workout', () {
      expect(_logs.where(WorkoutFilter.all.matches), hasLength(5));
      expect(_logs.where(WorkoutFilter.none.matches).map((l) => l.id), ['old']);
      expect(
        _logs.where(const WorkoutFilter.workout('push').matches).map((l) => l.id),
        ['p1', 'p2'],
      );
      expect(const WorkoutFilter.workout('push'),
          const WorkoutFilter.workout('push'));
      expect(WorkoutFilter.all, isNot(WorkoutFilter.none));
    });
  });

  test('workoutLabel prefers the current name, then the stored one', () {
    expect(workoutLabel(_logs[4], _workouts), 'Push', reason: 'renamed');
    expect(workoutLabel(_logs[3], _workouts), 'Rehab', reason: 'deleted');
    expect(workoutLabel(_logs[0], _workouts), isNull);
    expect(
      workoutLabel(_log('x', DateTime(2026), [], workoutId: 'gone'), {}),
      'Deleted workout',
    );
  });

  group('workoutFilterOptions', () {
    test('All first, workouts by most recent use, No workout last', () {
      final options = workoutFilterOptions(_logs, _workouts);
      expect(options.map((o) => o.label),
          ['All workouts', 'Push', 'Rehab', 'Upper', 'No workout']);
      expect(options.map((o) => o.count), [5, 2, 1, 1, 1]);
      expect(options.firstWhere((o) => o.label == 'Rehab').deleted, isTrue);
      expect(options.firstWhere((o) => o.label == 'Push').deleted, isFalse);
      expect(options.last.filter, WorkoutFilter.none);
    });

    test('no "No workout" entry when every log is tagged; empty history', () {
      final tagged = _logs.where((l) => l.workoutId != null).toList();
      expect(workoutFilterOptions(tagged, _workouts).map((o) => o.label),
          isNot(contains('No workout')));
      final empty = workoutFilterOptions([], _workouts);
      expect(empty.single.label, 'All workouts');
      expect(empty.single.count, 0);
    });
  });

  group('computeExerciseStats', () {
    test('within one workout', () {
      final s = computeExerciseStats(_logs, const WorkoutFilter.workout('push'));
      expect(s.count, 2);
      expect(s.last!.id, 'p2');
      expect(s.bestSet!.weight, 25);
      expect(s.bestLog!.id, 'p2');
      expect(s.lastElsewhere!.id, 'r1');
    });

    test('across all workouts the best can come from another workout', () {
      final s = computeExerciseStats(_logs, WorkoutFilter.all);
      expect(s.count, 5);
      expect(s.last!.id, 'p2');
      expect(s.bestSet!.weight, 80);
      expect(s.bestLog!.workoutId, 'upper');
      expect(s.lastElsewhere, isNull);
    });

    test('first time in a workout: no stats, hint from elsewhere', () {
      final s =
          computeExerciseStats(_logs, const WorkoutFilter.workout('legs'));
      expect(s.count, 0);
      expect(s.last, isNull);
      expect(s.bestSet, isNull);
      expect(s.lastElsewhere!.id, 'p2');
    });

    test('bodyweight: best is the set with the most reps', () {
      final s = computeExerciseStats([
        _log('a', DateTime(2026, 1, 1), [_set(8, 0), _set(12, 0)]),
        _log('b', DateTime(2026, 1, 2), [_set(10, 0)]),
      ], WorkoutFilter.all);
      expect(s.isBodyweight, isTrue);
      expect(s.bestSet!.reps, 12);
    });

    test('never logged', () {
      final s = computeExerciseStats([], WorkoutFilter.all);
      expect(s.count, 0);
      expect(s.last, isNull);
      expect(s.lastElsewhere, isNull);
    });
  });

  group('startingSets', () {
    final exercise = Exercise(
      id: 'e',
      name: 'Leg Extension',
      aliases: const [],
      links: const [],
      setTemplate: SetTemplate(id: 't', sets: [_set(12, 30), _set(12, 30)]),
    );

    test('copies the last log in the workout, with fresh ids', () {
      final sets = startingSets(exercise, _logs, 'push');
      expect(sets.map((s) => (s.reps, s.weight)),
          [(10, 25.0), (10, 25.0), (10, 25.0)]);
      final previousIds = _logs[4].sets.map((s) => s.id).toSet();
      expect(sets.any((s) => previousIds.contains(s.id)), isFalse);
      expect(sets.map((s) => s.id).toSet(), hasLength(3));
    });

    test('falls back to the template: no workout, or none logged in it', () {
      for (final id in [null, 'legs']) {
        final sets = startingSets(exercise, _logs, id);
        expect(sets.map((s) => (s.reps, s.weight)), [(12, 30.0), (12, 30.0)]);
        expect(sets.first.id, isNot('s12-30.0'));
      }
    });

    test('ignores logs with no sets', () {
      final logs = [
        ..._logs,
        _log('empty', DateTime(2026, 6, 1), [], workoutId: 'push'),
      ];
      expect(startingSets(exercise, logs, 'push'), hasLength(3));
    });
  });

  group('formatSets', () {
    test('uniform, same weight, mixed, bodyweight, empty', () {
      expect(formatSets([_set(10, 25), _set(10, 25), _set(10, 25)]),
          '3 × 10 @ 25 kg');
      expect(formatSets([_set(8, 72.5), _set(8, 72.5), _set(6, 72.5)]),
          '8/8/6 @ 72.5 kg');
      expect(formatSets([_set(8, 70), _set(6, 75)]), '8×70, 6×75 kg');
      expect(formatSets([_set(12, 25, 'lbs')]), '1 × 12 @ 25 lbs');
      expect(formatSets([_set(8, 0), _set(8, 0)]), '2 × 8 (bodyweight)');
      expect(formatSets([]), 'No sets');
    });

    test('formatWeight drops a trailing .0', () {
      expect(formatWeight(70), '70');
      expect(formatWeight(72.5), '72.5');
    });
  });

  group('ExerciseStatsCard', () {
    Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
          MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card))),
        );

    testWidgets('in a workout: only that workout', (tester) async {
      await pump(
        tester,
        ExerciseStatsCard(
          logs: _logs,
          workout: _push,
          workoutsById: _workouts,
          onSeeProgress: () {},
        ),
      );
      expect(find.text('IN PUSH'), findsOneWidget);
      expect(find.text('3 × 10 @ 25 kg'), findsOneWidget);
      expect(find.text('25 kg'), findsOneWidget);
      expect(find.text('2 times'), findsOneWidget);
      expect(find.text('See progress'), findsOneWidget);
    });

    testWidgets('all workouts names where each value came from',
        (tester) async {
      await pump(
        tester,
        ExerciseStatsCard(logs: _logs, workout: null, workoutsById: _workouts),
      );
      expect(find.text('ALL WORKOUTS'), findsOneWidget);
      expect(find.text('01/05/26 · Push'), findsOneWidget);
      expect(find.text('80 kg · Upper'), findsOneWidget);
      expect(find.text('5 times'), findsOneWidget);
      expect(find.text('See progress'), findsNothing, reason: 'no callback');
    });

    testWidgets('first time in a workout shows a hint', (tester) async {
      const legs = Workout(id: 'legs', name: 'Legs', exerciseIds: ['e']);
      await pump(
        tester,
        ExerciseStatsCard(
          logs: _logs,
          workout: legs,
          workoutsById: {..._workouts, 'legs': legs},
        ),
      );
      expect(find.text('No logs in Legs yet.'), findsOneWidget);
      expect(
        find.text('Last done in Push (01/05/26): 3 × 10 @ 25 kg'),
        findsOneWidget,
      );
    });

    testWidgets('never logged', (tester) async {
      await pump(
        tester,
        ExerciseStatsCard(
          logs: const [],
          workout: null,
          workoutsById: _workouts,
          onSeeProgress: () {},
        ),
      );
      expect(find.text('Not logged yet.'), findsOneWidget);
      expect(find.text('See progress'), findsNothing);
    });
  });
}
