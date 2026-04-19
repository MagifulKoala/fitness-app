import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app_repositories.dart';
import '../../core/app_logger.dart';
import '../../models/workout.dart';
import '../../models/workout_session.dart';
import '../../repositories/workout_repository.dart';
import '../../repositories/workout_session_repository.dart';
import '../../widgets/date_picker_field.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepo;

  const WorkoutSessionScreen({super.key, required this.workoutRepo});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final _uuid = const Uuid();
  List<Workout> _workouts = [];
  String? _selectedWorkoutId;
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final workouts = await widget.workoutRepo.getAll();
    setState(() {
      _workouts = workouts;
      if (workouts.isNotEmpty) _selectedWorkoutId = workouts.first.id;
    });
  }

  Future<void> _save(WorkoutSessionRepository sessionRepo) async {
    if (_selectedWorkoutId == null) return;
    setState(() => _saving = true);

    final session = WorkoutSession(
      id: _uuid.v4(),
      workoutId: _selectedWorkoutId!,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    try {
      await sessionRepo.insert(session);
      log.d('[WorkoutSession] session saved: workoutId=${session.workoutId}');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session logged!')),
        );
      }
    } catch (e, st) {
      log.e('[WorkoutSession] save failed', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save session.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Session')),
      body: SafeArea(
        child: _workouts.isEmpty
          ? const Center(child: Text('No workouts yet. Create one first.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedWorkoutId,
                  decoration: const InputDecoration(labelText: 'Workout'),
                  items: _workouts
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedWorkoutId = v),
                ),
                const SizedBox(height: 16),
                DatePickerField(
                  date: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(repos.sessionRepo),

                  child: const Text('Log Session'),
                ),
              ],
            ),
        ),
    );
  }
}

