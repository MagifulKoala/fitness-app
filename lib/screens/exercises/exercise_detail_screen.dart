import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../app_repositories.dart';
import '../../core/app_logger.dart';
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

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    final updated = await widget.exerciseRepo.getById(_exercise.id);
    if (updated != null && mounted) {
      setState(() => _exercise = updated);
    }
  }

  void _showLogDialog(BuildContext context, ExerciseLogRepository logRepo) {
    List<SetChild> sets = _exercise.setTemplate.sets
        .map((s) => s.copyWith())
        .map((s) => SetChild(id: _uuid.v4(), reps: s.reps, weight: s.weight, unit: s.unit))
        .toList();
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
                          final entry = ExerciseLog(
                            id: _uuid.v4(),
                            exerciseId: _exercise.id,
                            date: date,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            sets: sets,
                          );
                          try {
                            await logRepo.insert(entry);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => _StatusDialog(
                                  message: 'Log successful',
                                  color: const Color(0xFFB7F0C2),
                                  onClose: () => Navigator.pop(context),
                                ),
                              );
                            }
                          } catch (e, st) {
                            log.e('[ExerciseDetail] log insert failed', error: e, stackTrace: st);
                            if (ctx.mounted) {
                              showDialog(
                                context: ctx,
                                builder: (_) => _StatusDialog(
                                  message: 'Exercise log failed',
                                  color: const Color(0xFFFFC1C1),
                                  onClose: () => Navigator.pop(ctx),
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
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
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
          if (_exercise.links.isNotEmpty) ...[
            Text('Links', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ..._exercise.links.map((l) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text(
                    l.label.isNotEmpty ? l.label : l.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: l.label.isNotEmpty
                      ? Text(l.url,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _launchUrl(context, l.url),
                )),
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
        heroTag: null,
        icon: const Icon(Icons.add_chart),
        label: const Text('Log'),
        onPressed: () => _showLogDialog(context, repos.exerciseLogRepo),
      ),
    );
  }
}

class _StatusDialog extends StatelessWidget {
  final String message;
  final Color color;
  final VoidCallback onClose;

  const _StatusDialog({
    required this.message,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 15, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(message,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

