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

  const ProgressLineChart({
    super.key,
    required this.series,
    required this.dates,
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
                      dotData: const FlDotData(show: true),
                      barWidth: 2,
                    ),
                  )
                  .toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
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
