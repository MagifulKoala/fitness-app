import 'package:flutter/material.dart';
import 'repositories/exercise_log_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/measurement_repository.dart';
import 'repositories/workout_plan_repository.dart';
import 'repositories/workout_repository.dart';
import 'repositories/workout_session_repository.dart';

/// Makes all repositories available anywhere in the widget tree.
class AppRepositories extends InheritedWidget {
  final ExerciseRepository exerciseRepo;
  final ExerciseLogRepository exerciseLogRepo;
  final WorkoutRepository workoutRepo;
  final WorkoutPlanRepository planRepo;
  final WorkoutSessionRepository sessionRepo;
  final MeasurementRepository measurementRepo;

  const AppRepositories({
    super.key,
    required this.exerciseRepo,
    required this.exerciseLogRepo,
    required this.workoutRepo,
    required this.planRepo,
    required this.sessionRepo,
    required this.measurementRepo,
    required super.child,
  });

  static AppRepositories of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<AppRepositories>();
    assert(result != null, 'No AppRepositories found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppRepositories oldWidget) => false;
}
