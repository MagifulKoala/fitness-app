import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_repositories.dart';
import '../../core/app_logger.dart';
import '../../db/database_helper.dart';
import '../../models/workout_plan.dart';
import '../../repositories/exercise_log_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/share_service.dart';
import '../../widgets/date_picker_field.dart';

class DataScreen extends StatefulWidget {
  final SettingsRepository settingsRepo;
  final VoidCallback onDataCleared;

  const DataScreen({
    super.key,
    required this.settingsRepo,
    required this.onDataCleared,
  });

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  static final _tsFmt = DateFormat('dd MMM yyyy, HH:mm');

  bool _importing = false;
  bool _exportingPlan = false;
  bool _savingBackup = false;
  bool _runningAutoBackup = false;

  String? _backupFolderPath;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  Future<void> _loadBackupSettings() async {
    final folder = await widget.settingsRepo.getBackupFolderPath();
    final ts = await widget.settingsRepo.getBackupLastTimestamp();
    if (mounted) setState(() { _backupFolderPath = folder; _lastBackupTime = ts; });
  }

  Future<void> _pickBackupFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup folder',
    );
    if (path == null) return;
    await widget.settingsRepo.setBackupFolderPath(path);
    if (mounted) setState(() => _backupFolderPath = path);
    await _runBackupNow(showSnackbar: false);
  }

  Future<void> _runBackupNow({bool showSnackbar = true}) async {
    if (_backupFolderPath == null) return;
    setState(() => _runningAutoBackup = true);
    try {
      final repos = AppRepositories.of(context);
      final ok = await ShareService.autoBackupToFolder(
        repos.exerciseRepo,
        repos.exerciseLogRepo,
        widget.settingsRepo,
        _backupFolderPath!,
      );
      if (!mounted) return;
      final ts = await widget.settingsRepo.getBackupLastTimestamp();
      if (!mounted) return;
      setState(() => _lastBackupTime = ts);
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Backup saved.' : 'Backup failed. Check the selected folder.')),
        );
      }
    } finally {
      if (mounted) setState(() => _runningAutoBackup = false);
    }
  }

  String _folderLabel(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.lastWhere((s) => s.isNotEmpty, orElse: () => path);
  }

  Future<void> _saveBackup() async {
    setState(() => _savingBackup = true);
    try {
      final repos = AppRepositories.of(context);
      final ok = await ShareService.saveFullBackup(
        repos.exerciseRepo,
        repos.exerciseLogRepo,
        context,
      );
      if (ok && mounted) {
        await widget.settingsRepo.setBackupLastTimestamp(DateTime.now());
        final ts = await widget.settingsRepo.getBackupLastTimestamp();
        if (mounted) setState(() => _lastBackupTime = ts);
      }
    } finally {
      if (mounted) setState(() => _savingBackup = false);
    }
  }

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
    final repos = AppRepositories.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LogExportSheet(
        logRepo: repos.exerciseLogRepo,
        exerciseRepo: repos.exerciseRepo,
      ),
    );
  }

  Future<void> _exportPlan() async {
    final repos = AppRepositories.of(context);
    final plans = await repos.planRepo.getAll();

    if (!mounted) return;

    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workout plans to export.')),
      );
      return;
    }

    WorkoutPlan? selected;
    if (plans.length == 1) {
      selected = plans.first;
    } else {
      selected = await showDialog<WorkoutPlan>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select plan to export'),
          children: plans
              .map((p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, p),
                    child: Text(p.name),
                  ))
              .toList(),
        ),
      );
    }

    if (selected == null || !mounted) return;

    setState(() => _exportingPlan = true);
    try {
      await ShareService.exportWorkoutPlan(
        selected,
        repos.workoutRepo,
        repos.exerciseRepo,
        context,
      );
    } finally {
      if (mounted) setState(() => _exportingPlan = false);
    }
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

  Widget _loadingIcon(Widget icon, bool loading) => loading
      ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : icon;

  @override
  Widget build(BuildContext context) {
    final hasFolder = _backupFolderPath != null;
    final lastBackupSubtitle = _lastBackupTime != null
        ? _tsFmt.format(_lastBackupTime!)
        : 'Never';

    return Scaffold(
      appBar: AppBar(title: const Text('Data')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Auto backup', style: _sectionLabelStyle(context)),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Backup folder'),
            subtitle: Text(hasFolder ? _folderLabel(_backupFolderPath!) : 'Not set — tap to choose'),
            trailing: hasFolder ? const Icon(Icons.chevron_right) : null,
            onTap: _pickBackupFolder,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Last backup'),
            subtitle: Text(lastBackupSubtitle),
          ),
          ListTile(
            leading: _loadingIcon(const Icon(Icons.backup), _runningAutoBackup),
            title: const Text('Backup now'),
            subtitle: const Text('Save a backup to the selected folder'),
            onTap: (hasFolder && !_runningAutoBackup) ? () => _runBackupNow() : null,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Share', style: _sectionLabelStyle(context)),
          ),
          ListTile(
            leading: _loadingIcon(const Icon(Icons.upload_file), _exportingPlan),
            title: const Text('Export workout plan'),
            subtitle: const Text('Share a plan as a file your trainer can send you'),
            onTap: _exportingPlan ? null : _exportPlan,
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Export logs'),
            subtitle: const Text('Share your exercise history as JSON and text'),
            onTap: _showLogExportSheet,
          ),
          ListTile(
            leading: _loadingIcon(const Icon(Icons.download), _importing),
            title: const Text('Import workout plan'),
            subtitle: const Text('Load a plan shared by your trainer'),
            onTap: _importing ? null : _importPlan,
          ),
          ListTile(
            leading: _loadingIcon(const Icon(Icons.save_alt), _savingBackup),
            title: const Text('Save backup'),
            subtitle: const Text('Save all exercises and logs as a text file'),
            onTap: _savingBackup ? null : _saveBackup,
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

// ─── Log export period picker sheet ───────────────────────────────────────

enum _Period { week, month, custom }

class _LogExportSheet extends StatefulWidget {
  final ExerciseLogRepository logRepo;
  final ExerciseRepository exerciseRepo;

  const _LogExportSheet({
    required this.logRepo,
    required this.exerciseRepo,
  });

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
    // viewPaddingOf gives the system nav bar height (unlike viewInsetsOf which
    // only covers the keyboard).
    final navBarHeight = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + navBarHeight),
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

