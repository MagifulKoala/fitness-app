import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/app_logger.dart';
import '../models/exercise.dart';
import '../models/exercise_log.dart';
import '../models/set_child.dart';
import '../models/set_template.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../models/workout_plan_entry.dart';
import '../repositories/exercise_log_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/workout_plan_repository.dart';
import '../repositories/workout_repository.dart';

class ShareService {
  static const _uuid = Uuid();
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dayFmt = DateFormat('EEE, dd MMM');

  static String _isoDate(DateTime dt) => dt.toIso8601String().substring(0, 10);

  // ─── Export workout plan ───────────────────────────────────────────────────

  static Future<void> exportWorkoutPlan(
    WorkoutPlan plan,
    WorkoutRepository workoutRepo,
    ExerciseRepository exerciseRepo,
    BuildContext context,
  ) async {
    try {
      // Batch-fetch all unique workouts, then all unique exercises upfront.
      final uniqueWorkoutIds = plan.entries.map((e) => e.workoutId).toSet().toList();
      final workoutResults = await Future.wait(
          uniqueWorkoutIds.map(workoutRepo.getById));
      final workoutById = <String, Workout>{
        for (var i = 0; i < uniqueWorkoutIds.length; i++)
          if (workoutResults[i] != null)
            uniqueWorkoutIds[i]: workoutResults[i]!,
      };

      final uniqueExerciseIds = workoutById.values
          .expand((w) => w.exerciseIds)
          .toSet()
          .toList();
      final exerciseResults = await Future.wait(
          uniqueExerciseIds.map(exerciseRepo.getById));
      final exerciseById = <String, Exercise>{
        for (var i = 0; i < uniqueExerciseIds.length; i++)
          if (exerciseResults[i] != null)
            uniqueExerciseIds[i]: exerciseResults[i]!,
      };

      final entries = <Map<String, dynamic>>[];
      for (final entry in plan.entries) {
        final workout = workoutById[entry.workoutId];
        if (workout == null) continue;

        final exercisesJson = workout.exerciseIds
            .map((id) => exerciseById[id])
            .whereType<Exercise>()
            .map((exercise) => {
                  'name': exercise.name,
                  'aliases': exercise.aliases,
                  'notes': exercise.notes,
                  'sets': exercise.setTemplate.sets
                      .map((s) => {
                            'reps': s.reps,
                            'weight': s.weight,
                            'unit': s.unit,
                          })
                      .toList(),
                })
            .toList();

        entries.add({
          'day_of_week': entry.dayOfWeek,
          'workout_name': workout.name,
          'workout_notes': workout.notes,
          'exercises': exercisesJson,
        });
      }

      final payload = {
        'schema': 1,
        'type': 'workout_plan',
        'plan': {'name': plan.name, 'entries': entries},
      };

      final dir = await getTemporaryDirectory();
      final safeName = plan.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final file = File('${dir.path}/${safeName}_plan.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      log.d('[ShareService] exportWorkoutPlan: ${plan.name}');
      await Share.shareXFiles([XFile(file.path)],
          text: '${plan.name} — workout plan');
    } catch (e, st) {
      log.e('[ShareService] exportWorkoutPlan failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export plan.')),
        );
      }
    }
  }

  // ─── Export exercise logs ──────────────────────────────────────────────────

  static Future<void> exportLogs(
    DateTime from,
    DateTime to,
    ExerciseLogRepository logRepo,
    ExerciseRepository exerciseRepo,
    BuildContext context,
  ) async {
    try {
      final logs = await logRepo.getByDateRange(from, to);

      // Fetch only the exercises that appear in these logs.
      final uniqueExerciseIds = logs.map((l) => l.exerciseId).toSet().toList();
      final exerciseResults = await Future.wait(
          uniqueExerciseIds.map(exerciseRepo.getById));
      final exerciseById = <String, Exercise>{
        for (var i = 0; i < uniqueExerciseIds.length; i++)
          if (exerciseResults[i] != null)
            uniqueExerciseIds[i]: exerciseResults[i]!,
      };

      final logsJson = logs
          .map((entry) => {
                'exercise':
                    exerciseById[entry.exerciseId]?.name ?? entry.exerciseId,
                'date': _isoDate(entry.date),
                'notes': entry.notes,
                'sets': entry.sets
                    .map((s) =>
                        {'reps': s.reps, 'weight': s.weight, 'unit': s.unit})
                    .toList(),
              })
          .toList();

      final payload = {
        'schema': 1,
        'type': 'exercise_logs',
        'from': _isoDate(from),
        'to': _isoDate(to),
        'logs': logsJson,
      };

      final text = _buildLogText(from, to, logs, exerciseById);

      final dir = await getTemporaryDirectory();
      final tag = '${_isoDate(from)}_${_isoDate(to)}';
      final jsonFile = File('${dir.path}/workout_log_$tag.json');
      final txtFile = File('${dir.path}/workout_log_$tag.txt');
      await jsonFile
          .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      await txtFile.writeAsString(text);

      log.d('[ShareService] exportLogs: $tag (${logs.length} entries)');
      await Share.shareXFiles(
        [XFile(jsonFile.path), XFile(txtFile.path)],
        text: 'Workout log $tag',
      );
    } catch (e, st) {
      log.e('[ShareService] exportLogs failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export logs.')),
        );
      }
    }
  }

  static String _buildLogText(
    DateTime from,
    DateTime to,
    List<ExerciseLog> logs,
    Map<String, Exercise> exerciseById,
  ) {
    final buf = StringBuffer();
    buf.writeln(
        'Workout Log — ${_dateFmt.format(from)} – ${_dateFmt.format(to)}');
    buf.writeln();

    final byDate = <String, List<ExerciseLog>>{};
    for (final entry in logs) {
      byDate.putIfAbsent(_isoDate(entry.date), () => []).add(entry);
    }

    for (final dateKey in byDate.keys.toList()..sort()) {
      buf.writeln(_dayFmt.format(DateTime.parse(dateKey)));
      for (final entry in byDate[dateKey]!) {
        buf.writeln('  ${exerciseById[entry.exerciseId]?.name ?? entry.exerciseId}');
        for (final s in entry.sets) {
          buf.writeln('    ${s.reps} × ${s.weight} ${s.unit}');
        }
      }
      buf.writeln();
    }

    return buf.toString();
  }

  // ─── Import workout plan ───────────────────────────────────────────────────

  /// Returns the imported plan name on success, null on cancel or error.
  static Future<String?> importWorkoutPlan(
    ExerciseRepository exerciseRepo,
    WorkoutRepository workoutRepo,
    WorkoutPlanRepository planRepo,
    BuildContext context,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) return null;

      final Map<String, dynamic> payload =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

      if (payload['type'] != 'workout_plan' || payload['schema'] != 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid workout plan file.')),
          );
        }
        return null;
      }

      final planData = payload['plan'] as Map<String, dynamic>;
      final planName = planData['name'] as String;
      final entriesData =
          (planData['entries'] as List).cast<Map<String, dynamic>>();

      // Build exercise map, deduplicating by name (case-insensitive).
      final allExisting = await exerciseRepo.getAll();
      final existingByName = {
        for (final e in allExisting) e.name.toLowerCase(): e
      };
      final exerciseIdByName = <String, String>{};

      for (final entry in entriesData) {
        for (final exJson
            in (entry['exercises'] as List).cast<Map<String, dynamic>>()) {
          final name = exJson['name'] as String;
          final nameLower = name.toLowerCase();
          if (exerciseIdByName.containsKey(nameLower)) continue;

          if (existingByName.containsKey(nameLower)) {
            exerciseIdByName[nameLower] = existingByName[nameLower]!.id;
          } else {
            final sets = (exJson['sets'] as List)
                .cast<Map<String, dynamic>>()
                .map((s) => SetChild(
                      id: _uuid.v4(),
                      reps: s['reps'] as int,
                      weight: (s['weight'] as num).toDouble(),
                      unit: s['unit'] as String,
                    ))
                .toList();
            final newExercise = Exercise(
              id: _uuid.v4(),
              name: name,
              aliases: (exJson['aliases'] as List? ?? []).cast<String>(),
              notes: exJson['notes'] as String?,
              setTemplate: SetTemplate(id: _uuid.v4(), sets: sets),
            );
            await exerciseRepo.insert(newExercise);
            exerciseIdByName[nameLower] = newExercise.id;
          }
        }
      }

      // Create workouts, deduplicating by name.
      final workoutIdByName = <String, String>{};
      for (final entry in entriesData) {
        final workoutName = entry['workout_name'] as String;
        if (workoutIdByName.containsKey(workoutName)) continue;

        final exerciseIds = (entry['exercises'] as List)
            .cast<Map<String, dynamic>>()
            .map((exJson) =>
                exerciseIdByName[(exJson['name'] as String).toLowerCase()]!)
            .toList();

        final workout = Workout(
          id: _uuid.v4(),
          name: workoutName,
          notes: entry['workout_notes'] as String?,
          exerciseIds: exerciseIds,
        );
        await workoutRepo.insert(workout);
        workoutIdByName[workoutName] = workout.id;
      }

      final planEntries = entriesData
          .map((entry) => WorkoutPlanEntry(
                id: _uuid.v4(),
                workoutId: workoutIdByName[entry['workout_name'] as String]!,
                dayOfWeek: entry['day_of_week'] as int,
              ))
          .toList();

      final plan = WorkoutPlan(
        id: _uuid.v4(),
        name: planName,
        entries: planEntries,
      );
      await planRepo.insert(plan);

      log.d('[ShareService] importWorkoutPlan: $planName (${planEntries.length} entries)');
      return planName;
    } catch (e, st) {
      log.e('[ShareService] importWorkoutPlan failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import plan.')),
        );
      }
      return null;
    }
  }
}
