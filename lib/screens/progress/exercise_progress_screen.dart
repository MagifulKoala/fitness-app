import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app_repositories.dart';
import '../../core/exercise_stats.dart';
import '../../models/exercise.dart';
import '../../models/exercise_log.dart';
import '../../models/set_child.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../widgets/chart_filter_bar.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/progress_line_chart.dart';
import '../../widgets/set_row_widget.dart';

// Aggregate exercise logs into (date, avgWeight, volume) points.
// In raw mode returns one point per log; otherwise collapses by period.
@visibleForTesting
List<({DateTime date, double avgWeight, double volume})> aggregateLogs(
    List<ExerciseLog> logs, ChartGranularity granularity) {
  if (granularity == ChartGranularity.raw) {
    return logs
        .map((l) => (date: l.date, avgWeight: l.avgWeight, volume: l.volume))
        .toList();
  }
  final groups = <String, List<ExerciseLog>>{};
  for (final entry in logs) {
    groups.putIfAbsent(periodKey(entry.date, granularity), () => []).add(entry);
  }
  final sortedKeys = groups.keys.toList()..sort();
  return sortedKeys.map((key) {
    final g = groups[key]!;
    return (
      date: g.first.date,
      avgWeight: g.fold(0.0, (s, l) => s + l.avgWeight) / g.length,
      volume: g.fold(0.0, (s, l) => s + l.volume),
    );
  }).toList();
}

class ExerciseProgressScreen extends StatefulWidget {
  final Exercise exercise;
  final ExerciseLogRepository logRepo;

  /// Workout selected when the screen opens: All workouts from the Progress
  /// tab, a specific workout from the stats card's "See progress".
  final WorkoutFilter initialWorkoutFilter;

