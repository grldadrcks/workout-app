class BodyMeasurement {
  final String id;
  final DateTime date;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? bicepL;
  final double? bicepR;
  final double? thighL;
  final double? thighR;

  BodyMeasurement({
    required this.id,
    required this.date,
    this.chest,
    this.waist,
    this.hips,
    this.bicepL,
    this.bicepR,
    this.thighL,
    this.thighR,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'chest': chest,
        'waist': waist,
        'hips': hips,
        'bicep_l': bicepL,
        'bicep_r': bicepR,
        'thigh_l': thighL,
        'thigh_r': thighR,
      };

  factory BodyMeasurement.fromMap(Map<String, dynamic> m) => BodyMeasurement(
        id: m['id'],
        date: DateTime.parse(m['date']),
        chest: (m['chest'] as num?)?.toDouble(),
        waist: (m['waist'] as num?)?.toDouble(),
        hips: (m['hips'] as num?)?.toDouble(),
        bicepL: (m['bicep_l'] as num?)?.toDouble(),
        bicepR: (m['bicep_r'] as num?)?.toDouble(),
        thighL: (m['thigh_l'] as num?)?.toDouble(),
        thighR: (m['thigh_r'] as num?)?.toDouble(),
      );
}
