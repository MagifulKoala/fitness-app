import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_app/app_repositories.dart';
import 'package:workout_app/db/database_helper.dart';
import 'package:workout_app/repositories/exercise_log_repository.dart';
import 'package:workout_app/repositories/exercise_repository.dart';
import 'package:workout_app/repositories/measurement_repository.dart';
import 'package:workout_app/repositories/workout_plan_repository.dart';
import 'package:workout_app/repositories/workout_repository.dart';
import 'package:workout_app/repositories/workout_session_repository.dart';

/// All repositories wired to [DatabaseHelper.instance], as in `main.dart`.
AppRepositories testRepositories() {
  final db = DatabaseHelper.instance;
  return AppRepositories(
    exerciseRepo: ExerciseRepository(db),
    exerciseLogRepo: ExerciseLogRepository(db),
    workoutRepo: WorkoutRepository(db),
    planRepo: WorkoutPlanRepository(db),
    sessionRepo: WorkoutSessionRepository(db),
    measurementRepo: MeasurementRepository(db),
    child: const SizedBox(),
  );
}

/// Points [DatabaseHelper] at a fresh in-memory SQLite database for every test
/// in the calling file. Call once at the top of `main()`.
void useInMemoryDatabase() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });
  setUp(DatabaseHelper.resetForTesting);
  tearDownAll(() async {
    await DatabaseHelper.resetForTesting();
    DatabaseHelper.pathOverride = null;
  });
}