  const ExerciseProgressScreen({
    super.key,
    required this.exercise,
    required this.logRepo,
    this.initialWorkoutFilter = WorkoutFilter.all,
  });

  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  List<ExerciseLog> _logs = [];
  Map<String, Workout> _workoutsById = {};
  WorkoutRepository? _workoutRepo;
  bool _loading = true;
  ChartFilter _filter = ChartFilter.all;
  late WorkoutFilter _workoutFilter;
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 29));
  DateTime _customTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _workoutFilter = widget.initialWorkoutFilter;
    final now = DateTime.now();
    _customTo = DateTime(now.year, now.month, now.day);
    _customFrom = _customTo.subtract(const Duration(days: 29));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workoutRepo == null) {
      _workoutRepo = AppRepositories.of(context).workoutRepo;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await widget.logRepo.getByExerciseId(widget.exercise.id);
    final workouts = await _workoutRepo!.getAll();
    if (!mounted) return;
    setState(() {
      _logs = logs.reversed.toList(); // ASC: oldest first
      _workoutsById = {for (final w in workouts) w.id: w};
      _loading = false;
    });
  }

  String? _workoutLabel(ExerciseLog l) => workoutLabel(l, _workoutsById);

  List<ExerciseLog> get _filteredLogs {
    final byWorkout = _logs.where(_workoutFilter.matches).toList();
    if (_filter == ChartFilter.all) return byWorkout;
    final start = windowStart(_filter, _customFrom);
    final end = windowEnd(_filter, _customTo);
    return byWorkout.where((l) {
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;
    final ChartGranularity granularity;
    final bool dots;
    if (filteredLogs.length >= 2) {
      granularity = adaptiveGranularity(filteredLogs.first.date, filteredLogs.last.date);
      dots = filteredLogs.last.date.difference(filteredLogs.first.date).inDays <= 60;
    } else {
      granularity = granularityFor(_filter, _customFrom, _customTo);
      dots = showDots(_filter, _customFrom, _customTo);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.name),
          bottom: const TabBar(
            tabs: [Tab(text: 'Graph'), Tab(text: 'Table')],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_logs.isNotEmpty) _buildWorkoutDropdown(),
                  ChartFilterBar(
                    selected: _filter,
                    customFrom: _customFrom,
                    customTo: _customTo,
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onFromChanged: (d) => setState(() => _customFrom = d),
                    onToChanged: (d) => setState(() => _customTo = d),
                  ),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(child: Text('No logs yet.'))
                        : filteredLogs.isEmpty
                            ? const Center(
                                child: Text('No data in this period.'))
                            : TabBarView(
                                children: [
                                  _GraphView(
                                    logs: filteredLogs,
                                    granularity: granularity,
                                    showDots: dots,
                                    logRepo: widget.logRepo,
                                    onChanged: _load,
                                    filter: _filter,
                                    workoutFilter: _workoutFilter,
                                    workoutLabel: _workoutLabel,
                                    workoutsById: _workoutsById,
                                  ),
                                  _TableView(
                                    logs: filteredLogs,
                                    logRepo: widget.logRepo,
                                    onChanged: _load,
                                    workoutLabel: _workoutLabel,
                                    workoutsById: _workoutsById,
                                  ),
                                ],
                              ),
                  ),
                  // Keep the chart / table clear of the system nav bar.
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
      ),
    );
  }

  /// "Workout: [All workouts ▾]" — only workouts this exercise was logged in.
  Widget _buildWorkoutDropdown() {
    final options = workoutFilterOptions(_logs, _workoutsById);
    // Opened pre-filtered on a workout with no logs (or its last log was just
    // deleted): keep it selectable so the dropdown has a matching item.
    if (!options.any((o) => o.filter == _workoutFilter)) {
      options.add(WorkoutFilterOption(
        filter: _workoutFilter,
        label: _workoutFilter.workoutId == null
            ? 'No workout'
            : _workoutsById[_workoutFilter.workoutId]?.name ?? 'Workout',
        count: 0,
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DropdownButtonFormField<WorkoutFilter>(
        key: ValueKey(_workoutFilter),
        initialValue: _workoutFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Workout',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o.filter,
              child: Text(
                '${o.label}${o.deleted ? ' (deleted)' : ''} · ${o.count}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (f) {
          if (f != null) setState(() => _workoutFilter = f);
        },
      ),
    );
  }
}

// ── Graph ────────────────────────────────────────────────────────────────────

class _GraphView extends StatefulWidget {
  final List<ExerciseLog> logs;
  final ChartGranularity granularity;
  final bool showDots;
  final ExerciseLogRepository logRepo;
  final VoidCallback onChanged;
  final ChartFilter filter;
  final WorkoutFilter workoutFilter;
  final String? Function(ExerciseLog) workoutLabel;
  final Map<String, Workout> workoutsById;

  const _GraphView({
    required this.logs,
    required this.granularity,
    required this.showDots,
    required this.logRepo,
    required this.onChanged,
    required this.filter,
    required this.workoutFilter,
    required this.workoutLabel,
    required this.workoutsById,
  });

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  ExerciseLog? _selectedLog;

  @override
  void didUpdateWidget(_GraphView old) {
    super.didUpdateWidget(old);
    if (old.granularity != widget.granularity ||
        old.filter != widget.filter ||
        old.workoutFilter != widget.workoutFilter) {
      _selectedLog = null;
    }
  }

  void _onSpotTouched(int index) {
    final log =
        index >= 0 && index < widget.logs.length ? widget.logs[index] : null;
    setState(() =>
        _selectedLog = (_selectedLog?.id == log?.id) ? null : log);
  }

  @override
  Widget build(BuildContext context) {
    final points = aggregateLogs(widget.logs, widget.granularity);
    final weightSpots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgWeight))
        .toList();
    final volumeSpots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
        .toList();
    final dates = points.map((p) => p.date).toList();
    if (points.isEmpty) {
      return const Center(child: Text('No data in this period.'));
    }

    final isRaw = widget.granularity == ChartGranularity.raw;
    final showDots = points.length == 1 ? true : widget.showDots;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressLineChart(
              series: [
                ChartSeries(
                    label: 'Avg Weight',
                    spots: weightSpots,
                    color: Colors.blue),
                ChartSeries(
                    label: 'Volume',
                    spots: volumeSpots,
                    color: Colors.orange),
              ],
              dates: dates,
              showDots: showDots,
              onSpotTouched: isRaw ? _onSpotTouched : null,
              granularity: widget.granularity,
            ),
            if (_selectedLog != null && isRaw) ...[
              const SizedBox(height: 16),
              _LogDetailPanel(
                log: _selectedLog!,
                workoutName: widget.workoutLabel(_selectedLog!),
                workoutsById: widget.workoutsById,
                logRepo: widget.logRepo,
                onClose: () => setState(() => _selectedLog = null),
                onChanged: () {
                  setState(() => _selectedLog = null);
                  widget.onChanged();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Log detail panel ─────────────────────────────────────────────────────────

class _LogDetailPanel extends StatelessWidget {
  final ExerciseLog log;
  final String? workoutName;
  final Map<String, Workout> workoutsById;
  final ExerciseLogRepository logRepo;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const _LogDetailPanel({
    required this.log,
    required this.workoutName,
    required this.workoutsById,
    required this.logRepo,
    required this.onClose,
    required this.onChanged,
  });

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExerciseLogEditSheet(
        log: log,
        workoutsById: workoutsById,
        logRepo: logRepo,
        onSaved: onChanged,
        onDeleted: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(log.date),
                  style: theme.textTheme.titleMedium,
                ),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      onPressed: () => _openEdit(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClose,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
            Text(workoutName ?? 'No workout',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(log.notes!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            ...log.sets.asMap().entries.map((e) {
              final s = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Set ${e.key + 1}: ${s.reps} reps × ${s.weight} ${s.unit}',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Table ────────────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  final List<ExerciseLog> logs;
  final ExerciseLogRepository logRepo;
  final VoidCallback onChanged;
  final String? Function(ExerciseLog) workoutLabel;
  final Map<String, Workout> workoutsById;

  const _TableView({
    required this.logs,
    required this.logRepo,
    required this.onChanged,
    required this.workoutLabel,
    required this.workoutsById,
  });

  static const _workoutHeader = DataColumn(
      label: Text('Workout', style: TextStyle(fontWeight: FontWeight.bold)));

  DataCell _workoutCell(ExerciseLog l) =>
      DataCell(Text(workoutLabel(l) ?? '-'));

  void _openEdit(BuildContext context, ExerciseLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExerciseLogEditSheet(
        log: log,
        workoutsById: workoutsById,
        logRepo: logRepo,
        onSaved: onChanged,
        onDeleted: onChanged,
      ),
    );
  }

  Widget _buildTable(
      BuildContext context, List<DataColumn> columns, List<DataRow> rows) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columnSpacing: 24, columns: columns, rows: rows),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reversed = logs.reversed.toList();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Weight'), Tab(text: 'Volume')]),
          Expanded(
            child: TabBarView(
              children: [
                _buildTable(
                  context,
                  [
                    const DataColumn(
                        label: Text('Avg Weight',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(
                        label: Text('Unit',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(
                        label: Text('Date',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    _workoutHeader,
                    const DataColumn(label: SizedBox.shrink()),
                  ],
                  reversed
                      .map((l) => DataRow(cells: [
                            DataCell(Text(l.avgWeight.toStringAsFixed(2))),
                            DataCell(Text(
                                l.sets.isNotEmpty ? l.sets.first.unit : '-')),
                            DataCell(
                                Text(DateFormat('dd/MM/yy').format(l.date))),
                            _workoutCell(l),
                            DataCell(IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _openEdit(context, l),
                            )),
                          ]))
                      .toList(),
                ),
                _buildTable(
                  context,
                  [
                    const DataColumn(
                        label: Text('Volume',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(
                        label: Text('Date',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    _workoutHeader,
                    const DataColumn(label: SizedBox.shrink()),
                  ],
                  reversed
                      .map((l) => DataRow(cells: [
                            DataCell(Text(l.volume.toStringAsFixed(2))),
                            DataCell(
                                Text(DateFormat('dd/MM/yy').format(l.date))),
                            _workoutCell(l),
                            DataCell(IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _openEdit(context, l),
                            )),
                          ]))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit sheet ───────────────────────────────────────────────────────────────

class _ExerciseLogEditSheet extends StatefulWidget {
  final ExerciseLog log;
  final Map<String, Workout> workoutsById;
  final ExerciseLogRepository logRepo;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _ExerciseLogEditSheet({
    required this.log,
    required this.workoutsById,
    required this.logRepo,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_ExerciseLogEditSheet> createState() => _ExerciseLogEditSheetState();
}

class _ExerciseLogEditSheetState extends State<_ExerciseLogEditSheet> {
  final _uuid = const Uuid();
  late DateTime _date;
  late List<SetChild> _sets;
  late TextEditingController _notesCtrl;
  late String? _workoutId;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _workoutId = widget.log.workoutId;
    _date = widget.log.date;
    _sets = widget.log.sets
        .map((s) =>
            SetChild(id: s.id, reps: s.reps, weight: s.weight, unit: s.unit))
        .toList();
    _notesCtrl = TextEditingController(text: widget.log.notes ?? '');
    _notesCtrl.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _workoutId;
    final updated = ExerciseLog(
      id: widget.log.id,
      exerciseId: widget.log.exerciseId,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      sets: _sets,
      workoutId: id,
      // Current name while the workout exists; a deleted one keeps its
      // stored name.
      workoutName: id == null
          ? null
          : widget.workoutsById[id]?.name ??
              (id == widget.log.workoutId ? widget.log.workoutName : null),
    );
    try {
      await widget.logRepo.update(updated);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Successfully saved'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Save failed'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );
    }
  }

  /// Lets a mis-tagged or untagged (pre-v5) log be moved to another workout.
  Widget _buildWorkoutField() {
    final workouts = widget.workoutsById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final original = widget.log.workoutId;
    final originalDeleted =
        original != null && !widget.workoutsById.containsKey(original);
    return DropdownButtonFormField<String?>(
      initialValue: _workoutId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Workout'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('No workout')),
        for (final w in workouts)
          DropdownMenuItem<String?>(
              value: w.id,
              child: Text(w.name, overflow: TextOverflow.ellipsis)),
        if (originalDeleted)
          DropdownMenuItem<String?>(
            value: original,
            child: Text(
                '${widget.log.workoutName ?? 'Deleted workout'} (deleted)',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() {
        _workoutId = v;
        _dirty = true;
      }),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.logRepo.delete(widget.log.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Log',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWorkoutField(),
            const SizedBox(height: 12),
            DatePickerField(
              date: _date,
              onChanged: (d) => setState(() {
                _date = d;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
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
                  onPressed: () => setState(() {
                    _dirty = true;
                    _sets.add(SetChild(
                      id: _uuid.v4(),
                      reps: _sets.isNotEmpty ? _sets.last.reps : 10,
                      weight: _sets.isNotEmpty ? _sets.last.weight : 20,
                      unit: _sets.isNotEmpty ? _sets.last.unit : 'kg',
                    ));
                  }),
                ),
              ],
            ),
            ..._sets.asMap().entries.map((e) {
              final idx = e.key;
              return SetRowWidget(
                key: ValueKey(e.value.id),
                set: e.value,
                onChanged: (updated) =>
                    setState(() {
                      _sets[idx] = updated;
                      _dirty = true;
                    }),
                onDelete: () =>
                    setState(() {
                      _sets.removeAt(idx);
                      _dirty = true;
                    }),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dirty ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
