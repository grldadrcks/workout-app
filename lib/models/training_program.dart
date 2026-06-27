import 'dart:convert';

enum ProgramType { beginnerFullBody, startingStrength, ppl, fiveThreeOne }

class ProgramDefinition {
  final ProgramType type;
  final String name;
  final String shortName;
  final String description;
  final String details;
  final String difficulty; // 'Beginner', 'Intermediate', 'Advanced'
  final List<String> liftKeys;
  final List<String> liftLabels;
  final List<String> dayNames;

  const ProgramDefinition({
    required this.type,
    required this.name,
    required this.shortName,
    required this.description,
    required this.details,
    required this.difficulty,
    required this.liftKeys,
    required this.liftLabels,
    required this.dayNames,
  });
}

const programDefinitions = <ProgramDefinition>[
  ProgramDefinition(
    type: ProgramType.beginnerFullBody,
    name: 'Full Body Starter',
    shortName: 'FBS',
    difficulty: 'Beginner',
    description: 'The perfect first program. Three full-body sessions per week '
        'with automatic weight increases every session.',
    details: '3 days/week · A/B alternating · Add weight every session · 3×8',
    liftKeys: ['squat', 'bench', 'deadlift', 'ohp'],
    liftLabels: ['Squat', 'Bench Press', 'Deadlift', 'Overhead Press'],
    dayNames: ['Workout A', 'Workout B'],
  ),
  ProgramDefinition(
    type: ProgramType.startingStrength,
    name: 'Starting Strength',
    shortName: 'SS',
    difficulty: 'Intermediate',
    description: 'Mark Rippetoe\'s classic barbell program. '
        'Heavier sets of 5 with fast linear progression.',
    details: '3 days/week · A/B alternating · 3×5 · +2.5–5 kg per session',
    liftKeys: ['squat', 'bench', 'deadlift', 'ohp'],
    liftLabels: ['Squat', 'Bench Press', 'Deadlift', 'Overhead Press'],
    dayNames: ['Workout A', 'Workout B'],
  ),
  ProgramDefinition(
    type: ProgramType.ppl,
    name: 'Push / Pull / Legs',
    shortName: 'PPL',
    difficulty: 'Intermediate',
    description: 'A balanced split covering all major muscle groups '
        'with dedicated push, pull, and leg days.',
    details: '3 days/week · Push, Pull, Legs rotation · +2.5 kg/week on main lifts',
    liftKeys: ['bench', 'ohp', 'row', 'squat', 'deadlift'],
    liftLabels: ['Bench Press', 'Overhead Press', 'Barbell Row', 'Squat', 'Deadlift / RDL'],
    dayNames: ['Push Day', 'Pull Day', 'Leg Day'],
  ),
  ProgramDefinition(
    type: ProgramType.fiveThreeOne,
    name: '5/3/1',
    shortName: '5/3/1',
    difficulty: 'Advanced',
    description: 'Jim Wendler\'s percentage-based strength program. '
        'Slow, steady progress built around your 1-rep max.',
    details: '4 days/week · 4-week cycles · Percentage-based · Requires 1RM knowledge',
    liftKeys: ['squat', 'bench', 'deadlift', 'ohp'],
    liftLabels: ['Squat (training max)', 'Bench (training max)', 'Deadlift (training max)', 'OHP (training max)'],
    dayNames: ['OHP Day', 'Deadlift Day', 'Bench Day', 'Squat Day'],
  ),
];

class _PEx {
  final String name;
  final int sets;
  final int reps;
  final double weight;
  const _PEx(this.name, this.sets, this.reps, this.weight);
}

class ActiveProgram {
  final ProgramType type;
  final DateTime startDate;
  final int currentWeek;
  final int currentDayIndex;
  final int sessionsCompleted;
  final Map<String, double> trainingMaxes;

  const ActiveProgram({
    required this.type,
    required this.startDate,
    this.currentWeek = 1,
    this.currentDayIndex = 0,
    this.sessionsCompleted = 0,
    required this.trainingMaxes,
  });

  ProgramDefinition get definition =>
      programDefinitions.firstWhere((d) => d.type == type);

