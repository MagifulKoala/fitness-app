import 'package:flutter/material.dart';
import '../../app_repositories.dart';
import '../../core/app_logger.dart';
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

  /// Moves an exercise and saves the new order straight away. The list updates
  /// first so the drop feels instant; on a failed save it reloads from the DB.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    setState(() {
      _exercises.insert(newIndex, _exercises.removeAt(oldIndex));
      _workout = _workout.copyWith(
          exerciseIds: [for (final e in _exercises) e.id]);
    });
    try {
      await widget.workoutRepo.update(_workout);
    } catch (e, st) {
      log.e('[WorkoutDetail] reorder failed', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the new order')));
      await _refresh();
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
      // Drag the handle to reorder immediately, or long-press anywhere on a row.
      body: ReorderableListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        buildDefaultDragHandles: false,
        onReorderItem: _reorder,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_workout.notes != null && _workout.notes!.isNotEmpty) ...[
              Text('Notes', style: Theme.of(context).textTheme.labelLarge),
              Text(_workout.notes!),
              const SizedBox(height: 16),
            ],
            Text('Exercises', style: Theme.of(context).textTheme.titleMedium),
            if (_exercises.length > 1)
              Text('Drag ≡ to reorder',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (_workout.exerciseIds.isEmpty)
              const Text('No exercises in this workout.'),
          ],
        ),
        children: [
          for (final (i, ex) in _exercises.indexed)
            ReorderableDelayedDragStartListener(
              key: ValueKey(ex.id),
              index: i,
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(right: 8),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                    CircleAvatar(
                      radius: 12,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                title: Text(ex.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final repos = AppRepositories.of(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailScreen(
                        exercise: ex,
                        exerciseRepo: repos.exerciseRepo,
                        // Stats and new logs follow this workout.
                        workout: _workout,
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
