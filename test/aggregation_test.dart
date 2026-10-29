import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/exercise_log.dart';
import 'package:workout_app/models/measurement_entry.dart';
import 'package:workout_app/models/set_child.dart';
import 'package:workout_app/screens/progress/exercise_progress_screen.dart';
import 'package:workout_app/screens/progress/measurement_progress_screen.dart';
import 'package:workout_app/widgets/chart_filter_bar.dart';

ExerciseLog _log(DateTime date, double weight, {int reps = 10}) => ExerciseLog(
      id: '$date-$weight',
      exerciseId: 'e',
      date: date,
      sets: [SetChild(id: 's', reps: reps, weight: weight, unit: 'kg')],
    );

MeasurementEntry _entry(DateTime date, double value) => MeasurementEntry(
    id: '$date', measurementId: 'm', value: value, unit: 'kg', date: date);

void main() {
  group('aggregateLogs', () {
    final logs = [
      _log(DateTime(2026, 1, 5, 9), 50), // Monday
      _log(DateTime(2026, 1, 5, 18), 70), // same day
      _log(DateTime(2026, 1, 7), 60), // same week
      _log(DateTime(2026, 2, 2), 80), // next month
    ];

    test('raw keeps one point per log', () {
      final points = aggregateLogs(logs, ChartGranularity.raw);
      expect(points, hasLength(4));
      expect(points.first.volume, 500);
    });

    test('day: averages weight and sums volume within a day', () {
      final points = aggregateLogs(logs, ChartGranularity.day);
      expect(points, hasLength(3));
      expect(points.first.avgWeight, 60);
      expect(points.first.volume, 500 + 700);
    });

    test('week and month group further', () {
      expect(aggregateLogs(logs, ChartGranularity.week), hasLength(2));
      final months = aggregateLogs(logs, ChartGranularity.month);
      expect(months, hasLength(2));
      expect(months.first.volume, 500 + 700 + 600);
      expect(months.last.avgWeight, 80);
    });

    test('output is chronological even if input is not', () {
      final points =
          aggregateLogs(logs.reversed.toList(), ChartGranularity.month);
      expect(points.first.date.month, 1);
      expect(points.last.date.month, 2);
    });

    test('empty input', () {
      expect(aggregateLogs(const [], ChartGranularity.week), isEmpty);
    });
  });

  group('aggregateEntries', () {
    final entries = [
      _entry(DateTime(2026, 1, 1), 80),
      _entry(DateTime(2026, 1, 15), 82),
      _entry(DateTime(2026, 2, 1), 79),
    ];

    test('raw keeps every entry', () {
      expect(aggregateEntries(entries, ChartGranularity.raw), hasLength(3));
    });

    test('month averages values', () {
      final points = aggregateEntries(entries, ChartGranularity.month);
      expect(points, hasLength(2));
      expect(points.first.value, 81);
      expect(points.first.unit, 'kg');
    });
  });
}
