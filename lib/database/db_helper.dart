import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/body_measurement.dart';
import '../models/body_weight_entry.dart';
import '../models/exercise.dart';
import '../models/nutrition_log.dart';
import '../models/routine.dart';
import '../models/workout_session.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._();
  static Database? _db;

  DbHelper._();
  factory DbHelper() => _instance;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'workout.db');
    return openDatabase(path, version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedFromAsset(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE exercises ADD COLUMN level TEXT NOT NULL DEFAULT ""');
      await db.execute('ALTER TABLE exercises ADD COLUMN instructions TEXT NOT NULL DEFAULT ""');
      await db.delete('exercises', where: 'isCustom = 0');
      await _seedFromAsset(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sessionExercises ADD COLUMN notes TEXT NOT NULL DEFAULT ""');
      await db.execute('ALTER TABLE sessionExercises ADD COLUMN superset_with_next INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS body_weight_logs(
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          weight_kg REAL NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE sessionExercises ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 90');
      await db.execute('ALTER TABLE setLogs ADD COLUMN rpe INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE setLogs ADD COLUMN is_dropset INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE setLogs ADD COLUMN to_failure INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS body_measurements(
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          chest REAL,
          waist REAL,
          hips REAL,
          bicep_l REAL,
          bicep_r REAL,
          thigh_l REAL,
          thigh_r REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS nutrition_logs(
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          calories INTEGER,
          protein_g REAL,
          note TEXT NOT NULL DEFAULT ""
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE exercises ADD COLUMN gifUrl TEXT');
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE exercises(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        equipment TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT "",
        instructions TEXT NOT NULL DEFAULT "",
        isCustom INTEGER NOT NULL DEFAULT 0,
        gifUrl TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE routines(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routineExercises(
        id TEXT PRIMARY KEY,
        routineId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        exerciseName TEXT NOT NULL,
        targetSets INTEGER NOT NULL,
        targetReps INTEGER NOT NULL,
        targetWeight REAL,
        orderIndex INTEGER NOT NULL,
        FOREIGN KEY(routineId) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE workoutSessions(
        id TEXT PRIMARY KEY,
        routineId TEXT,
        name TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sessionExercises(
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        exerciseName TEXT NOT NULL,
        orderIndex INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT "",
        superset_with_next INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        FOREIGN KEY(sessionId) REFERENCES workoutSessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE setLogs(
        id TEXT PRIMARY KEY,
        sessionExerciseId TEXT NOT NULL,
        setNumber INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        rpe INTEGER NOT NULL DEFAULT 0,
        is_dropset INTEGER NOT NULL DEFAULT 0,
        to_failure INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(sessionExerciseId) REFERENCES sessionExercises(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE body_weight_logs(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        weight_kg REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE body_measurements(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        chest REAL,
        waist REAL,
        hips REAL,
        bicep_l REAL,
        bicep_r REAL,
        thigh_l REAL,
        thigh_r REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE nutrition_logs(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        calories INTEGER,
        protein_g REAL,
        note TEXT NOT NULL DEFAULT ""
      )
    ''');
  }

  Future<void> _seedFromAsset(Database db) async {
    final raw = await rootBundle.loadString('assets/exercises.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final batch = db.batch();
    for (final j in list) {
      final e = Exercise.fromJson(j);
      batch.insert('exercises', e.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  // ── Exercises ──────────────────────────────────────────────────────────────

  Future<List<Exercise>> getExercises() async {
    final d = await db;
    final rows = await d.query('exercises', orderBy: 'muscleGroup, name');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<void> insertExercise(Exercise e) async {
    final d = await db;
    await d.insert('exercises', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExercise(String id) async {
    final d = await db;
    await d.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ── Routines ───────────────────────────────────────────────────────────────

  Future<List<Routine>> getRoutines() async {
    final d = await db;
    final rows = await d.query('routines', orderBy: 'createdAt DESC');
    final routines = rows.map(Routine.fromMap).toList();
    for (final r in routines) {
      r.exercises = await getRoutineExercises(r.id);
    }
    return routines;
  }

  Future<void> insertRoutine(Routine r) async {
    final d = await db;
    await d.insert('routines', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await d.delete('routineExercises', where: 'routineId = ?', whereArgs: [r.id]);
    for (final e in r.exercises) {
      await d.insert('routineExercises', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> deleteRoutine(String id) async {
    final d = await db;
    await d.delete('routineExercises', where: 'routineId = ?', whereArgs: [id]);
    await d.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RoutineExercise>> getRoutineExercises(String routineId) async {
    final d = await db;
    final rows = await d.query('routineExercises',
        where: 'routineId = ?', whereArgs: [routineId], orderBy: 'orderIndex');
    return rows.map(RoutineExercise.fromMap).toList();
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<List<WorkoutSession>> getSessions() async {
    final d = await db;
    final rows = await d.query('workoutSessions', orderBy: 'startTime DESC');
    final sessions = rows.map(WorkoutSession.fromMap).toList();
    for (final s in sessions) {
      s.exercises = await _getSessionExercises(s.id);
    }
    return sessions;
  }

  Future<void> insertSession(WorkoutSession s) async {
    final d = await db;
    await d.insert('workoutSessions', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    for (final e in s.exercises) {
      await d.insert('sessionExercises', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final set in e.sets) {
        await d.insert('setLogs', set.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> deleteSession(String id) async {
    final d = await db;
    final exercises = await d.query('sessionExercises', where: 'sessionId = ?', whereArgs: [id]);
    for (final e in exercises) {
      await d.delete('setLogs', where: 'sessionExerciseId = ?', whereArgs: [e['id']]);
    }
    await d.delete('sessionExercises', where: 'sessionId = ?', whereArgs: [id]);
    await d.delete('workoutSessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SessionExercise>> _getSessionExercises(String sessionId) async {
    final d = await db;
    final rows = await d.query('sessionExercises',
        where: 'sessionId = ?', whereArgs: [sessionId], orderBy: 'orderIndex');
    final exercises = rows.map(SessionExercise.fromMap).toList();
    for (final e in exercises) {
      e.sets = await _getSets(e.id);
    }
    return exercises;
  }

  Future<List<SetLog>> _getSets(String sessionExerciseId) async {
    final d = await db;
    final rows = await d.query('setLogs',
        where: 'sessionExerciseId = ?', whereArgs: [sessionExerciseId], orderBy: 'setNumber');
    return rows.map(SetLog.fromMap).toList();
  }

  // ── Body Weight ────────────────────────────────────────────────────────────

  Future<List<BodyWeightEntry>> getBodyWeights() async {
    final d = await db;
    final rows = await d.query('body_weight_logs', orderBy: 'date ASC');
    return rows.map(BodyWeightEntry.fromMap).toList();
  }

  Future<void> insertBodyWeight(BodyWeightEntry entry) async {
    final d = await db;
    await d.insert('body_weight_logs', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBodyWeight(String id) async {
    final d = await db;
    await d.delete('body_weight_logs', where: 'id = ?', whereArgs: [id]);
  }

  // ── Body Measurements ──────────────────────────────────────────────────────

  Future<List<BodyMeasurement>> getBodyMeasurements() async {
    final d = await db;
    final rows = await d.query('body_measurements', orderBy: 'date DESC');
    return rows.map(BodyMeasurement.fromMap).toList();
  }

  Future<void> insertBodyMeasurement(BodyMeasurement m) async {
    final d = await db;
    await d.insert('body_measurements', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBodyMeasurement(String id) async {
    final d = await db;
    await d.delete('body_measurements', where: 'id = ?', whereArgs: [id]);
  }

  // ── Nutrition Logs ─────────────────────────────────────────────────────────

  Future<List<NutritionLog>> getNutritionLogs() async {
    final d = await db;
    final rows = await d.query('nutrition_logs', orderBy: 'date DESC');
    return rows.map(NutritionLog.fromMap).toList();
  }

  Future<void> insertNutritionLog(NutritionLog log) async {
    final d = await db;
    await d.insert('nutrition_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteNutritionLog(String id) async {
    final d = await db;
    await d.delete('nutrition_logs', where: 'id = ?', whereArgs: [id]);
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProgressForExercise(String exerciseId) async {
    final d = await db;
    return d.rawQuery('''
      SELECT ws.startTime, MAX(sl.weight) as maxWeight, MAX(sl.reps) as maxReps
      FROM workoutSessions ws
      JOIN sessionExercises se ON se.sessionId = ws.id
      JOIN setLogs sl ON sl.sessionExerciseId = se.id
      WHERE se.exerciseId = ? AND sl.isCompleted = 1
      GROUP BY date(ws.startTime)
      ORDER BY ws.startTime ASC
    ''', [exerciseId]);
  }

  // ── Export / Backup ────────────────────────────────────────────────────────

  Future<String> exportCsv() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT ws.startTime, ws.name as sessionName,
             se.exerciseName, sl.setNumber, sl.reps, sl.weight, sl.isCompleted
      FROM workoutSessions ws
      JOIN sessionExercises se ON se.sessionId = ws.id
      JOIN setLogs sl ON sl.sessionExerciseId = se.id
      WHERE sl.isCompleted = 1
      ORDER BY ws.startTime DESC, se.orderIndex, sl.setNumber
    ''');

    final buf = StringBuffer('Date,Session,Exercise,Set,Reps,Weight(kg)\n');
    for (final r in rows) {
      final date = (r['startTime'] as String).substring(0, 10);
      buf.write('$date,${r['sessionName']},${r['exerciseName']},${r['setNumber']},${r['reps']},${r['weight']}\n');
    }
    return buf.toString();
  }

  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), 'workout.db');
  }

  Future<void> restoreFromFile(String sourcePath) async {
    _db = null;
    final dest = join(await getDatabasesPath(), 'workout.db');
    await File(sourcePath).copy(dest);
  }

  Future<String> backupToDocuments() async {
    final src = join(await getDatabasesPath(), 'workout.db');
    final dir = await getApplicationDocumentsDirectory();
    final dest = join(dir.path, 'motagym_backup.db');
    await File(src).copy(dest);
    return dest;
  }
}
