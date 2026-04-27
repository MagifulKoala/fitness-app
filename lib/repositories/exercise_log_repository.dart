import 'package:sqflite/sqflite.dart';
import '../core/app_logger.dart';
import '../db/database_helper.dart';
import '../models/exercise_log.dart';
import '../models/set_child.dart';

class ExerciseLogRepository {
  final DatabaseHelper _db;

  ExerciseLogRepository(this._db);

  Future<void> insert(ExerciseLog exerciseLog) async {
    log.d('[ExerciseLogRepo] insert: exerciseId=${exerciseLog.exerciseId} sets=${exerciseLog.sets.length}');
    final db = await _db.database;
    await db.insert('exercise_logs', exerciseLog.toMap());
    for (final set in exerciseLog.sets) {
      await db.insert('exercise_log_sets', set.toMap(logId: exerciseLog.id));
    }
    log.d('[ExerciseLogRepo] insert complete: id=${exerciseLog.id}');
  }

  Future<List<ExerciseLog>> getByExerciseId(String exerciseId) async {
    final db = await _db.database;
    final rows = await db.query(
      'exercise_logs',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'date DESC',
    );
    return _hydrateLogs(db, rows);
  }

  Future<List<ExerciseLog>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('exercise_logs', orderBy: 'date ASC');
    return _hydrateLogs(db, rows);
  }

  Future<List<ExerciseLog>> getByDateRange(DateTime from, DateTime to) async {
    final db = await _db.database;
    final toNext = to.add(const Duration(days: 1));
    final rows = await db.query(
      'exercise_logs',
      where: 'date >= ? AND date < ?',
      whereArgs: [from.toIso8601String(), toNext.toIso8601String()],
      orderBy: 'date ASC',
    );
    return _hydrateLogs(db, rows);
  }

  // Batch-fetches all sets for the given log rows in a single query,
  // eliminating the N+1 pattern of one query per log.
  Future<List<ExerciseLog>> _hydrateLogs(
      Database db, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final logIds = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(logIds.length, '?').join(',');
    final setRows = await db.rawQuery(
      'SELECT * FROM exercise_log_sets WHERE log_id IN ($placeholders)',
      logIds,
    );
    final setsByLogId = <String, List<SetChild>>{};
    for (final row in setRows) {
      final logId = row['log_id'] as String;
      setsByLogId.putIfAbsent(logId, () => []).add(SetChild.fromMap(row));
    }
    return rows
        .map((row) => ExerciseLog.fromMap(
              row,
              setsByLogId[row['id'] as String] ?? [],
            ))
        .toList();
  }

  Future<void> update(ExerciseLog exerciseLog) async {
    log.d('[ExerciseLogRepo] update: id=${exerciseLog.id}');
    final db = await _db.database;
    await db.update(
      'exercise_logs',
      exerciseLog.toMap(),
      where: 'id = ?',
      whereArgs: [exerciseLog.id],
    );
    await db.delete('exercise_log_sets', where: 'log_id = ?', whereArgs: [exerciseLog.id]);
    for (final set in exerciseLog.sets) {
      await db.insert('exercise_log_sets', set.toMap(logId: exerciseLog.id));
    }
  }

  Future<void> delete(String logId) async {
    log.d('[ExerciseLogRepo] delete: $logId');
    final db = await _db.database;
    await db.delete(
      'exercise_log_sets',
      where: 'log_id = ?',
      whereArgs: [logId],
    );
    await db.delete(
      'exercise_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
  }
}
