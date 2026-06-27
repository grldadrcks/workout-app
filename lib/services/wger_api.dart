import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';

class WgerApi {
  static const _baseUrl = 'https://wger.de/api/v2/exerciseinfo/';

  static Future<List<Exercise>> search({String? name, int offset = 0}) async {
    final params = <String, String>{
      'format': 'json',
      'language': '2',
      'limit': '20',
      'offset': offset.toString(),
    };
    if (name != null && name.isNotEmpty) params['name'] = name;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode != 200) throw Exception('wger API error ${response.statusCode}');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List).cast<Map<String, dynamic>>();
    return results.map(_fromWgerJson).toList();
  }

  static Exercise _fromWgerJson(Map<String, dynamic> j) {
    // Resolve English name and description from translations (language id == 2)
    final translations = (j['translations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final englishTx = translations.firstWhere(
      (t) => (t['language'] as Map<String, dynamic>?)?['id'] == 2,
      orElse: () => translations.isNotEmpty ? translations.first : <String, dynamic>{},
    );

    final exerciseName = (englishTx['name'] as String?)?.trim();
    final rawDescription = (englishTx['description'] as String?) ?? '';

    // Strip HTML tags from description
    final cleanDescription = rawDescription
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Split description into sentences as instruction steps
    final instructions = cleanDescription.isEmpty
        ? <String>[]
        : cleanDescription
            .split(RegExp(r'(?<=[.!?])\s+'))
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();

    // Resolve muscle group from first muscle entry
    final muscles = (j['muscles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final primaryMuscle = muscles.isNotEmpty
        ? (muscles.first['name_en'] as String? ?? '')
        : '';

    // Resolve equipment from first equipment entry
    final equipmentList = (j['equipment'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final equipmentName = equipmentList.isNotEmpty
        ? (equipmentList.first['name'] as String? ?? '')
        : '';

    return Exercise(
      id: 'wger_${j['id']}',
      name: exerciseName ?? 'Unknown Exercise',
      muscleGroup: _mapMuscle(primaryMuscle),
      equipment: _mapEquipment(equipmentName),
      level: '',
      instructions: instructions,
      isCustom: false,
    );
  }

  static String _mapMuscle(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('chest') || lower.contains('pectoral')) return 'Chest';
    if (lower.contains('lat') || lower.contains('back') || lower.contains('rhomboid') ||
        lower.contains('trapezius') || lower.contains('teres')) return 'Back';
    if (lower.contains('delt') || lower.contains('shoulder')) return 'Shoulders';
    if (lower.contains('quad') || lower.contains('hamstring') || lower.contains('calf') ||
        lower.contains('calves') || lower.contains('glute') || lower.contains('adductor') ||
        lower.contains('abductor') || lower.contains('gastrocnemius') ||
        lower.contains('soleus')) return 'Legs';
    if (lower.contains('bicep') || lower.contains('tricep') || lower.contains('forearm') ||
        lower.contains('brachialis') || lower.contains('brachioradialis')) return 'Arms';
    if (lower.contains('ab') || lower.contains('core') || lower.contains('oblique') ||
        lower.contains('rectus') || lower.contains('transverse')) return 'Core';
    if (raw.isEmpty) return 'Other';
    return 'Other';
  }

  static String _mapEquipment(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('barbell')) return 'Barbell';
    if (lower.contains('dumbbell')) return 'Dumbbell';
    if (lower.contains('cable')) return 'Cable';
    if (lower.contains('machine')) return 'Machine';
    if (lower.contains('body weight') || lower.contains('bodyweight') || raw.isEmpty) {
      return 'Bodyweight';
    }
    if (lower.contains('band') || lower.contains('resistance band')) return 'Bands';
    if (lower.contains('kettlebell')) return 'Kettlebell';
    return 'Other';
  }
}
