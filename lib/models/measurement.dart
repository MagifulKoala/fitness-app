import 'package:equatable/equatable.dart';

class Measurement extends Equatable {
  final String id;
  final String name;

  const Measurement({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  Measurement copyWith({String? name}) =>
      Measurement(id: id, name: name ?? this.name);

  @override
  List<Object?> get props => [id, name];
}
