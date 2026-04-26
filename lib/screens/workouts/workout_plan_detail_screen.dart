import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app_repositories.dart';
import '../../models/workout.dart';
import '../../models/workout_plan.dart';
import '../../models/workout_plan_entry.dart';
import '../../repositories/workout_plan_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../services/share_service.dart';

class WorkoutPlanDetailScreen extends StatefulWidget {
  final WorkoutPlan? plan;
  final WorkoutRepository workoutRepo;
  final WorkoutPlanRepository planRepo;

  const WorkoutPlanDetailScreen({
    super.key,
    this.plan,
    required this.workoutRepo,
    required this.planRepo,
  });

  @override
  State<WorkoutPlanDetailScreen> createState() =>
      _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState extends State<WorkoutPlanDetailScreen> {
  final _uuid = const Uuid();
  final _nameCtrl = TextEditingController();
  List<Workout> _allWorkouts = [];
  // dayOfWeek (1–7) -> list of workout ids
  final Map<int, List<String>> _dayMap = {
    for (var i = 1; i <= 7; i++) i: [],
  };
  bool _saving = false;

  static const _dayNames = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.plan!.name;
      for (final e in widget.plan!.entries) {
        _dayMap[e.dayOfWeek]!.add(e.workoutId);
      }
    }
    _loadWorkouts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await widget.workoutRepo.getAll();
    setState(() => _allWorkouts = workouts);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Plan name is required')));
      return;
    }
    setState(() => _saving = true);

    final entries = <WorkoutPlanEntry>[];
    for (final day in _dayMap.keys) {
      for (final wid in _dayMap[day]!) {
        entries.add(WorkoutPlanEntry(
          id: _uuid.v4(),
          workoutId: wid,
          dayOfWeek: day,
        ));
      }
    }

    if (_isEdit) {
      final updated = widget.plan!.copyWith(
        name: _nameCtrl.text.trim(),
        entries: entries,
      );
      await widget.planRepo.update(updated);
    } else {
      final plan = WorkoutPlan(
        id: _uuid.v4(),
        name: _nameCtrl.text.trim(),
        entries: entries,
      );
      await widget.planRepo.insert(plan);
    }

    if (mounted) Navigator.pop(context);
  }

  void _toggleWorkoutForDay(int day, String workoutId) {
    setState(() {
      if (_dayMap[day]!.contains(workoutId)) {
        _dayMap[day]!.remove(workoutId);
      } else {
        _dayMap[day]!.add(workoutId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Plan' : 'New Plan'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => ShareService.exportWorkoutPlan(
                widget.plan!,
                widget.workoutRepo,
                AppRepositories.of(context).exerciseRepo,
                context,
              ),
            ),
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final nav = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete plan?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await widget.planRepo.delete(widget.plan!.id);
                  nav.pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Plan Name *'),
          ),
          const SizedBox(height: 20),
          Text('Weekly Schedule',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(7, (i) {
            final day = i + 1;
            final assigned = _dayMap[day]!;
            return Card(
              child: ExpansionTile(
                title: Text(_dayNames[day]),
                subtitle: assigned.isEmpty
                    ? const Text('No workouts')
                    : Text(assigned
                        .map((id) => _allWorkouts
                            .firstWhere((w) => w.id == id,
                                orElse: () => Workout(
                                    id: id,
                                    name: id,
                                    exerciseIds: []))
                            .name)
                        .join(', ')),
                children: _allWorkouts.map((w) {
                  return CheckboxListTile(
                    title: Text(w.name),
                    value: assigned.contains(w.id),
                    onChanged: (_) => _toggleWorkoutForDay(day, w.id),
                  );
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'Save Plan' : 'Create Plan'),
          ),
        ],
      ),
    );
  }
}
