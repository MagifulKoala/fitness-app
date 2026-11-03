import 'package:equatable/equatable.dart';
import 'set_child.dart';

class ExerciseLog extends Equatable {
  final String id;
  final String exerciseId;
  final DateTime date;
  final String? notes;
  final List<SetChild> sets;

  /// The workout this log was done in, or null (logged from the Exercises tab,
  /// or recorded before schema v5). May point at a workout that was deleted.
  final String? workoutId;

  /// The workout's name when the log was saved. Keeps deleted workouts
  /// readable; while the workout exists its current name is shown instead.
  final String? workoutName;

  const ExerciseLog({
    required this.id,
    required this.exerciseId,
    required this.date,
    this.notes,
    required this.sets,
    this.workoutId,
    this.workoutName,
  });

  double get volume =>
      sets.fold(0.0, (sum, s) => sum + s.reps * s.weight);

  double get avgWeight {
    if (sets.isEmpty) return 0.0;
    return sets.fold(0.0, (sum, s) => sum + s.weight) / sets.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'date': date.toIso8601String(),
      'notes': notes,
      'workout_id': workoutId,
      'workout_name': workoutName,
    };
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map, List<SetChild> sets) {
    return ExerciseLog(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      sets: sets,
      workoutId: map['workout_id'] as String?,
      workoutName: map['workout_name'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, exerciseId, date, notes, sets, workoutId, workoutName];
}
