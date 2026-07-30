import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/body_measurement.dart';
import '../models/body_weight_entry.dart';
import '../models/exercise.dart';
import '../models/nutrition_log.dart';
import '../models/routine.dart';
import '../models/training_program.dart';
import '../models/workout_session.dart';

// ── Badge model ────────────────────────────────────────────────────────────

class AppBadge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool Function(WorkoutProvider) check;

  const AppBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.check,
  });
}

// ── Template definitions ───────────────────────────────────────────────────

const _templates = {
  'Push Day': ['Bench Press', 'Overhead Press', 'Incline Dumbbell Press', 'Triceps Pushdown', 'Lateral Raise'],
  'Pull Day': ['Pull-Up', 'Bent Over Barbell Row', 'Seated Cable Row', 'Barbell Curl', 'Face Pull'],
  'Legs Day': ['Barbell Squat', 'Romanian Deadlift', 'Leg Press', 'Leg Curl', 'Standing Calf Raise'],
  'Upper Body': ['Bench Press', 'Pull-Up', 'Overhead Press', 'Bent Over Barbell Row', 'Dumbbell Curl'],
  'Lower Body': ['Barbell Squat', 'Romanian Deadlift', 'Leg Press', 'Leg Extension', 'Standing Calf Raise'],
  'Full Body': ['Barbell Squat', 'Bench Press', 'Deadlift', 'Pull-Up', 'Overhead Press'],
};

// ── Strength standards (kg, approximate for 75–80 kg male) ────────────────

const strengthStandards = <String, Map<String, double>>{
  'Bench Press': {'Beginner': 60, 'Intermediate': 100, 'Advanced': 140},
  'Barbell Squat': {'Beginner': 80, 'Intermediate': 120, 'Advanced': 180},
  'Deadlift': {'Beginner': 100, 'Intermediate': 150, 'Advanced': 220},
  'Overhead Press': {'Beginner': 40, 'Intermediate': 65, 'Advanced': 100},
  'Bent Over Barbell Row': {'Beginner': 50, 'Intermediate': 80, 'Advanced': 120},
};

class WorkoutProvider extends ChangeNotifier {
  final _db = DbHelper();
  final _uuid = const Uuid();

  List<Exercise> exercises = [];
  List<Routine> routines = [];
  List<WorkoutSession> sessions = [];
  List<BodyWeightEntry> bodyWeights = [];
  List<BodyMeasurement> bodyMeasurements = [];
  List<NutritionLog> nutritionLogs = [];

  WorkoutSession? activeSession;
  Map<String, double> lastSessionPRs = {};
  ActiveProgram? activeProgram;

  static const allBadges = <AppBadge>[
    AppBadge(id: 'first_workout', title: 'First Step', emoji: '👟', description: 'Complete your first workout', check: _b_firstWorkout),
    AppBadge(id: 'workouts_7', title: 'Week Warrior', emoji: '🗓️', description: 'Complete 7 workouts', check: _b_7workouts),
    AppBadge(id: 'workouts_30', title: 'Monthly Grind', emoji: '📅', description: 'Complete 30 workouts', check: _b_30workouts),
    AppBadge(id: 'workouts_100', title: 'Century Club', emoji: '💯', description: 'Complete 100 workouts', check: _b_100workouts),
    AppBadge(id: 'streak_7', title: 'Hot Streak', emoji: '🔥', description: '7-day workout streak', check: _b_streak7),
    AppBadge(id: 'streak_14', title: 'On Fire', emoji: '🚀', description: '14-day workout streak', check: _b_streak14),
    AppBadge(id: 'volume_10k', title: 'Heavy Lifter', emoji: '🏋️', description: 'Lift 10,000 kg total', check: _b_volume10k),
    AppBadge(id: 'volume_100k', title: 'Iron Mill', emoji: '⚙️', description: 'Lift 100,000 kg total', check: _b_volume100k),
    AppBadge(id: 'first_pr', title: 'New Heights', emoji: '📈', description: 'Set your first personal record', check: _b_firstPR),
    AppBadge(id: 'exercises_10', title: 'Variety Pack', emoji: '🎯', description: 'Log 10 different exercises', check: _b_exercises10),
    AppBadge(id: 'early_bird', title: 'Early Bird', emoji: '🌅', description: 'Complete a workout before 8 AM', check: _b_earlyBird),
    AppBadge(id: 'night_owl', title: 'Night Owl', emoji: '🦉', description: 'Complete a workout after 9 PM', check: _b_nightOwl),
  ];

