import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'axis_scale.dart';
import 'chart_filter_bar.dart';

class ChartSeries {
  final String label;
  final List<FlSpot> spots;
  final Color color;
  bool visible;

  ChartSeries({
    required this.label,
    required this.spots,
    required this.color,
    this.visible = true,
  });
}

class ProgressLineChart extends StatefulWidget {
  final List<ChartSeries> series;
  final List<DateTime> dates; // parallel to x-axis indices
  final bool showDots;
  final void Function(int spotIndex)? onSpotTouched;
  final ChartGranularity? granularity;

  const ProgressLineChart({
    super.key,
    required this.series,
    required this.dates,
    this.showDots = true,
    this.onSpotTouched,
    this.granularity,
  });

  @override
  State<ProgressLineChart> createState() => _ProgressLineChartState();
}

class _ProgressLineChartState extends State<ProgressLineChart> {
  late List<ChartSeries> _series;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
  }

  @override
  void didUpdateWidget(ProgressLineChart old) {
    super.didUpdateWidget(old);
    if (old.series != widget.series) {
      _series = widget.series;
    }
  }

  static String _axisLabel(DateTime date, ChartGranularity? granularity) {
    switch (granularity) {
      case ChartGranularity.month:
        return DateFormat('MMM').format(date);
      case ChartGranularity.week:
        final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
        return 'W$weekOfMonth ${DateFormat('MMM').format(date)}';
      default:
        return DateFormat('dd/MM').format(date);
    }
  }

  static double _xInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 31) return 5;
    if (count <= 52) return 4;
    return 6;
  }

  /// Y-axis labels for [scale], tinted with the series colour when the chart
  /// has two axes so it is clear which axis belongs to which line.
  static AxisTitles _yTitles(AxisScale? scale, Color? color) {
    if (scale == null) {
      return const AxisTitles(sideTitles: SideTitles(showTitles: false));
    }
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: 1 / AxisScale.intervals,
        getTitlesWidget: (value, meta) {
          // fl_chart also asks for labels at min/max; only draw real ticks.
          final ticks = value * AxisScale.intervals;
          if ((ticks - ticks.round()).abs() > 1e-6) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              AxisScale.format(scale.denormalize(value)),
              style: TextStyle(fontSize: 10, color: color),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Each visible series gets its own scale, normalized to 0..1, so series
    // with very different magnitudes are all readable. The first two visible
    // series get the left and right axis respectively.
    final visible =
        _series.where((s) => s.visible && s.spots.isNotEmpty).toList();
    final scales = [
      for (final s in visible) AxisScale.fit(s.spots.map((p) => p.y)),
    ];
    final twoAxes = visible.length >= 2;

    return Column(
      children: [
        // Legend / toggles
        Wrap(
          spacing: 12,
          children: _series.map((s) {
            return FilterChip(
              label: Text(s.label),
              selected: s.visible,
              selectedColor: s.color.withValues(alpha: 0.2),
              checkmarkColor: s.color,
              onSelected: (v) => setState(() => s.visible = v),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.7,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
              lineBarsData: [
                for (var i = 0; i < visible.length; i++)
                  (visible[i], scales[i]),
              ]
                  .map(
                    (pair) => LineChartBarData(
                      spots: [
                        for (final p in pair.$1.spots)
                          FlSpot(p.x, pair.$2.normalize(p.y)),
                      ],
                      color: pair.$1.color,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      dotData: FlDotData(
                        show: widget.showDots,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 6,
                              color: bar.color ?? Colors.blue,
                              strokeColor: Colors.white,
                              strokeWidth: 1.5,
                            ),
                      ),
                      barWidth: 2,
                    ),
                  )
                  .toList(),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent &&
                      response?.lineBarSpots != null &&
                      response!.lineBarSpots!.isNotEmpty) {
                    final spotIndex = response.lineBarSpots!.first.spotIndex;
                    widget.onSpotTouched?.call(spotIndex);
                  }
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: _xInterval(widget.dates.length),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= widget.dates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _axisLabel(widget.dates[idx], widget.granularity),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: _yTitles(
                  scales.isNotEmpty ? scales[0] : null,
                  twoAxes ? visible[0].color : null,
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: _yTitles(
                  twoAxes ? scales[1] : null,
                  twoAxes ? visible[1].color : null,
                ),
              ),
              gridData: const FlGridData(
                show: true,
                horizontalInterval: 1 / AxisScale.intervals,
              ),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),
      ],
    );
  }
}
