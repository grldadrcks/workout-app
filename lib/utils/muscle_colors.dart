import 'package:flutter/material.dart';
import '../models/exercise.dart';

const Map<String, Color> kMuscleColors = {
  'Chest':     Color(0xFFEF5350),
  'Back':      Color(0xFF42A5F5),
  'Shoulders': Color(0xFFAB47BC),
  'Legs':      Color(0xFF66BB6A),
  'Arms':      Color(0xFFFFA726),
  'Core':      Color(0xFF26C6DA),
  'Other':     Color(0xFF78909C),
};

Color muscleColor(String group) => kMuscleColors[group] ?? const Color(0xFF78909C);

String muscleGroupForId(String exerciseId, List<Exercise> exercises) =>
    exercises.where((e) => e.id == exerciseId).firstOrNull?.muscleGroup ?? 'Other';

String muscleGroupForName(String name, List<Exercise> exercises) =>
    exercises.where((e) => e.name == name).firstOrNull?.muscleGroup ?? 'Other';
