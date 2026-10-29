import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/workout.dart';
import 'package:workout_app/models/workout_plan.dart';
import 'package:workout_app/models/workout_plan_entry.dart';
import 'package:workout_app/screens/workouts/workout_plan_detail_screen.dart';

void main() {
  const push = Workout(id: 'push', name: 'Push', exerciseIds: []);
  const legs = Workout(id: 'legs', name: 'Legs', exerciseIds: []);
  const mobility = Workout(id: 'mob', name: 'Mobility', exerciseIds: []);
  final workouts = [push, legs, mobility];

  WorkoutPlanEntry e(String id, String wid, int day) =>
      WorkoutPlanEntry(id: id, workoutId: wid, dayOfWeek: day);

  group('planScheduleByDay', () {
    test('every day is present; unassigned days are empty (rest days)', () {
      final s = planScheduleByDay(
        const WorkoutPlan(id: 'p', name: 'Empty', entries: []),
        workouts,
      );
      expect(s.keys, [1, 2, 3, 4, 5, 6, 7]);
      expect(s.values.every((l) => l.isEmpty), isTrue);
    });

    test('groups workouts by day, keeping entry order within a day', () {
      final plan = WorkoutPlan(
        id: 'p',
        name: 'PPL',
        entries: [e('1', 'push', 1), e('2', 'legs', 6), e('3', 'mob', 6)],
      );
      final s = planScheduleByDay(plan, workouts);
      expect(s[1], [push]);
      expect(s[6], [legs, mobility]);
      expect(s[7], isEmpty);
    });

    test('skips entries whose workout was deleted', () {
      final plan = WorkoutPlan(
        id: 'p',
        name: 'X',
        entries: [e('1', 'gone', 2), e('2', 'push', 2)],
      );
      expect(planScheduleByDay(plan, workouts)[2], [push]);
    });
  });
}
