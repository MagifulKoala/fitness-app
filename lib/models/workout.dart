import 'package:equatable/equatable.dart';

class Workout extends Equatable {
  final String id;
  final String name;
  final List<String> exerciseIds;
  final String? notes;

  const Workout({
    required this.id,
    required this.name,
    required this.exerciseIds,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'notes': notes};
  }

  factory Workout.fromMap(Map<String, dynamic> map, List<String> exerciseIds) {
    return Workout(
      id: map['id'] as String,
      name: map['name'] as String,
      exerciseIds: exerciseIds,
      notes: map['notes'] as String?,
    );
  }

  Workout copyWith({String? name, List<String>? exerciseIds, String? notes}) {
    return Workout(
      id: id,
      name: name ?? this.name,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [id, name, exerciseIds, notes];
}
