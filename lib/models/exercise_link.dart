import 'package:equatable/equatable.dart';

class ExerciseLink extends Equatable {
  final String id;
  final String label; // empty string = no label; UI falls back to showing url
  final String url;

  const ExerciseLink({
    required this.id,
    required this.label,
    required this.url,
  });

  Map<String, dynamic> toMap({
    required String exerciseId,
    required int sortOrder,
  }) =>
      {
        'id': id,
        'exercise_id': exerciseId,
        'url': url,
        'label': label,
        'sort_order': sortOrder,
      };

  factory ExerciseLink.fromMap(Map<String, dynamic> map) => ExerciseLink(
        id: map['id'] as String,
        label: map['label'] as String? ?? '',
        url: map['url'] as String,
      );

  @override
  List<Object?> get props => [id, label, url];
}
