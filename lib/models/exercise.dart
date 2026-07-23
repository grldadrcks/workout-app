class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String level;
  final List<String> instructions;
  final bool isCustom;
  final String? gifUrl;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.level = '',
    this.instructions = const [],
    this.isCustom = false,
    this.gifUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'equipment': equipment,
        'level': level,
        'instructions': instructions.join('||'),
        'isCustom': isCustom ? 1 : 0,
        'gifUrl': gifUrl,
      };

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        id: m['id'],
        name: m['name'],
        muscleGroup: m['muscleGroup'],
        equipment: m['equipment'],
        level: m['level'] ?? '',
        instructions: m['instructions'] != null && (m['instructions'] as String).isNotEmpty
            ? (m['instructions'] as String).split('||')
            : [],
        isCustom: m['isCustom'] == 1,
        gifUrl: m['gifUrl'] as String?,
      );

  factory Exercise.fromJson(Map<String, dynamic> j) {
    final primary = (j['primaryMuscles'] as List?)?.firstOrNull as String? ?? '';
    return Exercise(
      id: j['id'] as String,
      name: j['name'] as String,
      muscleGroup: _mapMuscle(primary),
      equipment: _mapEquipment(j['equipment'] as String? ?? ''),
      level: j['level'] as String? ?? '',
      instructions: (j['instructions'] as List?)?.cast<String>() ?? [],
      isCustom: false,
    );
  }

  static String _mapMuscle(String raw) => switch (raw) {
        'chest' => 'Chest',
        'lats' || 'lower back' || 'middle back' || 'traps' => 'Back',
        'shoulders' => 'Shoulders',
        'quadriceps' || 'hamstrings' || 'calves' || 'glutes' || 'abductors' || 'adductors' =>
          'Legs',
        'biceps' || 'triceps' || 'forearms' => 'Arms',
        'abdominals' => 'Core',
        _ => 'Other',
      };

  static String _mapEquipment(String raw) => switch (raw) {
        'body only' => 'Bodyweight',
        'barbell' => 'Barbell',
        'dumbbell' => 'Dumbbell',
        'cable' => 'Cable',
        'machine' => 'Machine',
        'bands' => 'Bands',
        'kettlebells' => 'Kettlebell',
        'e-z curl bar' => 'EZ Bar',
        'exercise ball' => 'Exercise Ball',
        'foam roll' => 'Foam Roll',
        'medicine ball' => 'Medicine Ball',
        _ => 'Other',
      };
}
