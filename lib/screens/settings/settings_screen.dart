import 'package:flutter/material.dart';
import 'data_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onDataCleared;

  const SettingsScreen({super.key, required this.onDataCleared});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DataScreen(onDataCleared: onDataCleared),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
