import '../core/app_logger.dart';
import '../db/database_helper.dart';
import '../models/workout.dart';

class WorkoutRepository {
  final DatabaseHelper _db;

  WorkoutRepository(this._db);

  Future<List<Workout>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('workouts', orderBy: 'name ASC');
    final result = <Workout>[];
    for (final row in rows) {
      result.add(await _hydrate(db, row));
    }
    return result;
  }

  Future<Workout?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('workouts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _hydrate(db, rows.first);
  }

  Future<void> insert(Workout workout) async {
    log.d('[WorkoutRepo] insert: ${workout.name}');
    final db = await _db.database;
    await db.insert('workouts', workout.toMap());
    for (var i = 0; i < workout.exerciseIds.length; i++) {
      await db.insert('workout_exercises', {
        'workout_id': workout.id,
        'exercise_id': workout.exerciseIds[i],
        'sort_order': i,
      });
    }
  }

  Future<void> update(Workout workout) async {
    log.d('[WorkoutRepo] update: ${workout.name}');
    final db = await _db.database;
    await db.update(
      'workouts',
      workout.toMap(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
    await db.delete(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [workout.id],
    );
    for (var i = 0; i < workout.exerciseIds.length; i++) {
      await db.insert('workout_exercises', {
        'workout_id': workout.id,
        'exercise_id': workout.exerciseIds[i],
        'sort_order': i,
      });
    }
  }

  Future<void> delete(String id) async {
    log.d('[WorkoutRepo] delete: $id');
    final db = await _db.database;
    await db.delete(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [id],
    );
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Workout> _hydrate(dynamic db, Map<String, dynamic> row) async {
    final workoutId = row['id'] as String;
    final exRows = await db.query(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'sort_order ASC',
    );
    final exerciseIds =
        exRows.map<String>((r) => r['exercise_id'] as String).toList();
    return Workout.fromMap(row, exerciseIds);
  }
}
