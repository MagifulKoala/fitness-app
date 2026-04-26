import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/measurement.dart';
import '../../models/measurement_entry.dart';
import '../../repositories/measurement_repository.dart';
import '../../widgets/chart_filter_bar.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/progress_line_chart.dart';

// Aggregate measurement entries into (date, value, unit) points.
// In raw mode returns one point per entry; otherwise collapses by period averaging values.
List<({DateTime date, double value, String unit})> _aggregateEntries(
    List<MeasurementEntry> entries, ChartGranularity granularity) {
  if (granularity == ChartGranularity.raw) {
    return entries.map((e) => (date: e.date, value: e.value, unit: e.unit)).toList();
  }
  final groups = <String, List<MeasurementEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(periodKey(entry.date, granularity), () => []).add(entry);
  }
  final sortedKeys = groups.keys.toList()..sort();
  return sortedKeys.map((key) {
    final g = groups[key]!;
    final avg = g.fold(0.0, (s, e) => s + e.value) / g.length;
    return (date: g.first.date, value: avg, unit: g.first.unit);
  }).toList();
}

class MeasurementProgressScreen extends StatefulWidget {
  final Measurement measurement;
  final MeasurementRepository measurementRepo;

  const MeasurementProgressScreen({
    super.key,
    required this.measurement,
    required this.measurementRepo,
  });

  @override
  State<MeasurementProgressScreen> createState() =>
      _MeasurementProgressScreenState();
}

class _MeasurementProgressScreenState extends State<MeasurementProgressScreen> {
  List<MeasurementEntry> _entries = [];
  bool _loading = true;
  ChartFilter _filter = ChartFilter.all;
  late DateTime _customFrom;
  late DateTime _customTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customTo = DateTime(now.year, now.month, now.day);
    _customFrom = _customTo.subtract(const Duration(days: 29));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await widget.measurementRepo.getEntries(widget.measurement.id);
    setState(() {
      _entries = entries; // ASC: oldest first
      _loading = false;
    });
  }

  List<MeasurementEntry> get _filteredEntries {
    final start = windowStart(_filter, _customFrom);
    final end = windowEnd(_filter, _customTo);
    final endNext = end.add(const Duration(days: 1));
    return _entries.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(start) && d.isBefore(endNext);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;
    final granularity = granularityFor(_filter, _customFrom, _customTo);
    final dots = showDots(_filter, _customFrom, _customTo);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.measurement.name),
          bottom: const TabBar(
            tabs: [Tab(text: 'Graph'), Tab(text: 'Table')],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  ChartFilterBar(
                    selected: _filter,
                    customFrom: _customFrom,
                    customTo: _customTo,
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onFromChanged: (d) => setState(() => _customFrom = d),
                    onToChanged: (d) => setState(() => _customTo = d),
                  ),
                  Expanded(
                    child: _entries.isEmpty
                        ? const Center(child: Text('No data yet.'))
                        : filteredEntries.isEmpty
                            ? const Center(child: Text('No data in this period.'))
                            : TabBarView(
                                children: [
                                  _GraphView(
                                    entries: filteredEntries,
                                    granularity: granularity,
                                    showDots: dots,
                                  ),
                                  _TableView(
                                    entries: filteredEntries,
                                    measurementRepo: widget.measurementRepo,
                                    onChanged: () => _load(),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Graph ────────────────────────────────────────────────────────────────────

class _GraphView extends StatelessWidget {
  final List<MeasurementEntry> entries;
  final ChartGranularity granularity;
  final bool showDots;

  const _GraphView({
    required this.entries,
    required this.granularity,
    required this.showDots,
  });

  @override
  Widget build(BuildContext context) {
    final points = _aggregateEntries(entries, granularity);
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final dates = points.map((p) => p.date).toList();
    final unit = points.isNotEmpty ? points.first.unit : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ProgressLineChart(
        series: [
          ChartSeries(label: unit, spots: spots, color: Colors.blue),
        ],
        dates: dates,
        showDots: showDots,
      ),
    );
  }
}

// ── Table ────────────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  final List<MeasurementEntry> entries;
  final MeasurementRepository measurementRepo;
  final VoidCallback onChanged;

  const _TableView({
    required this.entries,
    required this.measurementRepo,
    required this.onChanged,
  });

  void _openEdit(BuildContext context, MeasurementEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MeasurementEditSheet(
        entry: entry,
        measurementRepo: measurementRepo,
        onSaved: onChanged,
        onDeleted: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reversed = entries.reversed.toList();
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: SizedBox.shrink()),
          ],
          rows: reversed.map((e) => DataRow(cells: [
            DataCell(Text(e.value.toString())),
            DataCell(Text(e.unit)),
            DataCell(Text(DateFormat('dd/MM/yy').format(e.date))),
            DataCell(IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _openEdit(context, e),
            )),
          ])).toList(),
        ),
      ),
    );
  }
}

// ── Edit sheet ───────────────────────────────────────────────────────────────

class _MeasurementEditSheet extends StatefulWidget {
  final MeasurementEntry entry;
  final MeasurementRepository measurementRepo;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _MeasurementEditSheet({
    required this.entry,
    required this.measurementRepo,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_MeasurementEditSheet> createState() => _MeasurementEditSheetState();
}

class _MeasurementEditSheetState extends State<_MeasurementEditSheet> {
  late TextEditingController _valueCtrl;
  late String _unit;
  late DateTime _date;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _valueCtrl = TextEditingController(text: widget.entry.value.toString());
    _unit = widget.entry.unit;
    _date = widget.entry.date;
    _valueCtrl.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = double.tryParse(_valueCtrl.text);
    if (val == null) return;
    try {
      await widget.measurementRepo.updateEntry(
        widget.entry.copyWith(value: val, unit: _unit, date: _date),
      );
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
      await widget.measurementRepo.deleteEntry(widget.entry.id);
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
                Text('Edit Entry', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _unit,
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'lbs', child: Text('lbs')),
                    DropdownMenuItem(value: 'cm', child: Text('cm')),
                    DropdownMenuItem(value: 'in', child: Text('in')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() { _unit = v; _dirty = true; });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            DatePickerField(
              date: _date,
              onChanged: (d) => setState(() { _date = d; _dirty = true; }),
            ),
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