  String get nextSessionName {
    final def = definition;
    final dayName = def.dayNames[currentDayIndex % def.dayNames.length];
    return '${def.shortName} W$currentWeek · $dayName';
  }

  ActiveProgram advance() {
    final def = definition;
    final nextDayIdx = currentDayIndex + 1;
    final daysInCycle = type == ProgramType.fiveThreeOne ? 4 : def.dayNames.length;
    final completedFullCycle = nextDayIdx >= daysInCycle;

    if (completedFullCycle) {
      // Increase training maxes at end of cycle
      final updated = Map<String, double>.from(trainingMaxes);
      if (type == ProgramType.beginnerFullBody) {
        for (final k in ['squat', 'bench', 'deadlift', 'ohp']) {
          if (updated.containsKey(k)) updated[k] = updated[k]! + 2.5;
        }
      } else if (type == ProgramType.startingStrength) {
        for (final k in ['squat', 'deadlift']) {
          if (updated.containsKey(k)) updated[k] = updated[k]! + 5;
        }
        for (final k in ['bench', 'ohp']) {
          if (updated.containsKey(k)) updated[k] = updated[k]! + 2.5;
        }
      } else if (type == ProgramType.fiveThreeOne) {
        if ((currentWeek % 4) == 3) {
          for (final k in ['squat', 'deadlift']) {
            if (updated.containsKey(k)) updated[k] = updated[k]! + 5;
          }
          for (final k in ['bench', 'ohp']) {
            if (updated.containsKey(k)) updated[k] = updated[k]! + 2.5;
          }
        }
      } else {
        // PPL: weekly increment
        for (final k in ['bench', 'ohp', 'row', 'squat']) {
          if (updated.containsKey(k)) updated[k] = updated[k]! + 2.5;
        }
      }
      return ActiveProgram(
        type: type,
        startDate: startDate,
        currentWeek: currentWeek + 1,
        currentDayIndex: 0,
        sessionsCompleted: sessionsCompleted + 1,
        trainingMaxes: updated,
      );
    }

    return ActiveProgram(
      type: type,
      startDate: startDate,
      currentWeek: currentWeek,
      currentDayIndex: nextDayIdx,
      sessionsCompleted: sessionsCompleted + 1,
      trainingMaxes: trainingMaxes,
    );
  }

  List<_PEx> get nextSessionExercises {
    final dayIdx = currentDayIndex % definition.dayNames.length;
    switch (type) {
      case ProgramType.beginnerFullBody:
        return _fbsDay(dayIdx);
      case ProgramType.startingStrength:
        return _ssDay(dayIdx);
      case ProgramType.fiveThreeOne:
        return _531Day(dayIdx, currentWeek);
      case ProgramType.ppl:
        return _pplDay(dayIdx);
    }
  }

  double _tm(String key, double fallback) => trainingMaxes[key] ?? fallback;

  static double _round(double w) => (w / 2.5).round() * 2.5;

  List<_PEx> _fbsDay(int dayIdx) {
    final sq = _tm('squat', 20);
    final bp = _tm('bench', 20);
    final dl = _tm('deadlift', 20);
    final ohp = _tm('ohp', 15);
    if (dayIdx == 0) {
      return [
        _PEx('Barbell Squat', 3, 8, sq),
        _PEx('Bench Press', 3, 8, bp),
        _PEx('Deadlift', 1, 8, dl),
      ];
    } else {
      return [
        _PEx('Barbell Squat', 3, 8, sq),
        _PEx('Overhead Press', 3, 8, ohp),
        _PEx('Bent Over Barbell Row', 3, 10, _round(sq * 0.5)),
      ];
    }
  }

  List<_PEx> _ssDay(int dayIdx) {
    final sq = _tm('squat', 60);
    final bp = _tm('bench', 40);
    final dl = _tm('deadlift', 80);
    final ohp = _tm('ohp', 30);
    final row = _tm('row', 40);
    if (dayIdx == 0) {
      return [
        _PEx('Barbell Squat', 3, 5, sq),
        _PEx('Bench Press', 3, 5, bp),
        _PEx('Deadlift', 1, 5, dl),
      ];
    } else {
      return [
        _PEx('Barbell Squat', 3, 5, sq),
        _PEx('Overhead Press', 3, 5, ohp),
        _PEx('Bent Over Barbell Row', 3, 5, row),
      ];
    }
  }

