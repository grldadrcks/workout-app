import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';

class WorkoutXApi {
  static const _baseUrl = 'https://api.workoutxapp.com/v1';
  static const _apiKey = 'wx_190cedd2e8e78b1710ceca2950bf3b7d199b46b2ef3f05a3d7a58c0b';
  static const _headers = {'X-WorkoutX-Key': _apiKey};

  static Future<List<Exercise>> search({
    String? name,
    String? equipment,
    String? bodyPart,
  }) async {
    final Uri uri;
    if (name != null && name.isNotEmpty) {
      uri = Uri.parse('$_baseUrl/exercises/name/${Uri.encodeComponent(name)}');
    } else if (equipment != null && equipment.isNotEmpty) {
      uri = Uri.parse('$_baseUrl/exercises/equipment/${Uri.encodeComponent(equipment)}');
    } else if (bodyPart != null && bodyPart.isNotEmpty) {
      uri = Uri.parse('$_baseUrl/exercises/bodyPart/${Uri.encodeComponent(bodyPart)}');
    } else {
      uri = Uri.parse('$_baseUrl/exercises');
    }

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('WorkoutX API error ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final List<dynamic> list =
        body is Map ? ((body['data'] as List?) ?? []) : body as List;
    return list.cast<Map<String, dynamic>>().map(_fromJson).toList();
  }

  static Exercise _fromJson(Map<String, dynamic> j) {
    return Exercise(
      id: 'wx_${j['id']}',
      name: j['name'] as String? ?? 'Unknown',
      muscleGroup: _mapBodyPart(j['bodyPart'] as String? ?? ''),
      equipment: _mapEquipment(j['equipment'] as String? ?? ''),
      level: j['difficulty'] as String? ?? '',
      instructions: _parseInstructions(j['instructions']),
      isCustom: false,
      gifUrl: j['gifUrl'] as String?,
    );
  }

  static List<String> _parseInstructions(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      return raw
          .split('. ')
          .where((s) => s.isNotEmpty)
          .map((s) => s.endsWith('.') ? s : '$s.')
          .toList();
    }
    return [];
  }

  static String _mapBodyPart(String raw) => switch (raw.toLowerCase()) {
        'chest' => 'Chest',
        'back' => 'Back',
        'shoulders' => 'Shoulders',
        'legs' || 'upper legs' || 'lower legs' => 'Legs',
        'arms' || 'upper arms' || 'lower arms' => 'Arms',
        'core' || 'waist' => 'Core',
        _ => 'Other',
      };

  static String _mapEquipment(String raw) => switch (raw.toLowerCase()) {
        'barbell' => 'Barbell',
        'dumbbell' => 'Dumbbell',
        'cable' => 'Cable',
        'machine' => 'Machine',
        'body weight' || 'bodyweight' || '' => 'Bodyweight',
        'band' || 'bands' || 'resistance band' => 'Bands',
        'kettlebell' => 'Kettlebell',
        _ => 'Other',
      };
}
