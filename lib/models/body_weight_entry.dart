class BodyWeightEntry {
  final String id;
  final DateTime date;
  final double weightKg;

  const BodyWeightEntry({required this.id, required this.date, required this.weightKg});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'weight_kg': weightKg,
      };

  factory BodyWeightEntry.fromMap(Map<String, dynamic> m) => BodyWeightEntry(
        id: m['id'],
        date: DateTime.parse(m['date']),
        weightKg: (m['weight_kg'] as num).toDouble(),
      );
}
