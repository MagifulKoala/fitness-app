import 'package:equatable/equatable.dart';
import 'set_child.dart';

class SetTemplate extends Equatable {
  final String id;
  final List<SetChild> sets;

  const SetTemplate({required this.id, required this.sets});

  double get volume =>
      sets.fold(0.0, (sum, s) => sum + s.reps * s.weight);

  Map<String, dynamic> toMap({required String exerciseId}) {
    return {'id': id, 'exercise_id': exerciseId};
  }

  factory SetTemplate.fromMap(Map<String, dynamic> map, List<SetChild> sets) {
    return SetTemplate(id: map['id'] as String, sets: sets);
  }

  SetTemplate copyWith({List<SetChild>? sets}) {
    return SetTemplate(id: id, sets: sets ?? this.sets);
  }

  @override
  List<Object?> get props => [id, sets];
}