  static bool _b_firstWorkout(WorkoutProvider p) => p.completedSessions.isNotEmpty;
  static bool _b_7workouts(WorkoutProvider p) => p.completedSessions.length >= 7;
  static bool _b_30workouts(WorkoutProvider p) => p.completedSessions.length >= 30;
  static bool _b_100workouts(WorkoutProvider p) => p.completedSessions.length >= 100;
  static bool _b_streak7(WorkoutProvider p) => p.currentStreak >= 7;
  static bool _b_streak14(WorkoutProvider p) => p.currentStreak >= 14;
  static bool _b_volume10k(WorkoutProvider p) => p.allTimeVolume >= 10000;
  static bool _b_volume100k(WorkoutProvider p) => p.allTimeVolume >= 100000;
  static bool _b_firstPR(WorkoutProvider p) => p.lastSessionPRs.isNotEmpty;
  static bool _b_exercises10(WorkoutProvider p) {
    final ids = p.completedSessions.expand((s) => s.exercises.map((e) => e.exerciseId)).toSet();
    return ids.length >= 10;
  }
  static bool _b_earlyBird(WorkoutProvider p) =>
      p.completedSessions.any((s) => s.endTime != null && s.startTime.hour < 8);
  static bool _b_nightOwl(WorkoutProvider p) =>
      p.completedSessions.any((s) => s.endTime != null && s.startTime.hour >= 21);

  List<AppBadge> get earnedBadges => allBadges.where((b) => b.check(this)).toList();

  Future<void> loadAll() async {
    try {
      exercises = await _db.getExercises();
    } catch (_) {}
    try {
      routines = await _db.getRoutines();
      sessions = await _db.getSessions();
      bodyWeights = await _db.getBodyWeights();
      bodyMeasurements = await _db.getBodyMeasurements();
      nutritionLogs = await _db.getNutritionLogs();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      activeProgram = ActiveProgram.tryFromJsonString(prefs.getString('active_program'));
    } catch (_) {}
    notifyListeners();
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  List<WorkoutSession> get completedSessions => sessions.where((s) => s.endTime != null).toList();

  int get currentStreak {
    if (sessions.isEmpty) return 0;
    final days = completedSessions
        .map((s) => DateTime(s.startTime.year, s.startTime.month, s.startTime.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    if (days.first.difference(todayD).inDays.abs() > 1) return 0;
    int streak = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i - 1].difference(days[i]).inDays == 1) streak++;
      else break;
    }
    return streak;
  }

  int get thisWeekVolume {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return completedSessions
        .where((s) => s.startTime.isAfter(start))
        .fold(0, (sum, s) => sum + s.totalVolume);
  }

  int get lastWeekVolume {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final lastStart = thisStart.subtract(const Duration(days: 7));
    return completedSessions
        .where((s) => s.startTime.isAfter(lastStart) && s.startTime.isBefore(thisStart))
        .fold(0, (sum, s) => sum + s.totalVolume);
  }

  int get thisWeekCount {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return completedSessions.where((s) => s.startTime.isAfter(start)).length;
  }

  int get allTimeVolume => completedSessions.fold(0, (sum, s) => sum + s.totalVolume);

  Map<String, int> get weeklyMuscleHits {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final result = <String, int>{};
    for (final s in completedSessions.where((s) => s.startTime.isAfter(start))) {
      for (final se in s.exercises) {
        final ex = exercises.firstWhere((e) => e.id == se.exerciseId,
            orElse: () => Exercise(id: '', name: '', muscleGroup: 'Other', equipment: ''));
        result[ex.muscleGroup] = (result[ex.muscleGroup] ?? 0) + 1;
      }
    }
    return result;
  }

  Set<DateTime> get workoutDays => completedSessions
      .map((s) => DateTime(s.startTime.year, s.startTime.month, s.startTime.day))
      .toSet();

