import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/chart_filter_bar.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final unused = DateTime(2000);

  group('calendar-aligned windows', () {
    test('day is today only', () {
      expect(windowStart(ChartFilter.day, unused), today);
      expect(windowEnd(ChartFilter.day, unused), today);
    });

    test('week runs Monday to Sunday and contains today', () {
      final start = windowStart(ChartFilter.week, unused);
      final end = windowEnd(ChartFilter.week, unused);
      expect(start.weekday, DateTime.monday);
      expect(end.weekday, DateTime.sunday);
      expect(end.difference(start).inDays, 6);
      expect(!today.isBefore(start) && !today.isAfter(end), isTrue);
    });

    test('month runs from the 1st to the last day', () {
      final start = windowStart(ChartFilter.month, unused);
      final end = windowEnd(ChartFilter.month, unused);
      expect(start, DateTime(today.year, today.month, 1));
      expect(end.month, today.month);
      expect(end.add(const Duration(days: 1)).day, 1);
    });

    test('year runs Jan 1 to Dec 31', () {
      expect(windowStart(ChartFilter.year, unused), DateTime(today.year, 1, 1));
      expect(windowEnd(ChartFilter.year, unused), DateTime(today.year, 12, 31));
    });

    test('custom uses the given dates', () {
      final from = DateTime(2025, 2, 3);
      final to = DateTime(2025, 4, 5);
      expect(windowStart(ChartFilter.custom, from), from);
      expect(windowEnd(ChartFilter.custom, to), to);
    });

    test('all covers past and future-dated entries', () {
      expect(windowStart(ChartFilter.all, unused).year, lessThanOrEqualTo(2000));
      expect(windowEnd(ChartFilter.all, unused).isAfter(DateTime(9000)), isTrue);
    });
  });

  group('adaptiveGranularity', () {
    final from = DateTime(2025, 1, 1);
    ChartGranularity forDays(int d) =>
        adaptiveGranularity(from, from.add(Duration(days: d)));

    test('thresholds', () {
      expect(forDays(0), ChartGranularity.raw);
      expect(forDays(7), ChartGranularity.raw);
      expect(forDays(8), ChartGranularity.day);
      expect(forDays(60), ChartGranularity.day);
      expect(forDays(61), ChartGranularity.week);
      expect(forDays(365), ChartGranularity.week);
      expect(forDays(366), ChartGranularity.month);
    });
  });

  group('periodKey', () {
    test('raw mode is a programming error', () {
      expect(() => periodKey(DateTime(2025), ChartGranularity.raw),
          throwsStateError);
    });

    test('day and month keys', () {
      expect(periodKey(DateTime(2025, 3, 7, 23), ChartGranularity.day),
          '2025-03-07');
      expect(periodKey(DateTime(2025, 3, 7), ChartGranularity.month), '2025-03');
    });

    test('weeks are Monday-aligned', () {
      final monday = DateTime(2026, 10, 26);
      final sunday = DateTime(2026, 11, 1);
      final nextMonday = DateTime(2026, 11, 2);
      final week = ChartGranularity.week;
      expect(periodKey(monday, week), periodKey(sunday, week));
      expect(periodKey(sunday, week), isNot(periodKey(nextMonday, week)));
    });

    test('week keys sort chronologically across years', () {
      final a = periodKey(DateTime(2025, 12, 29), ChartGranularity.week);
      final b = periodKey(DateTime(2026, 1, 5), ChartGranularity.week);
      expect(a.compareTo(b), lessThan(0));
    });
  });

  test('showDots hides dots only for dense views', () {
    final from = DateTime(2025, 1, 1);
    expect(showDots(ChartFilter.month, from, from), isTrue);
    expect(showDots(ChartFilter.year, from, from), isFalse);
    expect(showDots(ChartFilter.all, from, from.add(const Duration(days: 60))),
        isTrue);
    expect(showDots(ChartFilter.all, from, from.add(const Duration(days: 61))),
        isFalse);
  });
}
