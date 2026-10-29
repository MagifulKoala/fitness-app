import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/exercise.dart';
import '../../models/exercise_link.dart';
import '../../models/set_child.dart';
import '../../models/set_template.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/link_row_widget.dart';
import '../../widgets/set_row_widget.dart';
import '../../widgets/bottom_action_bar.dart';

class ExerciseFormScreen extends StatefulWidget {
  final ExerciseRepository exerciseRepo;
  final Exercise? exercise; // null = create

  const ExerciseFormScreen({
    super.key,
    required this.exerciseRepo,
    this.exercise,
  });

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _aliasesCtrl;
  late TextEditingController _notesCtrl;
  late List<SetChild> _sets;
  late List<ExerciseLink> _links;
  bool _saving = false;

  bool get _isEdit => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _aliasesCtrl =
        TextEditingController(text: ex?.aliases.join(', ') ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
    _sets = ex != null
        ? List.of(ex.setTemplate.sets)
        : [
            SetChild(
              id: _uuid.v4(),
              reps: 10,
              weight: 20,
              unit: 'kg',
            )
          ];
    _links = ex != null ? List.of(ex.links) : [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aliasesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final aliases = _aliasesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final links = _links
          .map((l) {
            var url = l.url.trim();
            if (url.isNotEmpty &&
                !url.startsWith('http://') &&
                !url.startsWith('https://')) {
              url = 'https://$url';
            }
            return ExerciseLink(id: l.id, label: l.label.trim(), url: url);
          })
          .where((l) => l.url.isNotEmpty)
          .toList();

      final existing = widget.exercise;
      if (_isEdit && existing != null) {
        final updated = existing.copyWith(
          name: _nameCtrl.text.trim(),
          aliases: aliases,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          setTemplate: existing.setTemplate.copyWith(sets: _sets),
          links: links,
        );
        await widget.exerciseRepo.update(updated);
      } else {
        final templateId = _uuid.v4();
        final exercise = Exercise(
          id: _uuid.v4(),
          name: _nameCtrl.text.trim(),
          aliases: aliases,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          setTemplate: SetTemplate(id: templateId, sets: _sets),
          links: links,
        );
        await widget.exerciseRepo.insert(exercise);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Exercise' : 'New Exercise'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete exercise',
              onPressed: () async {
                final nav = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete exercise?'),
                    content: const Text(
                        'This will remove all logs for this exercise.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await widget.exerciseRepo.delete(widget.exercise!.id);
                  nav.pop();
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: _isEdit ? 'Save Changes' : 'Create Exercise',
        onPressed: _saving ? null : _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aliasesCtrl,
              decoration: const InputDecoration(
                labelText: 'Aliases (comma-separated)',
                hintText: 'e.g. around the world, dumbbell halos',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Links',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add link'),
                  onPressed: () {
                    setState(() {
                      _links.add(ExerciseLink(
                        id: _uuid.v4(),
                        label: '',
                        url: '',
                      ));
                    });
                  },
                ),
              ],
            ),
            ..._links.asMap().entries.map((entry) {
              final idx = entry.key;
              final link = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: LinkRowWidget(
                  key: ValueKey(link.id),
                  link: link,
                  onChanged: (updated) {
                    setState(() => _links[idx] = updated);
                  },
                  onDelete: () {
                    setState(() => _links.removeAt(idx));
                  },
                ),
              );
            }),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sets',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                  onPressed: () {
                    setState(() {
                      _sets.add(SetChild(
                        id: _uuid.v4(),
                        reps: _sets.isNotEmpty ? _sets.last.reps : 10,
                        weight:
                            _sets.isNotEmpty ? _sets.last.weight : 20,
                        unit: _sets.isNotEmpty ? _sets.last.unit : 'kg',
                      ));
                    });
                  },
                ),
              ],
            ),
            ..._sets.asMap().entries.map((entry) {
              final idx = entry.key;
              final set = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SetRowWidget(
                  key: ValueKey(set.id),
                  set: set,
                  onChanged: (updated) {
                    setState(() => _sets[idx] = updated);
                  },
                  onDelete: () {
                    setState(() => _sets.removeAt(idx));
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
