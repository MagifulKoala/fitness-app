import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/app_logger.dart';
import '../db/database_helper.dart';
import '../models/exercise.dart';
import '../models/exercise_link.dart';
import '../models/set_child.dart';
import '../models/set_template.dart';

class ExerciseRepository {
  final DatabaseHelper _db;
  final _uuid = const Uuid();

  ExerciseRepository(this._db);

  Future<List<Exercise>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('exercises', orderBy: 'name ASC');
    final result = <Exercise>[];
    for (final row in rows) {
      result.add(await _hydrate(db, row));
    }
    return result;
  }

  Future<Exercise?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _hydrate(db, rows.first);
  }

  Future<List<Exercise>> search(String query) async {
    final db = await _db.database;
    final pattern = '%$query%';
    final rows = await db.query(
      'exercises',
      where: 'name LIKE ? OR aliases LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'name ASC',
    );
    final result = <Exercise>[];
    for (final row in rows) {
      result.add(await _hydrate(db, row));
    }
    return result;
  }

  Future<Exercise> insert(Exercise exercise) async {
    log.d('[ExerciseRepo] insert: ${exercise.name}');
    final db = await _db.database;
    await db.insert('exercises', exercise.toMap());

    final templateId = _uuid.v4();
    await db.insert('set_templates', {
      'id': templateId,
      'exercise_id': exercise.id,
    });

    for (final set in exercise.setTemplate.sets) {
      await db.insert('set_children', set.toMap(setTemplateId: templateId));
    }

    for (var i = 0; i < exercise.links.length; i++) {
      await db.insert('exercise_links',
          exercise.links[i].toMap(exerciseId: exercise.id, sortOrder: i));
    }

    return exercise;
  }

  Future<void> update(Exercise exercise) async {
    log.d('[ExerciseRepo] update: ${exercise.name}');
    final db = await _db.database;
    await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );

    // Update set template children
    final templates = await db.query(
      'set_templates',
      where: 'exercise_id = ?',
      whereArgs: [exercise.id],
    );
    if (templates.isNotEmpty) {
      final templateId = templates.first['id'] as String;
      await db.delete(
        'set_children',
        where: 'set_template_id = ?',
        whereArgs: [templateId],
      );
      for (final set in exercise.setTemplate.sets) {
        await db.insert('set_children', set.toMap(setTemplateId: templateId));
      }
    }

    await db.delete('exercise_links',
        where: 'exercise_id = ?', whereArgs: [exercise.id]);
    for (var i = 0; i < exercise.links.length; i++) {
      await db.insert('exercise_links',
          exercise.links[i].toMap(exerciseId: exercise.id, sortOrder: i));
    }
  }

  /// Deletes the exercise together with everything that references it: its
  /// logs (and their sets) and its slots in workouts. Runs in one transaction
  /// so a failure cannot leave orphaned rows behind.
  Future<void> delete(String id) async {
    log.d('[ExerciseRepo] delete: $id');
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'exercise_log_sets',
        where: 'log_id IN (SELECT id FROM exercise_logs WHERE exercise_id = ?)',
        whereArgs: [id],
      );
      await txn.delete('exercise_logs', where: 'exercise_id = ?', whereArgs: [id]);
      await txn.delete('workout_exercises',
          where: 'exercise_id = ?', whereArgs: [id]);
      await txn.delete('exercise_links', where: 'exercise_id = ?', whereArgs: [id]);
      await txn.delete(
        'set_children',
        where: 'set_template_id IN '
            '(SELECT id FROM set_templates WHERE exercise_id = ?)',
        whereArgs: [id],
      );
      await txn.delete('set_templates', where: 'exercise_id = ?', whereArgs: [id]);
      await txn.delete('exercises', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Exercise> _hydrate(Database db, Map<String, dynamic> row) async {
    final exerciseId = row['id'] as String;
    final templates = await db.query(
      'set_templates',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );

    SetTemplate setTemplate;
    if (templates.isEmpty) {
      setTemplate = SetTemplate(id: _uuid.v4(), sets: []);
    } else {
      final templateId = templates.first['id'] as String;
      final setRows = await db.query(
        'set_children',
        where: 'set_template_id = ?',
        whereArgs: [templateId],
      );
      final sets = setRows.map<SetChild>((r) => SetChild.fromMap(r)).toList();
      setTemplate = SetTemplate.fromMap(templates.first, sets);
    }

    final linkRows = await db.query(
      'exercise_links',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'sort_order ASC',
    );
    final links = linkRows.map(ExerciseLink.fromMap).toList();

    return Exercise.fromMap(row, setTemplate, links);
  }
}
