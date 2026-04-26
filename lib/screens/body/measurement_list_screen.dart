import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/measurement.dart';
import '../../repositories/measurement_repository.dart';
import 'measurement_detail_screen.dart';

class MeasurementListScreen extends StatefulWidget {
  final MeasurementRepository measurementRepo;

  const MeasurementListScreen({super.key, required this.measurementRepo});

  @override
  State<MeasurementListScreen> createState() => _MeasurementListScreenState();
}

class _MeasurementListScreenState extends State<MeasurementListScreen> {
  final _uuid = const Uuid();
  List<Measurement> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await widget.measurementRepo.getAllMeasurements();
    setState(() {
      _measurements = m;
      _loading = false;
    });
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Measurement'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Name', hintText: 'e.g. Chest, Waist, Body Fat %'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final m = Measurement(id: _uuid.v4(), name: name);
              await widget.measurementRepo.insertMeasurement(m);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Body Measurements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _measurements.isEmpty
              ? const Center(
                  child: Text('No measurements yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _measurements.length,
                  itemBuilder: (ctx, i) {
                    final m = _measurements[i];
                    return ListTile(
                      title: Text(m.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => MeasurementDetailScreen(
                              measurement: m,
                              measurementRepo: widget.measurementRepo,
                            ),
                          ),
                        );
                        _load();
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
