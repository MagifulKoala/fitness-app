import 'package:flutter/material.dart';
import '../../app_repositories.dart';
import '../../core/app_logger.dart';
import '../../db/database_helper.dart';
import '../../services/share_service.dart';
import '../../widgets/date_picker_field.dart';

class DataScreen extends StatefulWidget {
  final VoidCallback onDataCleared;

  const DataScreen({super.key, required this.onDataCleared});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _importing = false;

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('This will delete all data permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.clearAll();
        log.w('[DataScreen] all data cleared by user');
        widget.onDataCleared();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared.')),
          );
        }
      } catch (e, st) {
        log.e('[DataScreen] clearAll failed', error: e, stackTrace: st);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to clear data.')),
          );
        }
      }
    }
  }

  Future<void> _showLogExportSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LogExportSheet(
        logRepo: AppRepositories.of(context).exerciseLogRepo,
        exerciseRepo: AppRepositories.of(context).exerciseRepo,
      ),
    );
  }

  Future<void> _importPlan() async {
    setState(() => _importing = true);
    try {
      final repos = AppRepositories.of(context);
      final planName = await ShareService.importWorkoutPlan(
        repos.exerciseRepo,
        repos.workoutRepo,
        repos.planRepo,
        context,
      );
      if (planName != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "$planName".')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  TextStyle _sectionLabelStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Share', style: _sectionLabelStyle(context)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export logs'),
            subtitle: const Text('Share your exercise history as JSON and text'),
            onTap: _showLogExportSheet,
          ),
          ListTile(
            leading: _importing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            title: const Text('Import workout plan'),
            subtitle: const Text('Load a plan shared by your trainer'),
            onTap: _importing ? null : _importPlan,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Danger zone', style: _sectionLabelStyle(context)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear all data',
                style: TextStyle(color: Colors.red)),
            onTap: _clearAll,
          ),
        ],
      ),
    );
  }
}

// ─── Period picker sheet ───────────────────────────────────────────────────

enum _Period { week, month, custom }

class _LogExportSheet extends StatefulWidget {
  final dynamic logRepo;
  final dynamic exerciseRepo;

  const _LogExportSheet({required this.logRepo, required this.exerciseRepo});

  @override
  State<_LogExportSheet> createState() => _LogExportSheetState();
}

class _LogExportSheetState extends State<_LogExportSheet> {
  _Period _period = _Period.week;
  late DateTime _from;
  late DateTime _to;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 6));
  }

  DateTime get _resolvedFrom {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.week => today.subtract(const Duration(days: 6)),
      _Period.month => today.subtract(const Duration(days: 29)),
      _Period.custom => _from,
    };
  }

  DateTime get _resolvedTo {
    final now = DateTime.now();
    return switch (_period) {
      _Period.week || _Period.month => DateTime(now.year, now.month, now.day),
      _Period.custom => _to,
    };
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ShareService.exportLogs(
        _resolvedFrom,
        _resolvedTo,
        widget.logRepo,
        widget.exerciseRepo,
        context,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Export logs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.week, label: Text('Last 7 days')),
              ButtonSegment(value: _Period.month, label: Text('Last 30 days')),
              ButtonSegment(value: _Period.custom, label: Text('Custom')),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),
          if (_period == _Period.custom) ...[
            const SizedBox(height: 8),
            DatePickerField(
              date: _from,
              label: 'From',
              onChanged: (d) => setState(() => _from = d),
            ),
            const SizedBox(height: 8),
            DatePickerField(
              date: _to,
              label: 'To',
              onChanged: (d) => setState(() => _to = d),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _exporting ? null : _export,
            child: _exporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Export & Share'),
          ),
        ],
      ),
    );
  }
}
