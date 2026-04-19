import '../core/app_logger.dart';
import '../db/database_helper.dart';
import '../models/measurement.dart';
import '../models/measurement_entry.dart';

class MeasurementRepository {
  final DatabaseHelper _db;

  MeasurementRepository(this._db);

  // --- Measurements ---

  Future<List<Measurement>> getAllMeasurements() async {
    final db = await _db.database;
    final rows = await db.query('measurements', orderBy: 'name ASC');
    return rows.map(Measurement.fromMap).toList();
  }

  Future<void> insertMeasurement(Measurement m) async {
    log.d('[MeasurementRepo] insert: ${m.name}');
    final db = await _db.database;
    await db.insert('measurements', m.toMap());
  }

  Future<void> updateMeasurement(Measurement m) async {
    log.d('[MeasurementRepo] update: ${m.name}');
    final db = await _db.database;
    await db.update(
      'measurements',
      m.toMap(),
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteMeasurement(String id) async {
    log.d('[MeasurementRepo] deleteMeasurement: $id');
    final db = await _db.database;
    await db.delete(
      'measurement_entries',
      where: 'measurement_id = ?',
      whereArgs: [id],
    );
    await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  // --- Entries ---

  Future<List<MeasurementEntry>> getEntries(String measurementId) async {
    final db = await _db.database;
    final rows = await db.query(
      'measurement_entries',
      where: 'measurement_id = ?',
      whereArgs: [measurementId],
      orderBy: 'date ASC',
    );
    return rows.map(MeasurementEntry.fromMap).toList();
  }

  Future<void> insertEntry(MeasurementEntry entry) async {
    log.d('[MeasurementRepo] insertEntry: ${entry.value} ${entry.unit}');
    final db = await _db.database;
    await db.insert('measurement_entries', entry.toMap());
  }

  Future<void> updateEntry(MeasurementEntry entry) async {
    log.d('[MeasurementRepo] updateEntry: ${entry.value} ${entry.unit}');
    final db = await _db.database;
    await db.update(
      'measurement_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(String id) async {
    log.d('[MeasurementRepo] deleteEntry: $id');
    final db = await _db.database;
    await db.delete(
      'measurement_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
