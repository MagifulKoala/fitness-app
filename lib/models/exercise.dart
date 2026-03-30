import 'package:equatable/equatable.dart';
import 'set_template.dart';

class Exercise extends Equatable {
  final String id;
  final String name;
  final List<String> aliases;
  final String? notes;
  final SetTemplate setTemplate;

  const Exercise({
    required this.id,
    required this.name,
    required this.aliases,
    this.notes,
    required this.setTemplate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'aliases': aliases.join(','),
      'notes': notes,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map, SetTemplate setTemplate) {
    final aliasRaw = map['aliases'] as String? ?? '';
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      aliases: aliasRaw.isEmpty ? [] : aliasRaw.split(','),
      notes: map['notes'] as String?,
      setTemplate: setTemplate,
    );
  }

  Exercise copyWith({
    String? name,
    List<String>? aliases,
    String? notes,
    SetTemplate? setTemplate,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      notes: notes ?? this.notes,
      setTemplate: setTemplate ?? this.setTemplate,
    );
  }

  @override
  List<Object?> get props => [id, name, aliases, notes, setTemplate];
}
