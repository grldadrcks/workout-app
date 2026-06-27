class Routine {
  final String id;
  final String name;
  final DateTime createdAt;
  List<RoutineExercise> exercises;

  Routine({
    required this.id,
    required this.name,
    required this.createdAt,
    this.exercises = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Routine.fromMap(Map<String, dynamic> m) => Routine(
        id: m['id'],
        name: m['name'],
        createdAt: DateTime.parse(m['createdAt']),
      );
}

class RoutineExercise {
  final String id;
  final String routineId;
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final int targetReps;
  final double? targetWeight;
  final int orderIndex;

  const RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetWeight,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'routineId': routineId,
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'targetWeight': targetWeight,
        'orderIndex': orderIndex,
      };

  factory RoutineExercise.fromMap(Map<String, dynamic> m) => RoutineExercise(
        id: m['id'],
        routineId: m['routineId'],
        exerciseId: m['exerciseId'],
        exerciseName: m['exerciseName'],
        targetSets: m['targetSets'],
        targetReps: m['targetReps'],
        targetWeight: m['targetWeight'],
        orderIndex: m['orderIndex'],
      );

  RoutineExercise copyWith({int? targetSets, int? targetReps, double? targetWeight}) =>
      RoutineExercise(
        id: id,
        routineId: routineId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        targetSets: targetSets ?? this.targetSets,
        targetReps: targetReps ?? this.targetReps,
        targetWeight: targetWeight ?? this.targetWeight,
        orderIndex: orderIndex,
      );
}
