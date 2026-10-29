import 'package:flutter/material.dart';
import '../../app_repositories.dart';
import '../../models/workout.dart';
import '../../models/workout_plan.dart';
import '../../repositories/workout_plan_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../services/share_service.dart';
import 'workout_detail_screen.dart';
import 'workout_plan_form_screen.dart';

/// Groups a plan's entries by day of week (1 = Mon … 7 = Sun), resolving each
/// entry to its [Workout]. Every day is present (empty list = rest day).
/// Entries whose workout no longer exists are skipped.
Map<int, List<Workout>> planScheduleByDay(
    WorkoutPlan plan, List<Workout> workouts) {
  final byId = {for (final w in workouts) w.id: w};
  final schedule = {for (var d = 1; d <= 7; d++) d: <Workout>[]};
  for (final e in plan.entries) {
    final w = byId[e.workoutId];
    if (w != null) schedule[e.dayOfWeek]?.add(w);
  }
  return schedule;
}

/// Read-only view of a plan: the weekly schedule with each day's workouts.
/// Tapping a workout opens [WorkoutDetailScreen]; the edit icon opens
/// [WorkoutPlanFormScreen].
class WorkoutPlanDetailScreen extends StatefulWidget {
  final WorkoutPlan plan;
  final WorkoutRepository workoutRepo;
  final WorkoutPlanRepository planRepo;

  const WorkoutPlanDetailScreen({
    super.key,
    required this.plan,
    required this.workoutRepo,
    required this.planRepo,
  });

  @override
  State<WorkoutPlanDetailScreen> createState() =>
      _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState extends State<WorkoutPlanDetailScreen> {
  late WorkoutPlan _plan;
  List<Workout> _allWorkouts = [];
  bool _loading = true;

  static const _dayNames = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _load();
  }

  /// Reloads the plan and workouts; either may have changed in a pushed screen.
  Future<void> _load() async {
    final plan = await widget.planRepo.getById(_plan.id);
    final workouts = await widget.workoutRepo.getAll();
    if (!mounted) return;
    setState(() {
      if (plan != null) _plan = plan;
      _allWorkouts = workouts;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanFormScreen(
          plan: _plan,
          workoutRepo: widget.workoutRepo,
          planRepo: widget.planRepo,
        ),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
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
      await widget.planRepo.delete(_plan.id);
      nav.pop();
    }
  }

  Future<void> _openWorkout(Workout w) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workout: w,
          workoutRepo: widget.workoutRepo,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = planScheduleByDay(_plan, _allWorkouts);
    final today = DateTime.now().weekday;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_plan.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit plan',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export plan',
            onPressed: () => ShareService.exportWorkoutPlan(
              _plan,
              widget.workoutRepo,
              AppRepositories.of(context).exerciseRepo,
              context,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete plan',
            onPressed: _delete,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
              children: List.generate(7, (i) {
                final day = i + 1;
                final workouts = schedule[day]!;
                final isToday = day == today;
                return Card(
                  shape: isToday
                      ? RoundedRectangleBorder(
                          side: BorderSide(color: scheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(_dayNames[day],
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              if (isToday) ...[
                                const SizedBox(width: 8),
                                Text('Today',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: scheme.primary)),
                              ],
                            ],
                          ),
                        ),
                        if (workouts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Text('Rest day',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant)),
                          )
                        else
                          ...workouts.map((w) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.fitness_center),
                                title: Text(w.name),
                                subtitle: Text(
                                    '${w.exerciseIds.length} exercise(s)'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openWorkout(w),
                              )),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }
}
