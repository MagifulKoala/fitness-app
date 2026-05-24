import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../core/app_logger.dart';

/// Persists app-level preferences in the [app_settings] key-value table.
///
/// Intentionally excluded from [clearAll] so user preferences survive a
/// data wipe. Add new preference keys as additional static constants.
class SettingsRepository {
  static const _keyThemeMode = 'theme_mode';
  static const _keyBackupFolderPath = 'backup_folder_path';
  static const _keyBackupLastTimestamp = 'backup_last_timestamp';
  final DatabaseHelper _db;

  SettingsRepository(this._db);

  /// Returns the saved [ThemeMode], defaulting to [ThemeMode.light] on first
  /// launch or if the read fails (e.g. during a schema migration on upgrade).
  Future<ThemeMode> getThemeMode() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_keyThemeMode],
      );
      if (rows.isEmpty) return ThemeMode.light;
      return rows.first['value'] == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (e, st) {
      log.e('[Settings] getThemeMode error, defaulting to light', error: e, stackTrace: st);
      return ThemeMode.light;
    }
  }

  /// Persists [mode]. Uses REPLACE conflict algorithm so the row is upserted.
  Future<void> setThemeMode(ThemeMode mode) async {
    final db = await _db.database;
    final value = mode == ThemeMode.dark ? 'dark' : 'light';
    await db.insert(
      'app_settings',
      {'key': _keyThemeMode, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    log.d('[Settings] themeMode set to $value');
  }

  Future<String?> getBackupFolderPath() async {
    try {
      final db = await _db.database;
      final rows = await db.query('app_settings',
          where: 'key = ?', whereArgs: [_keyBackupFolderPath]);
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e, st) {
      log.e('[Settings] getBackupFolderPath error', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> setBackupFolderPath(String? path) async {
    final db = await _db.database;
    if (path == null) {
      await db.delete('app_settings',
          where: 'key = ?', whereArgs: [_keyBackupFolderPath]);
    } else {
      await db.insert('app_settings', {'key': _keyBackupFolderPath, 'value': path},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    log.d('[Settings] backupFolderPath set to $path');
  }

  Future<DateTime?> getBackupLastTimestamp() async {
    try {
      final db = await _db.database;
      final rows = await db.query('app_settings',
          where: 'key = ?', whereArgs: [_keyBackupLastTimestamp]);
      if (rows.isEmpty) return null;
      final value = rows.first['value'] as String?;
      if (value == null) return null;
      return DateTime.tryParse(value);
    } catch (e, st) {
      log.e('[Settings] getBackupLastTimestamp error', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> setBackupLastTimestamp(DateTime dt) async {
    final db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': _keyBackupLastTimestamp, 'value': dt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    log.d('[Settings] backupLastTimestamp set to ${dt.toIso8601String()}');
  }
}
