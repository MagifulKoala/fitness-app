import 'package:equatable/equatable.dart';
import 'workout_plan_entry.dart';

class WorkoutPlan extends Equatable {
  final String id;
  final String name;
  final List<WorkoutPlanEntry> entries;

  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.entries,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  factory WorkoutPlan.fromMap(
    Map<String, dynamic> map,
    List<WorkoutPlanEntry> entries,
  ) {
    return WorkoutPlan(
      id: map['id'] as String,
      name: map['name'] as String,
      entries: entries,
    );
  }

  WorkoutPlan copyWith({String? name, List<WorkoutPlanEntry>? entries}) {
    return WorkoutPlan(
      id: id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
    );
  }

  @override
  List<Object?> get props => [id, name, entries];
}
