import 'package:equatable/equatable.dart';
import 'set_child.dart';

class ExerciseLog extends Equatable {
  final String id;
  final String exerciseId;
  final DateTime date;
  final String? notes;
  final List<SetChild> sets;

  const ExerciseLog({
    required this.id,
    required this.exerciseId,
    required this.date,
    this.notes,
    required this.sets,
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
    };
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map, List<SetChild> sets) {
    return ExerciseLog(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      sets: sets,
    );
  }

  @override
  List<Object?> get props => [id, exerciseId, date, notes, sets];
}
