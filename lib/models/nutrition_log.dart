class NutritionLog {
  final String id;
  final DateTime date;
  final int? calories;
  final double? proteinG;
  final String note;

  NutritionLog({
    required this.id,
    required this.date,
    this.calories,
    this.proteinG,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'calories': calories,
        'protein_g': proteinG,
        'note': note,
      };

  factory NutritionLog.fromMap(Map<String, dynamic> m) => NutritionLog(
        id: m['id'],
        date: DateTime.parse(m['date']),
        calories: m['calories'] as int?,
        proteinG: (m['protein_g'] as num?)?.toDouble(),
        note: m['note'] as String? ?? '',
      );
}
