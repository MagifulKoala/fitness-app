import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/bottom_action_bar.dart';

/// Picks which exercises are alternatives of [exercise]. Pops with the chosen
/// set of exercise ids, or null if the user backs out without saving.
class AlternativesPickerScreen extends StatefulWidget {
  final Exercise exercise;
  final Set<String> initialSelection;
  final ExerciseRepository exerciseRepo;

  const AlternativesPickerScreen({
    super.key,
    required this.exercise,
    required this.initialSelection,
    required this.exerciseRepo,
  });

  @override
  State<AlternativesPickerScreen> createState() =>
      _AlternativesPickerScreenState();
}

class _AlternativesPickerScreenState extends State<AlternativesPickerScreen> {
  late final Set<String> _selected = {...widget.initialSelection};
  List<Exercise> _candidates = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.exerciseRepo.getAll();
    if (!mounted) return;
    setState(() {
      // Current alternatives first, sorted once so rows don't jump on toggle.
      _candidates = all.where((e) => e.id != widget.exercise.id).toList()
        ..sort((a, b) {
          final sa = widget.initialSelection.contains(a.id) ? 0 : 1;
          final sb = widget.initialSelection.contains(b.id) ? 0 : 1;
          return sa != sb ? sa - sb : a.name.compareTo(b.name);
        });
      _loading = false;
    });
  }

  List<Exercise> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _candidates;
    return _candidates
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.aliases.any((a) => a.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text('Alternatives: ${widget.exercise.name}')),
      bottomNavigationBar: BottomActionBar(
        label: 'Save (${_selected.length} selected)',
        onPressed: _loading ? null : () => Navigator.pop(context, _selected),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by name or alias…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Linked both ways: ${widget.exercise.name} also shows up '
                    'as an alternative of each exercise you pick.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: _candidates.isEmpty
                      ? const Center(child: Text('No other exercises yet.'))
                      : filtered.isEmpty
                      ? Center(child: Text('No exercises match "$_query"'))
                      : ListView(
                          children: [
                            for (final ex in filtered)
                              CheckboxListTile(
                                title: Text(ex.name),
                                subtitle: ex.aliases.isEmpty
                                    ? null
                                    : Text(ex.aliases.join(', ')),
                                value: _selected.contains(ex.id),
                                onChanged: (v) => setState(
                                  () => v == true
                                      ? _selected.add(ex.id)
                                      : _selected.remove(ex.id),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
