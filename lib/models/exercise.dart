import 'package:equatable/equatable.dart';
import 'exercise_link.dart';
import 'set_template.dart';

class Exercise extends Equatable {
  final String id;
  final String name;
  final List<String> aliases;
  final String? notes;
  final SetTemplate setTemplate;
  final List<ExerciseLink> links;

  const Exercise({
    required this.id,
    required this.name,
    required this.aliases,
    this.notes,
    required this.setTemplate,
    required this.links,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'aliases': aliases.join(','),
      'notes': notes,
    };
  }

  factory Exercise.fromMap(
    Map<String, dynamic> map,
    SetTemplate setTemplate,
    List<ExerciseLink> links,
  ) {
    final aliasRaw = map['aliases'] as String? ?? '';
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      aliases: aliasRaw.isEmpty ? [] : aliasRaw.split(','),
      notes: map['notes'] as String?,
      setTemplate: setTemplate,
      links: links,
    );
  }

  Exercise copyWith({
    String? name,
    List<String>? aliases,
    String? notes,
    SetTemplate? setTemplate,
    List<ExerciseLink>? links,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      notes: notes ?? this.notes,
      setTemplate: setTemplate ?? this.setTemplate,
      links: links ?? this.links,
    );
  }

  @override
  List<Object?> get props => [id, name, aliases, notes, setTemplate, links];
}
