import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/chart_filter_bar.dart';
import 'package:workout_app/widgets/progress_line_chart.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

List<FlSpot> _spots(List<double> ys) =>
    [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])];

void main() {
  final dates = [for (var i = 0; i < 4; i++) DateTime(2026, i + 1, 1)];

  testWidgets('two series get a left and a right axis', (tester) async {
    await tester.pumpWidget(_wrap(ProgressLineChart(
      series: [
        ChartSeries(
            label: 'Avg Weight',
            spots: _spots([60, 80, 100, 130]),
            color: Colors.blue),
        ChartSeries(
            label: 'Volume',
            spots: _spots([21500, 33000, 40517.5, 36000]),
            color: Colors.orange),
      ],
      dates: dates,
      granularity: ChartGranularity.month,
    )));

    expect(tester.takeException(), isNull);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.lineBarsData, hasLength(2));
    expect(data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(data.titlesData.rightTitles.sideTitles.showTitles, isTrue);
    // Both series are drawn normalized into the same 0..1 band.
    for (final bar in data.lineBarsData) {
      expect(bar.spots.every((s) => s.y >= 0 && s.y <= 1), isTrue);
    }
    // Labels are short and round, e.g. "40k" rather than "40517.5".
    expect(find.text('40517.5'), findsNothing);
    expect(find.textContaining('k'), findsWidgets);
  });

  testWidgets('hiding a series drops its axis', (tester) async {
    await tester.pumpWidget(_wrap(ProgressLineChart(
      series: [
        ChartSeries(label: 'Avg Weight', spots: _spots([60, 70, 80, 90]), color: Colors.blue),
        ChartSeries(label: 'Volume', spots: _spots([1, 2, 3, 4]), color: Colors.orange),
      ],
      dates: dates,
    )));

    await tester.tap(find.text('Volume'));
    await tester.pump();

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.lineBarsData, hasLength(1));
    expect(data.titlesData.rightTitles.sideTitles.showTitles, isFalse);
  });

  testWidgets('single flat series renders (measurement, bodyweight)',
      (tester) async {
    await tester.pumpWidget(_wrap(ProgressLineChart(
      series: [
        ChartSeries(label: 'Weight', spots: _spots([0]), color: Colors.blue),
      ],
      dates: [dates.first],
    )));
    expect(tester.takeException(), isNull);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(data.titlesData.rightTitles.sideTitles.showTitles, isFalse);
  });
}
