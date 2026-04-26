import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/app_logger.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'workout_app.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        aliases TEXT NOT NULL DEFAULT '',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE set_templates (
        id TEXT PRIMARY KEY,
        exercise_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE set_children (
        id TEXT PRIMARY KEY,
        set_template_id TEXT NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        unit TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_logs (
        id TEXT PRIMARY KEY,
        exercise_id TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_log_sets (
        id TEXT PRIMARY KEY,
        log_id TEXT NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        unit TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        workout_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_plans (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_plan_entries (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        workout_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE measurement_entries (
        id TEXT PRIMARY KEY,
        measurement_id TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed default "Weight" measurement
    final weightId = const Uuid().v4();
    await db.insert('measurements', {'id': weightId, 'name': 'Weight'});
  }

  Future<void> clearAll() async {
    log.w('[DB] clearAll: wiping all tables');
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'exercise_log_sets',
        'exercise_logs',
        'set_children',
        'set_templates',
        'exercises',
        'workout_exercises',
        'workout_plan_entries',
        'workout_plans',
        'workout_sessions',
        'workouts',
        'measurement_entries',
        'measurements',
      ]) {
        await txn.delete(table);
      }
      final weightId = const Uuid().v4();
      await txn.insert('measurements', {'id': weightId, 'name': 'Weight'});
    });
  }

  // Each version bump adds a new `if (oldVersion < N)` block here so that
  // devices upgrading from any older version receive every missing migration
  // in sequence. Never modify earlier blocks — always add a new one.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: app-level preferences (theme mode, etc.)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }
}
