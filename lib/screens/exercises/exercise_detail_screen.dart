import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../app_repositories.dart';
import '../../core/app_logger.dart';
import '../../core/exercise_stats.dart';
import '../../models/exercise.dart';
import '../../models/exercise_log.dart';
import '../../models/set_child.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/exercise_stats_card.dart';
import '../../widgets/set_row_widget.dart';
import '../progress/exercise_progress_screen.dart';
import 'alternatives_picker_screen.dart';
import 'exercise_form_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  final ExerciseRepository exerciseRepo;

  /// The workout this screen was opened from, if any. Stats then cover only
  /// that workout, and new logs are tagged with it.
  final Workout? workout;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    required this.exerciseRepo,
    this.workout,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final _uuid = const Uuid();
  late Exercise _exercise;
  List<Exercise> _alternatives = [];
  List<ExerciseLog> _logs = [];
  Map<String, Workout> _workoutsById = {};
  bool _statsRequested = false;
  // Set while this screen's "Removed … Undo" snackbar may be showing.
  ScaffoldMessengerState? _undoMessenger;

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
    _loadAlternatives();
  }

  @override
  void dispose() {
    // Snackbars are app-wide; don't let Undo outlive the screen it belongs to.
    _undoMessenger?.hideCurrentSnackBar();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_statsRequested) {
      _statsRequested = true;
      _loadStats();
    }
  }

  /// Loads this exercise's logs and all workouts, for the stats card and the
  /// log sheet.
  Future<void> _loadStats() async {
    final repos = AppRepositories.of(context);
    final logs = await repos.exerciseLogRepo.getByExerciseId(_exercise.id);
    final workouts = await repos.workoutRepo.getAll();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _workoutsById = {for (final w in workouts) w.id: w};
    });
  }

  Future<void> _openProgress() async {
    final repos = AppRepositories.of(context);
    final w = widget.workout;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseProgressScreen(
          exercise: _exercise,
          logRepo: repos.exerciseLogRepo,
          initialWorkoutFilter:
              w == null ? WorkoutFilter.all : WorkoutFilter.workout(w.id),
        ),
      ),
    );
    // Logs may have been edited or deleted there.
    await _loadStats();
  }

  Future<void> _loadAlternatives() async {
    final alts = await widget.exerciseRepo.getAlternatives(_exercise.id);
    if (mounted) setState(() => _alternatives = alts);
  }

  Future<void> _editAlternatives() async {
    final selected = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AlternativesPickerScreen(
          exercise: _exercise,
          initialSelection: {for (final a in _alternatives) a.id},
          exerciseRepo: widget.exerciseRepo,
        ),
      ),
    );
    if (selected == null) return;
    await widget.exerciseRepo.setAlternatives(_exercise.id, selected);
    await _loadAlternatives();
  }

  Future<void> _removeAlternative(Exercise alt) async {
    setState(() => _alternatives.remove(alt));
    await widget.exerciseRepo.removeAlternative(_exercise.id, alt.id);
    if (!mounted) return;
    _undoMessenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${alt.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await widget.exerciseRepo.addAlternative(_exercise.id, alt.id);
            await _loadAlternatives();
          },
        ),
      ));
  }

  Future<void> _openAlternative(Exercise alt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exercise: alt,
          exerciseRepo: widget.exerciseRepo,
          // Swapping in an alternative still counts toward this workout.
          workout: widget.workout,
        ),
      ),
    );
    // Links may have been edited from the other exercise's side.
    await _refresh();
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
    await _loadAlternatives();
    await _loadStats();
  }

  void _showLogDialog(BuildContext context, ExerciseLogRepository logRepo) {
    // Workout to tag the log with (null = no workout). Defaults to the
    // workout this screen was opened from.
    String? workoutId = widget.workout?.id;
    List<SetChild> sets = startingSets(_exercise, _logs, workoutId);
    // Once the user touches the sets, picking another workout won't refill them.
    var setsEdited = false;
    DateTime date = DateTime.now();
    final notesCtrl = TextEditingController();
    final workouts = _workoutsById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final id = workoutId;
            final workoutName = _workoutsById[id]?.name;
            final lastInWorkout = id == null
                ? null
                : computeExerciseStats(_logs, WorkoutFilter.workout(id)).last;
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
                    Text(
                        workoutName == null
                            ? 'Log: ${_exercise.name}'
                            : 'Log: ${_exercise.name} · $workoutName',
                        style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: workoutId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Workout'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('No workout')),
                        for (final w in workouts)
                          DropdownMenuItem<String?>(
                              value: w.id,
                              child: Text(w.name,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setModalState(() {
                        workoutId = v;
                        if (!setsEdited) {
                          sets = startingSets(_exercise, _logs, v);
                        }
                      }),
                    ),
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
                              setsEdited = true;
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
                    if (!setsEdited)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          lastInWorkout != null
                              ? 'Starting from your last $workoutName log '
                                  '(${DateFormat('dd/MM/yy').format(lastInWorkout.date)})'
                              : 'Starting from the set template',
                          style: hintStyle,
                        ),
                      ),
                    ...sets.asMap().entries.map((e) {
                      final idx = e.key;
                      return SetRowWidget(
                        key: ValueKey(e.value.id),
                        set: e.value,
                        onChanged: (updated) {
                          setModalState(() {
                            setsEdited = true;
                            sets[idx] = updated;
                          });
                        },
                        onDelete: () {
                          setModalState(() {
                            setsEdited = true;
                            sets.removeAt(idx);
                          });
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
                            workoutId: workoutId,
                            workoutName: workoutName,
                          );
                          try {
                            await logRepo.insert(entry);
                            _loadStats();
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
            16, 16, 16, 88 + MediaQuery.paddingOf(context).bottom),
        children: [
          ExerciseStatsCard(
            logs: _logs,
            workout: widget.workout,
            workoutsById: _workoutsById,
            onSeeProgress: _openProgress,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Alternatives',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                icon: Icon(_alternatives.isEmpty ? Icons.add : Icons.edit,
                    size: 18),
                label: Text(_alternatives.isEmpty ? 'Add' : 'Edit'),
                onPressed: _editAlternatives,
              ),
            ],
          ),
          if (_alternatives.isEmpty)
            Text(
              'Exercises you can swap in if the equipment is busy.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            )
          else ...[
            Text(
              'Tap to open \u00b7 swipe left to remove',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            for (final alt in _alternatives)
              Dismissible(
                key: ValueKey('alt-${alt.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(Icons.link_off,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => _removeAlternative(alt),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(alt.name),
                  subtitle: alt.aliases.isEmpty
                      ? null
                      : Text(alt.aliases.join(', '),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAlternative(alt),
                ),
              ),
          ],
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

