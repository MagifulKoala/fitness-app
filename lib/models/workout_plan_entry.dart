import 'package:equatable/equatable.dart';

class WorkoutPlanEntry extends Equatable {
  final String id;
  final String workoutId;
  final int dayOfWeek; // 1=Monday … 7=Sunday

  const WorkoutPlanEntry({
    required this.id,
    required this.workoutId,
    required this.dayOfWeek,
  });

  Map<String, dynamic> toMap({required String planId}) {
    return {
      'id': id,
      'plan_id': planId,
      'workout_id': workoutId,
      'day_of_week': dayOfWeek,
    };
  }

  factory WorkoutPlanEntry.fromMap(Map<String, dynamic> map) {
    return WorkoutPlanEntry(
      id: map['id'] as String,
      workoutId: map['workout_id'] as String,
      dayOfWeek: map['day_of_week'] as int,
    );
  }

  @override
  List<Object?> get props => [id, workoutId, dayOfWeek];
}
