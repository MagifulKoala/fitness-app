import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/measurement.dart';
import '../../models/measurement_entry.dart';
import '../../repositories/measurement_repository.dart';
import '../../widgets/progress_line_chart.dart';
import '../../widgets/progress_table.dart';

class MeasurementProgressScreen extends StatefulWidget {
  final Measurement measurement;
  final MeasurementRepository measurementRepo;

  const MeasurementProgressScreen({
    super.key,
    required this.measurement,
    required this.measurementRepo,
  });

  @override
  State<MeasurementProgressScreen> createState() =>
      _MeasurementProgressScreenState();
}

class _MeasurementProgressScreenState
    extends State<MeasurementProgressScreen> {
  List<MeasurementEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries =
        await widget.measurementRepo.getEntries(widget.measurement.id);
    setState(() {
      _entries = entries; // already ASC by date
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.measurement.name),
          bottom: const TabBar(
            tabs: [Tab(text: 'Graph'), Tab(text: 'Table')],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? const Center(child: Text('No data yet.'))
                : TabBarView(
                    children: [
                      _GraphView(entries: _entries),
                      _TableView(entries: _entries),
                    ],
                  ),
      ),
    );
  }
}

class _GraphView extends StatelessWidget {
  final List<MeasurementEntry> entries;
  const _GraphView({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final dates = entries.map((e) => e.date).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ProgressLineChart(
        series: [
          ChartSeries(
            label: entries.first.unit,
            spots: spots,
            color: Colors.blue,
          ),
        ],
        dates: dates,
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  final List<MeasurementEntry> entries;
  const _TableView({required this.entries});

  @override
  Widget build(BuildContext context) {
    final rows = entries.reversed
        .map((e) => [
              e.value.toString(),
              e.unit,
              DateFormat('dd/MM/yy').format(e.date),
            ])
        .toList();
    return ProgressTable(
      columns: const ['Value', 'Unit', 'Date'],
      rows: rows,
    );
  }
}
