import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/exercise_stats.dart';
import '../models/exercise_log.dart';
import '../models/workout.dart';

/// Summary of an exercise's history at the top of `ExerciseDetailScreen`.
///
/// With a [workout] it covers only logs from that workout ("IN PUSH");
/// without one it covers every log ("ALL WORKOUTS") and names the workout
/// each value came from.
class ExerciseStatsCard extends StatelessWidget {
  final List<ExerciseLog> logs;
  final Workout? workout;
  final Map<String, Workout> workoutsById;

  /// Opens the progress screen; hidden when null or there are no logs.
  final VoidCallback? onSeeProgress;

  const ExerciseStatsCard({
    super.key,
    required this.logs,
    required this.workout,
    required this.workoutsById,
    this.onSeeProgress,
  });

  static final _date = DateFormat('dd/MM/yy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = workout;
    final stats = computeExerciseStats(
        logs, w == null ? WorkoutFilter.all : WorkoutFilter.workout(w.id));
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    // " · Push" after a value, only in the all-workouts view.
    String from(ExerciseLog? l) {
      if (w != null || l == null) return '';
      final name = workoutLabel(l, workoutsById);
      return name == null ? '' : ' · $name';
    }

    final children = <Widget>[
      Text(
        w == null ? 'ALL WORKOUTS' : 'IN ${w.name.toUpperCase()}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 8),
    ];

    if (stats.count == 0) {
      children.add(Text(w == null
          ? 'Not logged yet.'
          : 'No logs in ${w.name} yet.'));
      final other = stats.lastElsewhere;
      if (other != null) {
        final where = workoutLabel(other, workoutsById);
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${where == null ? 'Last done' : 'Last done in $where'} '
            '(${_date.format(other.date)}): ${formatSets(other.sets)}',
            style: muted,
          ),
        ));
      }
    } else {
      final last = stats.last!;
      final best = stats.bestSet!;
      children.addAll([
        _row(context, 'Last', '${_date.format(last.date)}${from(last)}',
            sub: formatSets(last.sets)),
        _row(
          context,
          'Best',
          (stats.isBodyweight
                  ? '${best.reps} reps'
                  : '${formatWeight(best.weight)} ${best.unit}') +
              from(stats.bestLog),
        ),
        _row(context, 'Logged',
            '${stats.count} time${stats.count == 1 ? '' : 's'}'),
      ]);
    }

    if (onSeeProgress != null && logs.isNotEmpty) {
      children.add(Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onSeeProgress,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('See progress'),
        ),
      ));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {String? sub}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.bodyMedium),
                if (sub != null)
                  Text(sub,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
