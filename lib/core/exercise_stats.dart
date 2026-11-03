import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise.dart';
import '../models/exercise_log.dart';
import '../models/set_child.dart';
import '../models/workout.dart';

// Pure logic behind per-workout exercise stats: the stats card, the progress
// workout filter and the log sheet's starting sets. No widgets, so it can be
// unit-tested directly (test/exercise_stats_test.dart).

/// Which logs of an exercise to look at: all of them, only those with no
/// workout, or only those from one workout.
class WorkoutFilter extends Equatable {
  final bool isAll;

  /// The workout to match; null with [isAll] false means "No workout".
  final String? workoutId;

  const WorkoutFilter._(this.isAll, this.workoutId);

  static const all = WorkoutFilter._(true, null);
  static const none = WorkoutFilter._(false, null);
  const WorkoutFilter.workout(String id) : this._(false, id);

  bool matches(ExerciseLog log) => isAll || log.workoutId == workoutId;

  @override
  List<Object?> get props => [isAll, workoutId];
}

/// The name to show for a log's workout: the workout's current name while it
/// exists, otherwise the name stored on the log. Null if the log has none.
String? workoutLabel(ExerciseLog log, Map<String, Workout> workoutsById) {
  final id = log.workoutId;
  if (id == null) return null;
  return workoutsById[id]?.name ?? log.workoutName ?? 'Deleted workout';
}

/// One entry of the progress screen's workout dropdown.
class WorkoutFilterOption extends Equatable {
  final WorkoutFilter filter;
  final String label;
  final int count;
  final bool deleted;

  const WorkoutFilterOption({
    required this.filter,
    required this.label,
    required this.count,
    this.deleted = false,
  });

  @override
  List<Object?> get props => [filter, label, count, deleted];
}

/// Dropdown options for an exercise's logs: All workouts, then each workout it
/// was logged in (most recently used first), then No workout if any log has
/// none. [logs] may be in any order.
List<WorkoutFilterOption> workoutFilterOptions(
  List<ExerciseLog> logs,
  Map<String, Workout> workoutsById,
) {
  final counts = <String, int>{};
  final latest = <String, ExerciseLog>{};
  var untagged = 0;
  for (final l in logs) {
    final id = l.workoutId;
    if (id == null) {
      untagged++;
      continue;
    }
    counts[id] = (counts[id] ?? 0) + 1;
    final prev = latest[id];
    if (prev == null || l.date.isAfter(prev.date)) latest[id] = l;
  }
  final ids = counts.keys.toList()
    ..sort((a, b) => latest[b]!.date.compareTo(latest[a]!.date));
  return [
    WorkoutFilterOption(
        filter: WorkoutFilter.all, label: 'All workouts', count: logs.length),
    for (final id in ids)
      WorkoutFilterOption(
        filter: WorkoutFilter.workout(id),
        label: workoutLabel(latest[id]!, workoutsById)!,
        count: counts[id]!,
        deleted: !workoutsById.containsKey(id),
      ),
    if (untagged > 0)
      WorkoutFilterOption(
          filter: WorkoutFilter.none, label: 'No workout', count: untagged),
  ];
}

/// What the stats card shows for one exercise, either across all workouts or
/// within one.
class ExerciseStats extends Equatable {
  /// Logs matching the filter.
  final int count;

  /// Most recent matching log.
  final ExerciseLog? last;

  /// The log holding [bestSet].
  final ExerciseLog? bestLog;

  /// Heaviest single set; for bodyweight work (all weights 0) the set with the
  /// most reps.
  final SetChild? bestSet;

  /// Most recent log of this exercise outside the filter, shown as a hint when
  /// the filtered workout has no logs yet.
  final ExerciseLog? lastElsewhere;

  const ExerciseStats({
    required this.count,
    this.last,
    this.bestLog,
    this.bestSet,
    this.lastElsewhere,
  });

  bool get isBodyweight => bestSet != null && bestSet!.weight == 0;

  @override
  List<Object?> get props => [count, last, bestLog, bestSet, lastElsewhere];
}

ExerciseStats computeExerciseStats(
    List<ExerciseLog> logs, WorkoutFilter filter) {
  ExerciseLog? last;
  ExerciseLog? lastElsewhere;
  ExerciseLog? bestLog;
  SetChild? bestSet;
  var count = 0;
  for (final l in logs) {
    if (!filter.matches(l)) {
      if (lastElsewhere == null || l.date.isAfter(lastElsewhere.date)) {
        lastElsewhere = l;
      }
      continue;
    }
    count++;
    if (last == null || l.date.isAfter(last.date)) last = l;
    for (final s in l.sets) {
      if (bestSet == null || _better(s, bestSet)) {
        bestSet = s;
        bestLog = l;
      }
    }
  }
  return ExerciseStats(
    count: count,
    last: last,
    bestLog: bestLog,
    bestSet: bestSet,
    lastElsewhere: lastElsewhere,
  );
}

bool _better(SetChild a, SetChild b) =>
    a.weight > b.weight || (a.weight == b.weight && a.reps > b.reps);

/// The sets a new log starts with: a copy of the last log in [workoutId] if
/// there is one, otherwise the exercise's set template. Every set gets a fresh
/// id so repeated logs never collide.
List<SetChild> startingSets(
  Exercise exercise,
  List<ExerciseLog> logs,
  String? workoutId,
) {
  ExerciseLog? last;
  if (workoutId != null) {
    for (final l in logs) {
      if (l.workoutId == workoutId &&
          l.sets.isNotEmpty &&
          (last == null || l.date.isAfter(last.date))) {
        last = l;
      }
    }
  }
  const uuid = Uuid();
  return [
    for (final s in last?.sets ?? exercise.setTemplate.sets)
      SetChild(id: uuid.v4(), reps: s.reps, weight: s.weight, unit: s.unit),
  ];
}

/// `72.5`, `70` (no trailing `.0`).
String formatWeight(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toString();

/// Compact summary of a log's sets:
/// `4 × 8 @ 72.5 kg` when all sets match, `8/8/6 @ 72.5 kg` when only the
/// weight matches, otherwise `8×70, 6×75 kg`. Weight 0 reads as bodyweight.
String formatSets(List<SetChild> sets) {
  if (sets.isEmpty) return 'No sets';
  final unit = sets.first.unit;
  final sameWeight = sets.every((s) => s.weight == sets.first.weight);
  final sameReps = sets.every((s) => s.reps == sets.first.reps);
  if (sameWeight) {
    final reps = sameReps
        ? '${sets.length} × ${sets.first.reps}'
        : sets.map((s) => s.reps).join('/');
    final w = sets.first.weight;
    return w == 0 ? '$reps (bodyweight)' : '$reps @ ${formatWeight(w)} $unit';
  }
  return '${sets.map((s) => '${s.reps}×${formatWeight(s.weight)}').join(', ')} $unit';
}
