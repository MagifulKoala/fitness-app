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
  State<ProgressScreen> createState() => ProgressScreenState();
}

class ProgressScreenState extends State<ProgressScreen>
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

  void reload() => _load();

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

class _ExerciseList extends StatefulWidget {
  final List<Exercise> exercises;
  final ExerciseLogRepository logRepo;

  const _ExerciseList({required this.exercises, required this.logRepo});

  @override
  State<_ExerciseList> createState() => _ExerciseListState();
}

class _ExerciseListState extends State<_ExerciseList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Exercise> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.exercises;
    return widget.exercises.where((ex) {
      if (ex.name.toLowerCase().contains(q)) return true;
      return ex.aliases.any((a) => a.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isEmpty) {
      return const Center(child: Text('No exercises yet.'));
    }

    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search exercises…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No exercises match "$_query"'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final ex = filtered[i];
                    return ListTile(
                      title: Text(ex.name),
                      trailing: const Icon(Icons.show_chart),
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => ExerciseProgressScreen(
                            exercise: ex,
                            logRepo: widget.logRepo,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MeasurementList extends StatefulWidget {
  final List<Measurement> measurements;
  final MeasurementRepository measurementRepo;

  const _MeasurementList(
      {required this.measurements, required this.measurementRepo});

  @override
  State<_MeasurementList> createState() => _MeasurementListState();
}

class _MeasurementListState extends State<_MeasurementList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Measurement> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.measurements;
    return widget.measurements
        .where((m) => m.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.measurements.isEmpty) {
      return const Center(child: Text('No measurements yet.'));
    }

    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search measurements…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No measurements match "$_query"'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final m = filtered[i];
                    return ListTile(
                      title: Text(m.name),
                      trailing: const Icon(Icons.show_chart),
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => MeasurementProgressScreen(
                            measurement: m,
                            measurementRepo: widget.measurementRepo,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
