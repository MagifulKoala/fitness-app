import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app_repositories.dart';
import 'db/database_helper.dart';
import 'repositories/exercise_log_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/measurement_repository.dart';
import 'repositories/workout_plan_repository.dart';
import 'repositories/workout_repository.dart';
import 'repositories/workout_session_repository.dart';
import 'screens/body/measurement_list_screen.dart';
import 'screens/exercises/exercise_list_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/workouts/workout_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite doesn't support Windows/Linux natively; use FFI on those platforms
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final db = DatabaseHelper.instance;
  // Open the database eagerly so the seed runs before UI loads
  await db.database;

  final exerciseRepo = ExerciseRepository(db);
  final exerciseLogRepo = ExerciseLogRepository(db);
  final workoutRepo = WorkoutRepository(db);
  final planRepo = WorkoutPlanRepository(db);
  final sessionRepo = WorkoutSessionRepository(db);
  final measurementRepo = MeasurementRepository(db);

  runApp(
    AppRepositories(
      exerciseRepo: exerciseRepo,
      exerciseLogRepo: exerciseLogRepo,
      workoutRepo: workoutRepo,
      planRepo: planRepo,
      sessionRepo: sessionRepo,
      measurementRepo: measurementRepo,
      child: const WorkoutApp(),
    ),
  );
}

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _MainShell(),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  int _resetKey = 0;
  final _progressKey = GlobalKey<ProgressScreenState>();

  void _onDataCleared() => setState(() => _resetKey++);

  @override
  Widget build(BuildContext context) {
    final repos = AppRepositories.of(context);

    final screens = [
      ExerciseListScreen(exerciseRepo: repos.exerciseRepo),
      WorkoutListScreen(
        workoutRepo: repos.workoutRepo,
        planRepo: repos.planRepo,
      ),
      MeasurementListScreen(measurementRepo: repos.measurementRepo),
      ProgressScreen(
        key: _progressKey,
        exerciseRepo: repos.exerciseRepo,
        logRepo: repos.exerciseLogRepo,
        measurementRepo: repos.measurementRepo,
      ),
      SettingsScreen(onDataCleared: _onDataCleared),
    ];

    return Scaffold(
      body: IndexedStack(key: ValueKey(_resetKey), index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 3) _progressKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight),
            label: 'Body',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
