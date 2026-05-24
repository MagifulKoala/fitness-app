import 'package:flutter/material.dart';
import '../../repositories/settings_repository.dart';
import 'data_screen.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsRepository settingsRepo;
  final VoidCallback onDataCleared;
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.settingsRepo,
    required this.onDataCleared,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Display',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (on) =>
                onThemeModeChanged(on ? ThemeMode.dark : ThemeMode.light),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Data',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Manage data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DataScreen(
              settingsRepo: settingsRepo,
              onDataCleared: onDataCleared,
            ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
