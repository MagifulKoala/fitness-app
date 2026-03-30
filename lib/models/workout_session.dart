import 'package:equatable/equatable.dart';

class WorkoutSession extends Equatable {
  final String id;
  final String workoutId;
  final DateTime date;
  final String? notes;

  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      workoutId: map['workout_id'] as String,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, workoutId, date, notes];
}
