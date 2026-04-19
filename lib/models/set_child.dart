import 'package:equatable/equatable.dart';

class SetChild extends Equatable {
  final String id;
  final int reps;
  final double weight;
  final String unit; // 'kg' or 'lbs'

  const SetChild({
    required this.id,
    required this.reps,
    required this.weight,
    required this.unit,
  });

  Map<String, dynamic> toMap({String? setTemplateId, String? logId}) {
    return {
      'id': id,
      // ignore: use_null_aware_elements
      if (setTemplateId != null) 'set_template_id': setTemplateId,
      // ignore: use_null_aware_elements
      if (logId != null) 'log_id': logId,
      'reps': reps,
      'weight': weight,
      'unit': unit,
    };
  }

  factory SetChild.fromMap(Map<String, dynamic> map) {
    return SetChild(
      id: map['id'] as String,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
      unit: map['unit'] as String,
    );
  }

  SetChild copyWith({int? reps, double? weight, String? unit}) {
    return SetChild(
      id: id,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
    );
  }

  @override
  List<Object?> get props => [id, reps, weight, unit];
}
