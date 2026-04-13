import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/exercise.dart';
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

    return exercise;
  }

  Future<void> update(Exercise exercise) async {
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
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    final templates = await db.query(
      'set_templates',
      where: 'exercise_id = ?',
      whereArgs: [id],
    );
    for (final t in templates) {
      await db.delete(
        'set_children',
        where: 'set_template_id = ?',
        whereArgs: [t['id']],
      );
    }
    await db.delete('set_templates', where: 'exercise_id = ?', whereArgs: [id]);
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<Exercise> _hydrate(dynamic db, Map<String, dynamic> row) async {
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

    return Exercise.fromMap(row, setTemplate);
  }
}
