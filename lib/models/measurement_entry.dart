import 'package:equatable/equatable.dart';

class MeasurementEntry extends Equatable {
  final String id;
  final String measurementId;
  final double value;
  final String unit; // e.g. 'kg', 'lbs', 'cm', 'in'
  final DateTime date;

  const MeasurementEntry({
    required this.id,
    required this.measurementId,
    required this.value,
    required this.unit,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'measurement_id': measurementId,
      'value': value,
      'unit': unit,
      'date': date.toIso8601String(),
    };
  }

  factory MeasurementEntry.fromMap(Map<String, dynamic> map) {
    return MeasurementEntry(
      id: map['id'] as String,
      measurementId: map['measurement_id'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }

  MeasurementEntry copyWith({double? value, String? unit, DateTime? date}) {
    return MeasurementEntry(
      id: id,
      measurementId: measurementId,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      date: date ?? this.date,
    );
  }

  @override
  List<Object?> get props => [id, measurementId, value, unit, date];
}
