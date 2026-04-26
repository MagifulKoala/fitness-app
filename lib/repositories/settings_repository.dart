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
}
