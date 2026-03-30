import '../db/database_helper.dart';
import '../models/exercise_log.dart';
import '../models/set_child.dart';

class ExerciseLogRepository {
  final DatabaseHelper _db;

  ExerciseLogRepository(this._db);

  Future<void> insert(ExerciseLog log) async {
    final db = await _db.database;
    await db.insert('exercise_logs', log.toMap());
    for (final set in log.sets) {
      await db.insert('exercise_log_sets', set.toMap(logId: log.id));
    }
  }

  Future<List<ExerciseLog>> getByExerciseId(String exerciseId) async {
    final db = await _db.database;
    final rows = await db.query(
      'exercise_logs',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'date DESC',
    );
    final result = <ExerciseLog>[];
    for (final row in rows) {
      final logId = row['id'] as String;
      final setRows = await db.query(
        'exercise_log_sets',
        where: 'log_id = ?',
        whereArgs: [logId],
      );
      final sets = setRows.map((r) => SetChild.fromMap(r)).toList();
      result.add(ExerciseLog.fromMap(row, sets));
    }
    return result;
  }

  Future<void> delete(String logId) async {
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
