import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/exercise.dart';
import '../../models/exercise_log.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../widgets/progress_line_chart.dart';
import '../../widgets/progress_table.dart';

class ExerciseProgressScreen extends StatefulWidget {
  final Exercise exercise;
  final ExerciseLogRepository logRepo;

  const ExerciseProgressScreen({
    super.key,
    required this.exercise,
    required this.logRepo,
  });

  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  List<ExerciseLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await widget.logRepo.getByExerciseId(widget.exercise.id);
    setState(() {
      _logs = logs.reversed.toList(); // ASC for charting
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.name),
          bottom: const TabBar(
            tabs: [Tab(text: 'Graph'), Tab(text: 'Table')],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
                ? const Center(child: Text('No logs yet.'))
                : TabBarView(
                    children: [
                      _GraphView(logs: _logs),
                      _TableView(logs: _logs),
                    ],
                  ),
      ),
    );
  }
}

class _GraphView extends StatelessWidget {
  final List<ExerciseLog> logs;
  const _GraphView({required this.logs});

  @override
  Widget build(BuildContext context) {
    final weightSpots = logs
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgWeight))
        .toList();
    final volumeSpots = logs
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
        .toList();
    final dates = logs.map((l) => l.date).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ProgressLineChart(
        series: [
          ChartSeries(
            label: 'Avg Weight',
            spots: weightSpots,
            color: Colors.blue,
          ),
          ChartSeries(
            label: 'Volume',
            spots: volumeSpots,
            color: Colors.orange,
          ),
        ],
        dates: dates,
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  final List<ExerciseLog> logs;
  const _TableView({required this.logs});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Weight'), Tab(text: 'Volume')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ProgressTable(
                  columns: const ['Avg Weight', 'Unit', 'Date'],
                  rows: logs.reversed
                      .map((l) => [
                            l.avgWeight.toStringAsFixed(2),
                            l.sets.isNotEmpty ? l.sets.first.unit : '-',
                            DateFormat('dd/MM/yy').format(l.date),
                          ])
                      .toList(),
                ),
                ProgressTable(
                  columns: const ['Volume', 'Date'],
                  rows: logs.reversed
                      .map((l) => [
                            l.volume.toStringAsFixed(2),
                            DateFormat('dd/MM/yy').format(l.date),
                          ])
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
