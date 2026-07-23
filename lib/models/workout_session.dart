class WorkoutSession {
  final String id;
  final String? routineId;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  List<SessionExercise> exercises;

  WorkoutSession({
    required this.id,
    this.routineId,
    required this.name,
    required this.startTime,
    this.endTime,
    this.exercises = const [],
  });

  int get totalVolume => exercises.fold(
        0,
        (sum, e) => sum + e.sets.fold(0, (s, set) => s + (set.reps * set.weight).round()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'routineId': routineId,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      };

  factory WorkoutSession.fromMap(Map<String, dynamic> m) => WorkoutSession(
        id: m['id'],
        routineId: m['routineId'],
        name: m['name'],
        startTime: DateTime.parse(m['startTime']),
        endTime: m['endTime'] != null ? DateTime.parse(m['endTime']) : null,
      );
}

class SessionExercise {
  final String id;
  final String sessionId;
  final String exerciseId;
  final String exerciseName;
  int orderIndex;
  String notes;
  bool supersetWithNext;
  int restSeconds;
  List<SetLog> sets;

  SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.exerciseName,
    required this.orderIndex,
    this.notes = '',
    this.supersetWithNext = false,
    this.restSeconds = 60,
    this.sets = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'orderIndex': orderIndex,
        'notes': notes,
        'superset_with_next': supersetWithNext ? 1 : 0,
        'rest_seconds': restSeconds,
      };

  factory SessionExercise.fromMap(Map<String, dynamic> m) => SessionExercise(
        id: m['id'],
        sessionId: m['sessionId'],
        exerciseId: m['exerciseId'],
        exerciseName: m['exerciseName'],
        orderIndex: m['orderIndex'],
        notes: m['notes'] as String? ?? '',
        supersetWithNext: (m['superset_with_next'] as int? ?? 0) == 1,
        restSeconds: m['rest_seconds'] as int? ?? 60,
      );
}

class SetLog {
  final String id;
  final String sessionExerciseId;
  final int setNumber;
  int reps;
  double weight;
  bool isCompleted;
  int rpe; // 0 = not set, 1–10
  bool isDropset;
  bool toFailure;

  SetLog({
    required this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    required this.reps,
    required this.weight,
    this.isCompleted = false,
    this.rpe = 0,
    this.isDropset = false,
    this.toFailure = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionExerciseId': sessionExerciseId,
        'setNumber': setNumber,
        'reps': reps,
        'weight': weight,
        'isCompleted': isCompleted ? 1 : 0,
        'rpe': rpe,
        'is_dropset': isDropset ? 1 : 0,
        'to_failure': toFailure ? 1 : 0,
      };

  factory SetLog.fromMap(Map<String, dynamic> m) => SetLog(
        id: m['id'],
        sessionExerciseId: m['sessionExerciseId'],
        setNumber: m['setNumber'],
        reps: m['reps'],
        weight: (m['weight'] as num).toDouble(),
        isCompleted: m['isCompleted'] == 1,
        rpe: m['rpe'] as int? ?? 0,
        isDropset: (m['is_dropset'] as int? ?? 0) == 1,
        toFailure: (m['to_failure'] as int? ?? 0) == 1,
      );
}
