import 'package:flutter/material.dart';
import '../../app_repositories.dart';
import '../../models/workout.dart';
import '../../models/workout_plan.dart';
import '../../repositories/workout_plan_repository.dart';
import '../../repositories/workout_repository.dart';
import 'workout_detail_screen.dart';
import 'workout_form_screen.dart';
import 'workout_plan_detail_screen.dart';
import 'workout_session_screen.dart';

class WorkoutListScreen extends StatefulWidget {
  final WorkoutRepository workoutRepo;
  final WorkoutPlanRepository planRepo;

  const WorkoutListScreen({
    super.key,
    required this.workoutRepo,
    required this.planRepo,
  });

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Workout> _workouts = [];
  List<WorkoutPlan> _plans = [];
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
    final workouts = await widget.workoutRepo.getAll();
    final plans = await widget.planRepo.getAll();
    setState(() {
      _workouts = workouts;
      _plans = plans;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Workouts'), Tab(text: 'Plans')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Log session',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      WorkoutSessionScreen(workoutRepo: widget.workoutRepo),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _WorkoutTab(
                  workouts: _workouts,
                  workoutRepo: widget.workoutRepo,
                  onRefresh: _load,
                ),
                _PlanTab(
                  plans: _plans,
                  workoutRepo: widget.workoutRepo,
                  planRepo: widget.planRepo,
                  onRefresh: _load,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        child: const Icon(Icons.add),
        onPressed: () async {
          if (_tabCtrl.index == 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    WorkoutFormScreen(
                      workoutRepo: widget.workoutRepo,
                      exerciseRepo:
                          AppRepositories.of(context).exerciseRepo,
                    ),
              ),
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutPlanDetailScreen(
                  workoutRepo: widget.workoutRepo,
                  planRepo: widget.planRepo,
                ),
              ),
            );
          }
          _load();
        },
      ),
    );
  }
}

class _WorkoutTab extends StatelessWidget {
  final List<Workout> workouts;
  final WorkoutRepository workoutRepo;
  final VoidCallback onRefresh;

  const _WorkoutTab({
    required this.workouts,
    required this.workoutRepo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return const Center(child: Text('No workouts yet. Tap + to create one.'));
    }
    return ListView.builder(
      itemCount: workouts.length,
      itemBuilder: (ctx, i) {
        final w = workouts[i];
        return ListTile(
          title: Text(w.name),
          subtitle:
              Text('${w.exerciseIds.length} exercise(s)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => WorkoutDetailScreen(
                  workout: w,
                  workoutRepo: workoutRepo,
                ),
              ),
            );
            onRefresh();
          },
        );
      },
    );
  }
}

class _PlanTab extends StatelessWidget {
  final List<WorkoutPlan> plans;
  final WorkoutRepository workoutRepo;
  final WorkoutPlanRepository planRepo;
  final VoidCallback onRefresh;

  const _PlanTab({
    required this.plans,
    required this.workoutRepo,
    required this.planRepo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const Center(child: Text('No plans yet. Tap + to create one.'));
    }
    return ListView.builder(
      itemCount: plans.length,
      itemBuilder: (ctx, i) {
        final p = plans[i];
        return ListTile(
          title: Text(p.name),
          subtitle: Text('${p.entries.length} workout(s)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => WorkoutPlanDetailScreen(
                  plan: p,
                  workoutRepo: workoutRepo,
                  planRepo: planRepo,
                ),
              ),
            );
            onRefresh();
          },
        );
      },
    );
  }
}
