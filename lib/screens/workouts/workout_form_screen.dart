import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../widgets/bottom_action_bar.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _selectedExerciseIds = [];
  List<Exercise> _allExercises = [];
  String _searchQuery = '';
  bool _saving = false;

  bool get _isEdit => widget.workout != null;

  List<Exercise> get _filteredExercises {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return _allExercises;
    return _allExercises.where((ex) {
      if (ex.name.toLowerCase().contains(q)) return true;
      return ex.aliases.any((a) => a.toLowerCase().contains(q));
    }).toList();
  }

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
    _searchCtrl.dispose();
    super.dispose();
  }

  // Sort once at load time so currently-selected exercises appear first.
  // Order is intentionally NOT re-computed on toggle — re-sorting while
  // the user is checking boxes causes items to jump, which is disorienting.
  Future<void> _loadExercises() async {
    if (widget.exerciseRepo == null) return;
    final exercises = await widget.exerciseRepo!.getAll();
    exercises.sort((a, b) {
      final aSelected = _selectedExerciseIds.contains(a.id);
      final bSelected = _selectedExerciseIds.contains(b.id);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.name.compareTo(b.name);
    });
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
    final filtered = _filteredExercises;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Workout' : 'New Workout')),
      bottomNavigationBar: BottomActionBar(
        label: _isEdit ? 'Save Changes' : 'Create Workout',
        onPressed: _saving ? null : _save,
      ),
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
              Text('Exercises', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search exercises…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 4),
              ...filtered.map((ex) {
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
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No exercises match "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
