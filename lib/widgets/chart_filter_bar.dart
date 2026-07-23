import 'package:flutter/material.dart';
import 'date_picker_field.dart';

enum ChartFilter { day, week, month, year, all, custom }

enum ChartGranularity { raw, day, week, month }

DateTime windowStart(ChartFilter filter, DateTime customFrom) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter) {
    ChartFilter.day => today,
    ChartFilter.week => today.subtract(Duration(days: today.weekday - 1)), // Monday
    ChartFilter.month => DateTime(today.year, today.month, 1),
    ChartFilter.year => DateTime(today.year, 1, 1),
    ChartFilter.all => DateTime(2000),
    ChartFilter.custom => customFrom,
  };
}

DateTime windowEnd(ChartFilter filter, DateTime customTo) {
  if (filter == ChartFilter.custom) return customTo;
  if (filter == ChartFilter.all) return DateTime(9999, 12, 30); // include future-dated entries
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return switch (filter) {
    ChartFilter.day => today,
    ChartFilter.week => monday.add(const Duration(days: 6)), // Sunday
    ChartFilter.month => DateTime(today.year, today.month + 1, 0), // last day of month
    ChartFilter.year => DateTime(today.year, 12, 31),
    ChartFilter.all || ChartFilter.custom => today, // unreachable
  };
}

bool showDots(ChartFilter filter, DateTime from, DateTime to) {
  return switch (filter) {
    ChartFilter.day || ChartFilter.week || ChartFilter.month => true,
    ChartFilter.year => false,
    ChartFilter.all || ChartFilter.custom => to.difference(from).inDays <= 60,
  };
}

ChartGranularity granularityFor(ChartFilter filter, DateTime from, DateTime to) {
  return switch (filter) {
    ChartFilter.day => ChartGranularity.raw,
    ChartFilter.week || ChartFilter.month => ChartGranularity.day,
    ChartFilter.year => ChartGranularity.week,
    ChartFilter.all => ChartGranularity.raw, // overridden per-screen with actual data range
    ChartFilter.custom => adaptiveGranularity(from, to),
  };
}

// Public so screens can compute granularity from actual data span for ChartFilter.all.
ChartGranularity adaptiveGranularity(DateTime from, DateTime to) {
  final days = to.difference(from).inDays;
  if (days <= 7) return ChartGranularity.raw;
  if (days <= 60) return ChartGranularity.day;
  if (days <= 365) return ChartGranularity.week;
  return ChartGranularity.month;
}

/// Groups a date into a sortable string key for the given granularity.
String periodKey(DateTime date, ChartGranularity granularity) {
  final y = date.year;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return switch (granularity) {
    ChartGranularity.raw =>
      throw StateError('periodKey must not be called in raw mode'),
    ChartGranularity.day => '$y-$m-$d',
    ChartGranularity.week => _weekKey(date),
    ChartGranularity.month => '$y-$m',
  };
}

// Weeks since a fixed reference point, aligned to Monday.
// The Unix epoch (1970-01-01) was a Thursday (+3 offsets to Monday).
String _weekKey(DateTime date) {
  final weeks = (date.difference(DateTime(1970)).inDays + 3) ~/ 7;
  return 'W${weeks.toString().padLeft(6, '0')}';
}

class ChartFilterBar extends StatelessWidget {
  final ChartFilter selected;
  final DateTime customFrom;
  final DateTime customTo;
  final void Function(ChartFilter) onFilterChanged;
  final void Function(DateTime) onFromChanged;
  final void Function(DateTime) onToChanged;

  const ChartFilterBar({
    super.key,
    required this.selected,
    required this.customFrom,
    required this.customTo,
    required this.onFilterChanged,
    required this.onFromChanged,
    required this.onToChanged,
  });

  static const _labels = {
    ChartFilter.day: 'Day',
    ChartFilter.week: 'Week',
    ChartFilter.month: 'Month',
    ChartFilter.year: 'Year',
    ChartFilter.all: 'All',
    ChartFilter.custom: 'Custom',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: ChartFilter.values
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_labels[f]!),
                        selected: selected == f,
                        onSelected: (_) => onFilterChanged(f),
                      ),
                    ))
                .toList(),
          ),
        ),
        if (selected == ChartFilter.custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DatePickerField(
                    date: customFrom,
                    label: 'From',
                    onChanged: onFromChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DatePickerField(
                    date: customTo,
                    label: 'To',
                    onChanged: onToChanged,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