  List<Map<String, dynamic>> weeklyVolumeHistory({int weeks = 8}) {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = weeks - 1; i >= 0; i--) {
      final weekEnd = today.subtract(Duration(days: 7 * i));
      final weekStart = weekEnd.subtract(const Duration(days: 7));
      final vol = completedSessions
          .where((s) =>
              s.startTime.isAfter(weekStart) &&
              !s.startTime.isAfter(weekEnd.add(const Duration(days: 1))))
          .fold(0, (sum, s) => sum + s.totalVolume);
      result.add({'weekStart': weekStart, 'volume': vol, 'weekEnd': weekEnd});
    }
    return result;
  }

  Map<String, Map<String, dynamic>> get allTimePRs {
    final prs = <String, Map<String, dynamic>>{};
    for (final s in completedSessions) {
      for (final se in s.exercises) {
        for (final set in se.sets.where((st) => st.isCompleted)) {
          final e1rm = epley1RM(set.weight, set.reps);
          final existing = prs[se.exerciseId];
          if (existing == null || e1rm > (existing['e1rm'] as double)) {
            prs[se.exerciseId] = {
              'name': se.exerciseName,
              'weight': set.weight,
              'reps': set.reps,
              'date': s.startTime,
              'e1rm': e1rm,
            };
          }
        }
      }
    }
    return prs;
  }

  Routine? get suggestedRoutine {
    if (routines.isEmpty) return null;
    if (completedSessions.isEmpty) return routines.first;
    final recent = DateTime.now().subtract(const Duration(days: 2));
    final recentMuscles = completedSessions
        .where((s) => s.startTime.isAfter(recent))
        .expand((s) => s.exercises.map((e) => e.exerciseName))
        .toSet();
    return routines.firstWhere(
      (r) => r.exercises.every((e) => !recentMuscles.contains(e.exerciseName)),
      orElse: () => routines.first,
    );
  }

  // ── 1RM ───────────────────────────────────────────────────────────────────

  static double epley1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  double bestEstimated1RM(String exerciseId) {
    double best = 0;
    for (final s in completedSessions) {
      for (final se in s.exercises.where((e) => e.exerciseId == exerciseId)) {
        for (final set in se.sets.where((s) => s.isCompleted)) {
          final e1rm = epley1RM(set.weight, set.reps);
          if (e1rm > best) best = e1rm;
        }
      }
    }
    return best;
  }

  // ── Exercises ──────────────────────────────────────────────────────────────

  Future<void> addExercise(String name, String muscleGroup, String equipment) async {
    final e = Exercise(
      id: _uuid.v4(),
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      isCustom: true,
    );
    await _db.insertExercise(e);
    exercises = await _db.getExercises();
    notifyListeners();
  }

  Future<void> saveApiExercise(Exercise e) async {
    final saved = Exercise(
      id: e.id,
      name: e.name,
      muscleGroup: e.muscleGroup,
      equipment: e.equipment,
      level: e.level,
      instructions: e.instructions,
      isCustom: true,
    );
    await _db.insertExercise(saved);
    exercises = await _db.getExercises();
    notifyListeners();
  }

  Future<void> deleteExercise(String id) async {
    await _db.deleteExercise(id);
    exercises.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ── Routines ───────────────────────────────────────────────────────────────

  Future<void> saveRoutine(Routine routine) async {
    await _db.insertRoutine(routine);
    routines = await _db.getRoutines();
    notifyListeners();
  }

  Future<void> deleteRoutine(String id) async {
    await _db.deleteRoutine(id);
    routines.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  String newRoutineId() => _uuid.v4();
  String newExerciseId() => _uuid.v4();

  Future<void> seedTemplate(String templateName) async {
    final names = _templates[templateName] ?? [];
    final routineId = _uuid.v4();
    final routineExercises = <RoutineExercise>[];
    for (int i = 0; i < names.length; i++) {
      final name = names[i];
      final ex = exercises.firstWhere(
        (e) => e.name.toLowerCase().contains(name.toLowerCase()),
        orElse: () => Exercise(id: _uuid.v4(), name: name, muscleGroup: 'Other', equipment: 'Other'),
      );
      routineExercises.add(RoutineExercise(
        id: _uuid.v4(),
        routineId: routineId,
        exerciseId: ex.id,
        exerciseName: ex.name,
        targetSets: 3,
        targetReps: 10,
        orderIndex: i,
      ));
    }
    await saveRoutine(Routine(
      id: routineId,
      name: templateName,
      createdAt: DateTime.now(),
      exercises: routineExercises,
    ));
  }

  static List<String> get templateNames => _templates.keys.toList();

  Future<void> saveSessionAsRoutine(WorkoutSession session, String name) async {
    final routineId = _uuid.v4();
    final exercises = <RoutineExercise>[];
    for (int i = 0; i < session.exercises.length; i++) {
      final se = session.exercises[i];
      final completed = se.sets.where((s) => s.isCompleted).toList();
      if (completed.isEmpty) continue;
      final avgReps = (completed.map((s) => s.reps).reduce((a, b) => a + b) / completed.length).round();
      final avgWeight = completed.map((s) => s.weight).reduce((a, b) => a + b) / completed.length;
      exercises.add(RoutineExercise(
        id: _uuid.v4(),
        routineId: routineId,
        exerciseId: se.exerciseId,
        exerciseName: se.exerciseName,
        targetSets: completed.length,
        targetReps: avgReps,
        targetWeight: avgWeight,
        orderIndex: i,
      ));
    }
    await saveRoutine(Routine(
      id: routineId,
      name: name,
      createdAt: DateTime.now(),
      exercises: exercises,
    ));
  }

  // ── Active Session ─────────────────────────────────────────────────────────

  void startSession(String name, {String? routineId, List<RoutineExercise>? fromRoutine}) {
    final sessionId = _uuid.v4();

    // Auto-fill from last session with same routine
    final lastSession = routineId != null
        ? sessions.where((s) => s.routineId == routineId && s.endTime != null).isNotEmpty
            ? sessions.where((s) => s.routineId == routineId && s.endTime != null).first
            : null
        : null;

    final lastBestSets = <String, SetLog>{};
    if (lastSession != null) {
      for (final se in lastSession.exercises) {
        final completed = se.sets.where((s) => s.isCompleted).toList();
        if (completed.isNotEmpty) lastBestSets[se.exerciseId] = completed.last;
      }
    }

    final sexercises = (fromRoutine ?? []).asMap().entries.map((entry) {
      final re = entry.value;
      final seId = _uuid.v4();
      final lastSet = lastBestSets[re.exerciseId];
      return SessionExercise(
        id: seId,
        sessionId: sessionId,
        exerciseId: re.exerciseId,
        exerciseName: re.exerciseName,
        orderIndex: entry.key,
        sets: List.generate(
          re.targetSets,
          (i) => SetLog(
            id: _uuid.v4(),
            sessionExerciseId: seId,
            setNumber: i + 1,
            reps: lastSet?.reps ?? re.targetReps,
            weight: lastSet?.weight ?? (re.targetWeight ?? 0),
          ),
        ),
      );
    }).toList();

    activeSession = WorkoutSession(
      id: sessionId,
      routineId: routineId,
      name: name,
      startTime: DateTime.now(),
      exercises: sexercises,
    );
    notifyListeners();
  }

  void addExerciseToSession(Exercise exercise) {
    if (activeSession == null) return;
    final seId = _uuid.v4();
    activeSession!.exercises.add(SessionExercise(
      id: seId,
      sessionId: activeSession!.id,
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      orderIndex: activeSession!.exercises.length,
      sets: [
        SetLog(id: _uuid.v4(), sessionExerciseId: seId, setNumber: 1, reps: 10, weight: 0)
      ],
    ));
    notifyListeners();
  }

  void reorderExercises(int oldIndex, int newIndex) {
    if (activeSession == null) return;
    final exs = activeSession!.exercises;
    if (newIndex > oldIndex) newIndex--;
    final item = exs.removeAt(oldIndex);
    exs.insert(newIndex, item);
    for (int i = 0; i < exs.length; i++) {
      exs[i].orderIndex = i;
    }
    notifyListeners();
  }

  void addSetToExercise(String sessionExerciseId) {
    if (activeSession == null) return;
    final se = activeSession!.exercises.firstWhere((e) => e.id == sessionExerciseId);
    se.sets.add(SetLog(
      id: _uuid.v4(),
      sessionExerciseId: sessionExerciseId,
      setNumber: se.sets.length + 1,
      reps: se.sets.isNotEmpty ? se.sets.last.reps : 10,
      weight: se.sets.isNotEmpty ? se.sets.last.weight : 0,
    ));
    notifyListeners();
  }

  void removeSetFromExercise(String sessionExerciseId) {
    if (activeSession == null) return;
    final se = activeSession!.exercises.firstWhere((e) => e.id == sessionExerciseId);
    if (se.sets.length > 1) {
      se.sets.removeLast();
      notifyListeners();
    }
  }

  void addWarmupSets(String sessionExerciseId) {
    if (activeSession == null) return;
    final se = activeSession!.exercises.firstWhere((e) => e.id == sessionExerciseId);
    final targetWeight = se.sets.isNotEmpty ? se.sets.first.weight : 0.0;
    final warmups = [
      SetLog(id: _uuid.v4(), sessionExerciseId: sessionExerciseId,
          setNumber: 0, reps: 8, weight: targetWeight * 0.5),
      SetLog(id: _uuid.v4(), sessionExerciseId: sessionExerciseId,
          setNumber: 0, reps: 5, weight: targetWeight * 0.75),
    ];
    se.sets.insertAll(0, warmups);
    for (int i = 0; i < se.sets.length; i++) {
      se.sets[i] = SetLog(
        id: se.sets[i].id,
        sessionExerciseId: se.sets[i].sessionExerciseId,
        setNumber: i + 1,
        reps: se.sets[i].reps,
        weight: se.sets[i].weight,
        isCompleted: se.sets[i].isCompleted,
      );
    }
    notifyListeners();
  }

  void toggleSuperset(String sessionExerciseId) {
    if (activeSession == null) return;
    final se = activeSession!.exercises.firstWhere((e) => e.id == sessionExerciseId);
    se.supersetWithNext = !se.supersetWithNext;
    notifyListeners();
  }

  void updateExerciseNotes(String sessionExerciseId, String notes) {
    if (activeSession == null) return;
    final se = activeSession!.exercises.firstWhere((e) => e.id == sessionExerciseId);
    se.notes = notes;
    notifyListeners();
  }

  void updateExerciseRestSeconds(String sessionExerciseId, int seconds) {
    if (activeSession == null) return;
    final se = activeSession!.exercises.firstWhere((e) => e.id == sessionExerciseId);
    se.restSeconds = seconds;
    notifyListeners();
  }

  void updateSet(String setId,
      {int? reps,
      double? weight,
      bool? isCompleted,
      int? rpe,
      bool? isDropset,
      bool? toFailure}) {
    if (activeSession == null) return;
    for (final se in activeSession!.exercises) {
      for (final s in se.sets) {
        if (s.id == setId) {
          if (reps != null) s.reps = reps;
          if (weight != null) s.weight = weight;
          if (isCompleted != null) s.isCompleted = isCompleted;
          if (rpe != null) s.rpe = rpe;
          if (isDropset != null) s.isDropset = isDropset;
          if (toFailure != null) s.toFailure = toFailure;
          notifyListeners();
          return;
        }
      }
    }
  }

  Future<WorkoutSession> finishSession() async {
    if (activeSession == null) throw StateError('No active session');
    final finished = WorkoutSession(
      id: activeSession!.id,
      routineId: activeSession!.routineId,
      name: activeSession!.name,
      startTime: activeSession!.startTime,
      endTime: DateTime.now(),
      exercises: activeSession!.exercises,
    );
    await _db.insertSession(finished);
    lastSessionPRs = await _detectPRs(finished);
    sessions = await _db.getSessions();
    activeSession = null;
    if (activeProgram != null) {
      activeProgram = activeProgram!.advance();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_program', jsonEncode(activeProgram!.toJson()));
    }
    notifyListeners();
    return finished;
  }

  Future<Map<String, double>> _detectPRs(WorkoutSession session) async {
    final prs = <String, double>{};
    for (final se in session.exercises) {
      final history = await _db.getProgressForExercise(se.exerciseId);
      if (history.length < 2) continue;
      final prevBest = history
          .take(history.length - 1)
          .map((r) => (r['maxWeight'] as num).toDouble())
          .fold(0.0, (a, b) => a > b ? a : b);
      final todayBest = se.sets
          .where((s) => s.isCompleted)
          .fold(0.0, (best, s) => s.weight > best ? s.weight : best);
      if (todayBest > prevBest && todayBest > 0) {
        prs[se.exerciseId] = todayBest;
      }
    }
    return prs;
  }

  bool sessionHasPR(WorkoutSession session) =>
      session.exercises.any((se) => lastSessionPRs.containsKey(se.exerciseId));

  Future<void> deleteSession(String id) async {
    await _db.deleteSession(id);
    sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void cancelSession() {
    activeSession = null;
    notifyListeners();
  }

  // ── Body Weight ────────────────────────────────────────────────────────────

  Future<void> addBodyWeight(double weightKg) async {
    final entry = BodyWeightEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      weightKg: weightKg,
    );
    await _db.insertBodyWeight(entry);
    bodyWeights = await _db.getBodyWeights();
    notifyListeners();
  }

  Future<void> deleteBodyWeight(String id) async {
    await _db.deleteBodyWeight(id);
    bodyWeights.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ── Body Measurements ──────────────────────────────────────────────────────

  Future<void> addBodyMeasurement(BodyMeasurement m) async {
    await _db.insertBodyMeasurement(m);
    bodyMeasurements = await _db.getBodyMeasurements();
    notifyListeners();
  }

  Future<void> deleteBodyMeasurement(String id) async {
    await _db.deleteBodyMeasurement(id);
    bodyMeasurements.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  // ── Nutrition Logs ─────────────────────────────────────────────────────────

  Future<void> addNutritionLog(NutritionLog log) async {
    await _db.insertNutritionLog(log);
    nutritionLogs = await _db.getNutritionLogs();
    notifyListeners();
  }

  Future<void> deleteNutritionLog(String id) async {
    await _db.deleteNutritionLog(id);
    nutritionLogs.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  // ── Smart Progression Engine ───────────────────────────────────────────────

  Map<String, dynamic>? getProgressionSuggestion(String exerciseId, {int targetReps = 8}) {
    final history = <List<SetLog>>[];
    for (final s in completedSessions.reversed) {
      for (final se in s.exercises.where((e) => e.exerciseId == exerciseId)) {
        final done = se.sets.where((st) => st.isCompleted).toList();
        if (done.isNotEmpty) history.add(done);
      }
      if (history.length >= 3) break;
    }
    if (history.isEmpty) return null;

    final last = history.first;
    final avgWeight = last.map((s) => s.weight).reduce((a, b) => a + b) / last.length;
    final avgReps = last.map((s) => s.reps).reduce((a, b) => a + b) / last.length;
    final ratedSets = last.where((s) => s.rpe > 0).toList();
    final avgRpe = ratedSets.isEmpty
        ? 0.0
        : ratedSets.map((s) => s.rpe).reduce((a, b) => a + b) / ratedSets.length;

    // Deload signal: RPE ≥ 9 for 2 consecutive sessions
    if (history.length >= 2 && avgRpe >= 9) {
      final prev = history[1];
      final prevRated = prev.where((s) => s.rpe > 0).toList();
      final prevRpe = prevRated.isEmpty
          ? 0.0
          : prevRated.map((s) => s.rpe).reduce((a, b) => a + b) / prevRated.length;
      if (prevRpe >= 9) {
        return {
          'weight': (avgWeight * 0.9 / 2.5).round() * 2.5,
          'note': 'Deload — high RPE two sessions running',
          'level': 'deload',
        };
      }
    }

    if (avgRpe > 0) {
      if (avgRpe <= 7 && avgReps >= targetReps) {
        return {'weight': avgWeight + 2.5, 'note': 'Hit target at RPE ${avgRpe.round()} — add weight!', 'level': 'increase'};
      } else if (avgRpe >= 9) {
        return {'weight': avgWeight, 'note': 'Very hard session (RPE ${avgRpe.round()}) — hold weight', 'level': 'hold'};
      } else if (avgRpe >= 8) {
        return {'weight': avgWeight, 'note': 'Hard session (RPE ${avgRpe.round()}) — maintain', 'level': 'hold'};
      }
    }

    // No RPE data — use reps only
    if (avgReps >= targetReps) {
      return {'weight': avgWeight + 2.5, 'note': 'Hit ${avgReps.round()} reps — try +2.5 kg', 'level': 'increase'};
    }
    return null;
  }

  // ── Muscle Balance ─────────────────────────────────────────────────────────

  Map<String, int> get weeklySetBalance {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final result = <String, int>{'Push': 0, 'Pull': 0, 'Legs': 0, 'Core': 0};
    for (final s in completedSessions.where((s) => s.startTime.isAfter(weekStart))) {
      for (final se in s.exercises) {
        final ex = exercises.firstWhere((e) => e.id == se.exerciseId,
            orElse: () => Exercise(id: '', name: '', muscleGroup: 'Other', equipment: ''));
        final sets = se.sets.where((st) => st.isCompleted).length;
        switch (ex.muscleGroup) {
          case 'Chest':
          case 'Shoulders':
            result['Push'] = result['Push']! + sets;
          case 'Back':
            result['Pull'] = result['Pull']! + sets;
          case 'Legs':
            result['Legs'] = result['Legs']! + sets;
          case 'Core':
            result['Core'] = result['Core']! + sets;
        }
      }
    }
    return result;
  }

  ({String message, Color color})? get muscleBalanceTip {
    final b = weeklySetBalance;
    final push = b['Push']!;
    final pull = b['Pull']!;
    final legs = b['Legs']!;
    final core = b['Core']!;
    final total = push + pull + legs + core;
    if (total < 4) return null;

    if (push > 0 && pull > 0 && push > pull * 1.6) {
      return (message: 'Push:Pull ${push}:$pull — add more rows/pull-ups', color: Colors.orange);
    }
    if (total > 8 && legs < (total * 0.15).round()) {
      return (message: 'Low leg volume this week — don\'t skip leg day!', color: Colors.orange);
    }
    if (push > 0 && pull > 0 && legs > 0) {
      final ratio = (push * 10 / pull).round() / 10;
      if (ratio <= 1.3) {
        return (message: 'Push:Pull $ratio:1 · Well balanced week!', color: Colors.green);
      }
    }
    return null;
  }

  // ── Training Programs ──────────────────────────────────────────────────────

  Future<void> startProgram(ProgramType type, Map<String, double> trainingMaxes) async {
    activeProgram = ActiveProgram(
      type: type,
      startDate: DateTime.now(),
      trainingMaxes: trainingMaxes,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_program', jsonEncode(activeProgram!.toJson()));
    notifyListeners();
  }

  Future<void> advanceProgram() async {
    if (activeProgram == null) return;
    activeProgram = activeProgram!.advance();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_program', jsonEncode(activeProgram!.toJson()));
    notifyListeners();
  }

  Future<void> cancelProgram() async {
    activeProgram = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_program');
    notifyListeners();
  }

  void startProgramSession() {
    if (activeProgram == null) return;
    final programExercises = activeProgram!.nextSessionExercises;
    final sessionId = _uuid.v4();

    final sexercises = programExercises.asMap().entries.map((entry) {
      final pe = entry.value;
      final seId = _uuid.v4();
      final ex = exercises.firstWhere(
        (e) => e.name.toLowerCase().contains(pe.name.split(' ').first.toLowerCase()) &&
            e.name.toLowerCase().contains(pe.name.split(' ').last.toLowerCase()),
        orElse: () => exercises.firstWhere(
          (e) => e.name.toLowerCase().contains(pe.name.toLowerCase().split(' ').first),
          orElse: () => Exercise(
              id: _uuid.v4(), name: pe.name, muscleGroup: 'Other', equipment: 'Barbell'),
        ),
      );
      return SessionExercise(
        id: seId,
        sessionId: sessionId,
        exerciseId: ex.id,
        exerciseName: ex.name,
        orderIndex: entry.key,
        sets: List.generate(
          pe.sets,
          (i) => SetLog(
            id: _uuid.v4(),
            sessionExerciseId: seId,
            setNumber: i + 1,
            reps: pe.reps,
            weight: pe.weight,
          ),
        ),
      );
    }).toList();

    activeSession = WorkoutSession(
      id: sessionId,
      name: activeProgram!.nextSessionName,
      startTime: DateTime.now(),
      exercises: sexercises,
    );
    notifyListeners();
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProgress(String exerciseId) =>
      _db.getProgressForExercise(exerciseId);

  // ── Export / Backup ────────────────────────────────────────────────────────

  Future<String> exportCsv() => _db.exportCsv();
  Future<String> backupDb() => _db.backupToDocuments();
  Future<void> restoreDb(String path) => _db.restoreFromFile(path);
}
