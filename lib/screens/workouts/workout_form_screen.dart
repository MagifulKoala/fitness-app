import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/workout_repository.dart';

class WorkoutFormScreen extends StatefulWidget {
  final WorkoutRepository workoutRepo;
  final ExerciseRepository? exerciseRepo;
  final Workout? workout;

  const WorkoutFormScreen({
    super.key,
    required this.workoutRepo,
    this.exerciseRepo,
    this.workout,
  });

  @override
  State<WorkoutFormScreen> createState() => _WorkoutFormScreenState();
}

class _WorkoutFormScreenState extends State<WorkoutFormScreen> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  List<String> _selectedExerciseIds = [];
  List<Exercise> _allExercises = [];
  bool _saving = false;

  bool get _isEdit => widget.workout != null;

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _notesCtrl = TextEditingController(text: w?.notes ?? '');
    _selectedExerciseIds = List.of(w?.exerciseIds ?? []);
    _loadExercises();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    if (widget.exerciseRepo == null) return;
    final exercises = await widget.exerciseRepo!.getAll();
    setState(() => _allExercises = exercises);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    if (_isEdit) {
      final updated = widget.workout!.copyWith(
        name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        exerciseIds: _selectedExerciseIds,
      );
      await widget.workoutRepo.update(updated);
    } else {
      final workout = Workout(
        id: _uuid.v4(),
        name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        exerciseIds: _selectedExerciseIds,
      );
      await widget.workoutRepo.insert(workout);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Workout' : 'New Workout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            if (_allExercises.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Exercises',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._allExercises.map((ex) {
                final selected = _selectedExerciseIds.contains(ex.id);
                return CheckboxListTile(
                  title: Text(ex.name),
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedExerciseIds.add(ex.id);
                      } else {
                        _selectedExerciseIds.remove(ex.id);
                      }
                    });
                  },
                );
              }),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? 'Save Changes' : 'Create Workout'),
            ),
          ],
        ),
      ),
    );
  }
}
