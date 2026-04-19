import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app_repositories.dart';
import '../../models/exercise.dart';
import '../../models/exercise_log.dart';
import '../../models/set_child.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/set_row_widget.dart';
import 'exercise_form_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  final ExerciseRepository exerciseRepo;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    required this.exerciseRepo,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final _uuid = const Uuid();
  late Exercise _exercise;

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
  }

  Future<void> _refresh() async {
    final updated = await widget.exerciseRepo.getById(_exercise.id);
    if (updated != null && mounted) {
      setState(() => _exercise = updated);
    }
  }

  void _showLogDialog(BuildContext context, ExerciseLogRepository logRepo) {
    List<SetChild> sets = List.of(_exercise.setTemplate.sets);
    DateTime date = DateTime.now();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom +
                    16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log: ${_exercise.name}',
                        style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DatePickerField(
                      date: date,
                      onChanged: (d) => setModalState(() => date = d),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sets',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                          onPressed: () {
                            setModalState(() {
                              sets.add(SetChild(
                                id: _uuid.v4(),
                                reps: sets.isNotEmpty ? sets.last.reps : 10,
                                weight:
                                    sets.isNotEmpty ? sets.last.weight : 20,
                                unit: sets.isNotEmpty ? sets.last.unit : 'kg',
                              ));
                            });
                          },
                        ),
                      ],
                    ),
                    ...sets.asMap().entries.map((e) {
                      final idx = e.key;
                      return SetRowWidget(
                        key: ValueKey(e.value.id),
                        set: e.value,
                        onChanged: (updated) {
                          setModalState(() => sets[idx] = updated);
                        },
                        onDelete: () {
                          setModalState(() => sets.removeAt(idx));
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final log = ExerciseLog(
                            id: _uuid.v4(),
                            exerciseId: _exercise.id,
                            date: date,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            sets: sets,
                          );
                          try {
                            await logRepo.insert(log);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFFB7F0C2),
                                  title: const Text('Log successful'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (_) {
                            if (ctx.mounted) {
                              showDialog(
                                context: ctx,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFFFFC1C1),
                                  title: const Text('Exercise log failed'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Log Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // We need the logRepo — it's passed via AppRepositories inherited widget
    final repos = AppRepositories.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_exercise.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExerciseFormScreen(
                    exerciseRepo: widget.exerciseRepo,
                    exercise: _exercise,
                  ),
                ),
              );
              await _refresh();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_exercise.aliases.isNotEmpty) ...[
            Text('Aliases',
                style: Theme.of(context).textTheme.labelLarge),
            Text(_exercise.aliases.join(', ')),
            const SizedBox(height: 12),
          ],
          if (_exercise.notes != null && _exercise.notes!.isNotEmpty) ...[
            Text('Notes', style: Theme.of(context).textTheme.labelLarge),
            Text(_exercise.notes!),
            const SizedBox(height: 12),
          ],
          Text('Current Template',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._exercise.setTemplate.sets.asMap().entries.map((e) {
            final s = e.value;
            return ListTile(
              dense: true,
              leading: Text('Set ${e.key + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text('${s.reps} reps × ${s.weight} ${s.unit}'),
            );
          }),
          if (_exercise.setTemplate.sets.isEmpty)
            const Text('No sets defined yet.'),
          const SizedBox(height: 8),
          Text(
            'Volume: ${_exercise.setTemplate.volume.toStringAsFixed(1)} (adimensional)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_chart),
        label: const Text('Log'),
        onPressed: () => _showLogDialog(context, repos.exerciseLogRepo),
      ),
    );
  }
}

