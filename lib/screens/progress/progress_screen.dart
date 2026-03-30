import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../models/measurement.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/measurement_repository.dart';
import 'exercise_progress_screen.dart';
import 'measurement_progress_screen.dart';

class ProgressScreen extends StatefulWidget {
  final ExerciseRepository exerciseRepo;
  final ExerciseLogRepository logRepo;
  final MeasurementRepository measurementRepo;

  const ProgressScreen({
    super.key,
    required this.exerciseRepo,
    required this.logRepo,
    required this.measurementRepo,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Exercise> _exercises = [];
  List<Measurement> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final exercises = await widget.exerciseRepo.getAll();
    final measurements = await widget.measurementRepo.getAllMeasurements();
    setState(() {
      _exercises = exercises;
      _measurements = measurements;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Exercises'), Tab(text: 'Body')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _ExerciseList(
                  exercises: _exercises,
                  logRepo: widget.logRepo,
                ),
                _MeasurementList(
                  measurements: _measurements,
                  measurementRepo: widget.measurementRepo,
                ),
              ],
            ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  final List<Exercise> exercises;
  final ExerciseLogRepository logRepo;

  const _ExerciseList({required this.exercises, required this.logRepo});

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return const Center(child: Text('No exercises yet.'));
    }
    return ListView.builder(
      itemCount: exercises.length,
      itemBuilder: (ctx, i) {
        final ex = exercises[i];
        return ListTile(
          title: Text(ex.name),
          trailing: const Icon(Icons.show_chart),
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => ExerciseProgressScreen(
                exercise: ex,
                logRepo: logRepo,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MeasurementList extends StatelessWidget {
  final List<Measurement> measurements;
  final MeasurementRepository measurementRepo;

  const _MeasurementList(
      {required this.measurements, required this.measurementRepo});

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return const Center(child: Text('No measurements yet.'));
    }
    return ListView.builder(
      itemCount: measurements.length,
      itemBuilder: (ctx, i) {
        final m = measurements[i];
        return ListTile(
          title: Text(m.name),
          trailing: const Icon(Icons.show_chart),
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => MeasurementProgressScreen(
                measurement: m,
                measurementRepo: measurementRepo,
              ),
            ),
          ),
        );
      },
    );
  }
}
