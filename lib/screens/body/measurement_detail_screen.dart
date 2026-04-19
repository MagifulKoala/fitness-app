import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/measurement.dart';
import '../../models/measurement_entry.dart';
import '../../repositories/measurement_repository.dart';
import '../../widgets/date_picker_field.dart';

class MeasurementDetailScreen extends StatefulWidget {
  final Measurement measurement;
  final MeasurementRepository measurementRepo;

  const MeasurementDetailScreen({
    super.key,
    required this.measurement,
    required this.measurementRepo,
  });

  @override
  State<MeasurementDetailScreen> createState() =>
      _MeasurementDetailScreenState();
}

class _MeasurementDetailScreenState extends State<MeasurementDetailScreen> {
  final _uuid = const Uuid();
  List<MeasurementEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries =
        await widget.measurementRepo.getEntries(widget.measurement.id);
    setState(() {
      _entries = entries.reversed.toList(); // newest first for display
      _loading = false;
    });
  }

  void _showEntryDialog({MeasurementEntry? existing}) {
    final valueCtrl = TextEditingController(
        text: existing?.value.toString() ?? '');
    String unit = existing?.unit ?? 'kg';
    DateTime date = existing?.date ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).viewPadding.bottom +
                16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existing == null ? 'Add Entry' : 'Edit Entry',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Value'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'lbs', child: Text('lbs')),
                      DropdownMenuItem(value: 'cm', child: Text('cm')),
                      DropdownMenuItem(value: 'in', child: Text('in')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModal(() => unit = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DatePickerField(
                date: date,
                onChanged: (d) => setModal(() => date = d),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final val = double.tryParse(valueCtrl.text);
                    if (val == null) return;
                    if (existing == null) {
                      final entry = MeasurementEntry(
                        id: _uuid.v4(),
                        measurementId: widget.measurement.id,
                        value: val,
                        unit: unit,
                        date: date,
                      );
                      await widget.measurementRepo.insertEntry(entry);
                    } else {
                      await widget.measurementRepo.updateEntry(
                          existing.copyWith(value: val, unit: unit, date: date));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.measurement.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () {
              final ctrl = TextEditingController(
                  text: widget.measurement.name);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Rename'),
                  content: TextField(controller: ctrl, autofocus: true),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        final name = ctrl.text.trim();
                        if (name.isEmpty) return;
                        await widget.measurementRepo.updateMeasurement(
                            widget.measurement.copyWith(name: name));
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: const Text('Rename'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete measurement',
            onPressed: () async {
              final nav = Navigator.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete measurement?'),
                  content: const Text('All entries will be removed.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await widget.measurementRepo
                    .deleteMeasurement(widget.measurement.id);
                nav.pop();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No entries yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) {
                    final e = _entries[i];
                    return ListTile(
                      title: Text('${e.value} ${e.unit}'),
                      subtitle:
                          Text(DateFormat('dd/MM/yy').format(e.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showEntryDialog(existing: e),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () async {
                              await widget.measurementRepo
                                  .deleteEntry(e.id);
                              _load();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEntryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
