import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  const ProgressLineChart({
    super.key,
    required this.series,
    required this.dates,
    this.showDots = true,
    this.onSpotTouched,
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

  static double _xInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 31) return 5;
    if (count <= 52) return 4;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
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
              lineBarsData: _series
                  .where((s) => s.visible && s.spots.isNotEmpty)
                  .map(
                    (s) => LineChartBarData(
                      spots: s.spots,
                      color: s.color,
                      isCurved: true,
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
                          DateFormat('dd/MM').format(widget.dates[idx]),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),
      ],
    );
  }
}