  List<_PEx> _531Day(int dayIdx, int week) {
    final liftTMs = [
      _tm('ohp', 50),
      _tm('deadlift', 100),
      _tm('bench', 80),
      _tm('squat', 100),
    ];
    final liftNames = [
      'Overhead Press',
      'Deadlift',
      'Bench Press',
      'Barbell Squat',
    ];
    final assistNames = [
      'Bent Over Barbell Row',
      'Leg Press',
      'Bent Over Barbell Row',
      'Romanian Deadlift',
    ];

    final tm = liftTMs[dayIdx % 4];
    final liftName = liftNames[dayIdx % 4];
    final assistName = assistNames[dayIdx % 4];

    final weekInCycle = ((week - 1) % 4) + 1;
    List<(double, int)> scheme;
    switch (weekInCycle) {
      case 1: scheme = [(0.65, 5), (0.75, 5), (0.85, 5)];
      case 2: scheme = [(0.70, 3), (0.80, 3), (0.90, 3)];
      case 3: scheme = [(0.75, 5), (0.85, 3), (0.95, 1)];
      default: scheme = [(0.40, 5), (0.50, 5), (0.60, 5)]; // deload
    }

    final result = <_PEx>[];
    for (final (pct, reps) in scheme) {
      result.add(_PEx(liftName, 1, reps, _round(tm * pct)));
    }
    if (weekInCycle != 4) {
      result.add(_PEx(liftName, 5, 10, _round(tm * 0.65)));
    }
    result.add(_PEx(assistName, 3, 10, 0));
    return result;
  }

  List<_PEx> _pplDay(int dayIdx) {
    final bench = _tm('bench', 60);
    final ohp = _tm('ohp', 40);
    final row = _tm('row', 60);
    final sq = _tm('squat', 80);
    final dl = _tm('deadlift', 100);

    switch (dayIdx) {
      case 0:
        return [
          _PEx('Bench Press', 4, 5, bench),
          _PEx('Overhead Press', 3, 8, ohp),
          _PEx('Incline Dumbbell Press', 3, 10, _round(bench * 0.4)),
          _PEx('Triceps Pushdown', 3, 12, 0),
          _PEx('Lateral Raise', 3, 15, 0),
        ];
      case 1:
        return [
          _PEx('Bent Over Barbell Row', 4, 5, row),
          _PEx('Pull-Up', 3, 8, 0),
          _PEx('Seated Cable Row', 3, 10, 0),
          _PEx('Barbell Curl', 3, 12, 0),
          _PEx('Face Pull', 3, 15, 0),
        ];
      default:
        return [
          _PEx('Barbell Squat', 4, 5, sq),
          _PEx('Romanian Deadlift', 3, 8, _round(dl * 0.6)),
          _PEx('Leg Press', 3, 12, 0),
          _PEx('Leg Curl', 3, 12, 0),
          _PEx('Standing Calf Raise', 4, 15, 0),
        ];
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'startDate': startDate.toIso8601String(),
        'currentWeek': currentWeek,
        'currentDayIndex': currentDayIndex,
        'sessionsCompleted': sessionsCompleted,
        'trainingMaxes': trainingMaxes,
      };

  factory ActiveProgram.fromJson(Map<String, dynamic> j) => ActiveProgram(
        type: ProgramType.values.firstWhere((t) => t.name == j['type']),
        startDate: DateTime.parse(j['startDate']),
        currentWeek: j['currentWeek'] ?? 1,
        currentDayIndex: j['currentDayIndex'] ?? 0,
        sessionsCompleted: j['sessionsCompleted'] ?? 0,
        trainingMaxes: Map<String, double>.from(
          (j['trainingMaxes'] as Map)
              .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        ),
      );

  static ActiveProgram? tryFromJsonString(String? s) {
    if (s == null) return null;
    try {
      return ActiveProgram.fromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }
}
