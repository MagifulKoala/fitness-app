import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/exercise.dart';
import '../../models/exercise_log.dart';
import '../../models/set_child.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/progress_line_chart.dart';
import '../../widgets/set_row_widget.dart';

class ExerciseProgressScreen extends StatefulWidget {
  final Exercise exercise;
  final ExerciseLogRepository logRepo;

  const ExerciseProgressScreen({
    super.key,
    required this.exercise,
    required this.logRepo,
  });

  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  List<ExerciseLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await widget.logRepo.getByExerciseId(widget.exercise.id);
    setState(() {
      _logs = logs.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            : _logs.isEmpty
                ? const Center(child: Text('No logs yet.'))
                : TabBarView(
                    children: [
                      _GraphView(
                        logs: _logs,
                        logRepo: widget.logRepo,
                        onChanged: () => _load(),
                      ),
                      _TableView(
                        logs: _logs,
                        logRepo: widget.logRepo,
                        onChanged: () => _load(),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ── Graph ────────────────────────────────────────────────────────────────────

class _GraphView extends StatefulWidget {
  final List<ExerciseLog> logs;
  final ExerciseLogRepository logRepo;
  final VoidCallback onChanged;

  const _GraphView({
    required this.logs,
    required this.logRepo,
    required this.onChanged,
  });

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  ExerciseLog? _selectedLog;

  void _onSpotTouched(int index) {
    final log = index >= 0 && index < widget.logs.length ? widget.logs[index] : null;
    setState(() => _selectedLog = (_selectedLog?.id == log?.id) ? null : log);
  }

  @override
  Widget build(BuildContext context) {
    final weightSpots = widget.logs
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgWeight))
        .toList();
    final volumeSpots = widget.logs
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
        .toList();
    final dates = widget.logs.map((l) => l.date).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressLineChart(
              series: [
                ChartSeries(label: 'Avg Weight', spots: weightSpots, color: Colors.blue),
                ChartSeries(label: 'Volume', spots: volumeSpots, color: Colors.orange),
              ],
              dates: dates,
              onSpotTouched: _onSpotTouched,
            ),
            if (_selectedLog != null) ...[
              const SizedBox(height: 16),
              _LogDetailPanel(
                log: _selectedLog!,
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
  final ExerciseLogRepository logRepo;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const _LogDetailPanel({
    required this.log,
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

  const _TableView({
    required this.logs,
    required this.logRepo,
    required this.onChanged,
  });

  void _openEdit(BuildContext context, ExerciseLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExerciseLogEditSheet(
        log: log,
        logRepo: logRepo,
        onSaved: onChanged,
        onDeleted: onChanged,
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<DataColumn> columns, List<DataRow> rows) {
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
                    const DataColumn(label: Text('Avg Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: SizedBox.shrink()),
                  ],
                  reversed.map((l) => DataRow(cells: [
                    DataCell(Text(l.avgWeight.toStringAsFixed(2))),
                    DataCell(Text(l.sets.isNotEmpty ? l.sets.first.unit : '-')),
                    DataCell(Text(DateFormat('dd/MM/yy').format(l.date))),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _openEdit(context, l),
                    )),
                  ])).toList(),
                ),
                _buildTable(
                  context,
                  [
                    const DataColumn(label: Text('Volume', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataColumn(label: SizedBox.shrink()),
                  ],
                  reversed.map((l) => DataRow(cells: [
                    DataCell(Text(l.volume.toStringAsFixed(2))),
                    DataCell(Text(DateFormat('dd/MM/yy').format(l.date))),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _openEdit(context, l),
                    )),
                  ])).toList(),
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
  final ExerciseLogRepository logRepo;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _ExerciseLogEditSheet({
    required this.log,
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
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _date = widget.log.date;
    _sets = widget.log.sets
        .map((s) => SetChild(id: s.id, reps: s.reps, weight: s.weight, unit: s.unit))
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
    final updated = ExerciseLog(
      id: widget.log.id,
      exerciseId: widget.log.exerciseId,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      sets: _sets,
    );
    try {
      await widget.logRepo.update(updated);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Successfully saved'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
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
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
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
                Text('Edit Log', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DatePickerField(
              date: _date,
              onChanged: (d) => setState(() { _date = d; _dirty = true; }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sets', style: TextStyle(fontWeight: FontWeight.bold)),
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
                onChanged: (updated) => setState(() { _sets[idx] = updated; _dirty = true; }),
                onDelete: () => setState(() { _sets.removeAt(idx); _dirty = true; }),
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
