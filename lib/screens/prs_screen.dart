import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../utils/muscle_colors.dart';

class PrsScreen extends StatelessWidget {
  const PrsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final prs = provider.allTimePRs;

    final sorted = prs.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final exercises = provider.exercises;

    return Scaffold(
      appBar: AppBar(title: const Text('All-Time PRs')),
      body: sorted.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Complete workouts to track your PRs',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final pr = sorted[i];
                final name = pr['name'] as String;
                final weightKg = pr['weight'] as double;
                final reps = pr['reps'] as int;
                final date = pr['date'] as DateTime;
                final e1rm = pr['e1rm'] as double;
                final diff = DateTime.now().difference(date).inDays;
                final dateStr = diff == 0
                    ? 'Today'
                    : diff == 1
                        ? 'Yesterday'
                        : '${date.day}/${date.month}/${date.year}';
                final group = muscleGroupForName(name, exercises);
                final color = muscleColor(group);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                '${settings.formatWeight(weightKg)} × $reps reps',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Est. 1RM: ${settings.formatWeight(e1rm)}  ·  $dateStr',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
