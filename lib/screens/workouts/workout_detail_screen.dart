import 'package:flutter/material.dart';
import '../../app_repositories.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../repositories/workout_repository.dart';
import '../exercises/exercise_detail_screen.dart';
import 'workout_form_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;
  final WorkoutRepository workoutRepo;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.workoutRepo,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Workout _workout;
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final repos = AppRepositories.of(context);
    final all = await repos.exerciseRepo.getAll();
    if (mounted) {
      setState(() {
        _exercises = all
            .where((e) => _workout.exerciseIds.contains(e.id))
            .toList()
          ..sort((a, b) => _workout.exerciseIds
              .indexOf(a.id)
              .compareTo(_workout.exerciseIds.indexOf(b.id)));
      });
    }
  }

  Future<void> _refresh() async {
    final updated = await widget.workoutRepo.getById(_workout.id);
    if (updated != null && mounted) {
      setState(() => _workout = updated);
      _loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workout.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final repos = AppRepositories.of(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutFormScreen(
                    workoutRepo: widget.workoutRepo,
                    exerciseRepo: repos.exerciseRepo,
                    workout: _workout,
                  ),
                ),
              );
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final nav = Navigator.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete workout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await widget.workoutRepo.delete(_workout.id);
                nav.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (_workout.notes != null && _workout.notes!.isNotEmpty) ...[
            Text('Notes', style: Theme.of(context).textTheme.labelLarge),
            Text(_workout.notes!),
            const SizedBox(height: 16),
          ],
          Text('Exercises', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_workout.exerciseIds.isEmpty)
            const Text('No exercises in this workout.')
          else
            ..._exercises.asMap().entries.map(
                  (e) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text('${e.key + 1}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                    title: Text(e.value.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final repos = AppRepositories.of(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(
                            exercise: e.value,
                            exerciseRepo: repos.exerciseRepo,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
