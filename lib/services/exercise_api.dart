import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';

class ExerciseApi {
  static const _baseUrl = 'https://api.api-ninjas.com/v1/exercises';
  static const _apiKey = 'mG36ZlVlnj0F2w5Lf0gFnDgYhr3O7ITw7oSU8WV2';

  static Future<List<Exercise>> search({String? name, String? muscle, String? type}) async {
    final params = <String, String>{};
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (muscle != null && muscle.isNotEmpty) params['muscle'] = muscle;
    if (type != null && type.isNotEmpty) params['type'] = type;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await http.get(uri, headers: {'X-Api-Key': _apiKey});

    if (response.statusCode != 200) throw Exception('API error ${response.statusCode}');

    final list = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    return list.map(_fromApiJson).toList();
  }

  static Exercise _fromApiJson(Map<String, dynamic> j) {
    final muscle = j['muscle'] as String? ?? '';
    final equip = j['equipments'] is List
        ? ((j['equipments'] as List).isNotEmpty ? j['equipments'][0] as String : '')
        : j['equipments'] as String? ?? '';

    return Exercise(
      id: 'api_${(j['name'] as String).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: j['name'] as String,
      muscleGroup: _mapMuscle(muscle),
      equipment: _mapEquipment(equip),
      level: j['difficulty'] as String? ?? '',
      instructions: j['instructions'] != null && (j['instructions'] as String).isNotEmpty
          ? (j['instructions'] as String).split('. ').where((s) => s.isNotEmpty).map((s) => s.endsWith('.') ? s : '$s.').toList()
          : [],
      isCustom: false,
    );
  }

  static String _mapMuscle(String raw) => switch (raw) {
        'chest' => 'Chest',
        'lats' || 'lower_back' || 'middle_back' || 'traps' => 'Back',
        'shoulders' || 'traps' => 'Shoulders',
        'quadriceps' || 'hamstrings' || 'calves' || 'glutes' || 'abductors' || 'adductors' => 'Legs',
        'biceps' || 'triceps' || 'forearms' => 'Arms',
        'abdominals' => 'Core',
        _ => 'Other',
      };

  static String _mapEquipment(String raw) => switch (raw.toLowerCase()) {
        'barbell' => 'Barbell',
        'dumbbell' || 'dumbbells' => 'Dumbbell',
        'cable' => 'Cable',
        'machine' => 'Machine',
        'body only' || 'bodyweight' || '' => 'Bodyweight',
        'bands' || 'band' => 'Bands',
        'kettlebell' || 'kettlebells' => 'Kettlebell',
        'e-z curl bar' => 'EZ Bar',
        'exercise ball' => 'Exercise Ball',
        'foam roll' => 'Foam Roll',
        'medicine ball' => 'Medicine Ball',
        _ => 'Other',
      };
}
