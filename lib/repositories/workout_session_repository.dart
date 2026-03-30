import '../db/database_helper.dart';
import '../models/workout_session.dart';

class WorkoutSessionRepository {
  final DatabaseHelper _db;

  WorkoutSessionRepository(this._db);

  Future<List<WorkoutSession>> getAll() async {
    final db = await _db.database;
    final rows =
        await db.query('workout_sessions', orderBy: 'date DESC');
    return rows.map(WorkoutSession.fromMap).toList();
  }

  Future<List<WorkoutSession>> getByWorkoutId(String workoutId) async {
    final db = await _db.database;
    final rows = await db.query(
      'workout_sessions',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'date DESC',
    );
    return rows.map(WorkoutSession.fromMap).toList();
  }

  Future<void> insert(WorkoutSession session) async {
    final db = await _db.database;
    await db.insert('workout_sessions', session.toMap());
  }

  Future<void> update(WorkoutSession session) async {
    final db = await _db.database;
    await db.update(
      'workout_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
  }
}
