import '../db/database_helper.dart';
import '../models/workout_plan.dart';
import '../models/workout_plan_entry.dart';

class WorkoutPlanRepository {
  final DatabaseHelper _db;

  WorkoutPlanRepository(this._db);

  Future<List<WorkoutPlan>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('workout_plans', orderBy: 'name ASC');
    final result = <WorkoutPlan>[];
    for (final row in rows) {
      result.add(await _hydrate(db, row));
    }
    return result;
  }

  Future<WorkoutPlan?> getById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('workout_plans', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _hydrate(db, rows.first);
  }

  Future<void> insert(WorkoutPlan plan) async {
    final db = await _db.database;
    await db.insert('workout_plans', plan.toMap());
    for (final entry in plan.entries) {
      await db.insert('workout_plan_entries', entry.toMap(planId: plan.id));
    }
  }

  Future<void> update(WorkoutPlan plan) async {
    final db = await _db.database;
    await db.update(
      'workout_plans',
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
    await db.delete(
      'workout_plan_entries',
      where: 'plan_id = ?',
      whereArgs: [plan.id],
    );
    for (final entry in plan.entries) {
      await db.insert('workout_plan_entries', entry.toMap(planId: plan.id));
    }
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      'workout_plan_entries',
      where: 'plan_id = ?',
      whereArgs: [id],
    );
    await db.delete('workout_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<WorkoutPlan> _hydrate(dynamic db, Map<String, dynamic> row) async {
    final planId = row['id'] as String;
    final entryRows = await db.query(
      'workout_plan_entries',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'day_of_week ASC',
    );
    final entries =
        entryRows.map((r) => WorkoutPlanEntry.fromMap(r)).toList();
    return WorkoutPlan.fromMap(row, entries);
  }
}
