import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final earned = provider.earnedBadges.map((b) => b.id).toSet();
    final progress = WorkoutProvider.allBadges.isEmpty
        ? 0.0
        : earned.length / WorkoutProvider.allBadges.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${earned.length}/${WorkoutProvider.allBadges.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFEF5350),
                            Color(0xFFFFA726),
                            Color(0xFFFFEE58),
                            Color(0xFF66BB6A),
                            Color(0xFF42A5F5),
                            Color(0xFFAB47BC),
                          ]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${earned.length} earned',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('${WorkoutProvider.allBadges.length - earned.length} remaining',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: WorkoutProvider.allBadges.length,
              itemBuilder: (context, i) {
                final badge = WorkoutProvider.allBadges[i];
                final isEarned = earned.contains(badge.id);
                return _BadgeTile(badge: badge, isEarned: isEarned);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AppBadge badge;
  final bool isEarned;
  const _BadgeTile({required this.badge, required this.isEarned});

  static const _gradients = <String, List<Color>>{
    'first_workout': [Color(0xFF43A047), Color(0xFF1DE9B6)],
    'workouts_7':    [Color(0xFF1E88E5), Color(0xFF42A5F5)],
    'workouts_30':   [Color(0xFF3949AB), Color(0xFF7E57C2)],
    'workouts_100':  [Color(0xFF6A1B9A), Color(0xFFCE93D8)],
    'streak_7':      [Color(0xFFFB8C00), Color(0xFFFFCC02)],
    'streak_14':     [Color(0xFFF4511E), Color(0xFFFF8A65)],
    'volume_10k':    [Color(0xFFE53935), Color(0xFFFF7043)],
    'volume_100k':   [Color(0xFFB71C1C), Color(0xFFFF5252)],
    'first_pr':      [Color(0xFFFFB300), Color(0xFFFFE082)],
    'exercises_10':  [Color(0xFF00ACC1), Color(0xFF80DEEA)],
    'early_bird':    [Color(0xFFF57F17), Color(0xFFFFCA28)],
    'night_owl':     [Color(0xFF4A148C), Color(0xFFBA68C8)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[badge.id];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: isEarned && colors != null
            ? LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(colors: [
                isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE),
                isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
              ]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEarned && colors != null
            ? [
                BoxShadow(
                  color: colors[0].withAlpha(100),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      badge.emoji,
                      style: TextStyle(
                        fontSize: 36,
                        color: isEarned ? null : Colors.transparent,
                      ),
                    ),
                    if (!isEarned)
                      const Text('🔒',
                          style: TextStyle(fontSize: 28, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  badge.title,
                  style: TextStyle(
                    color: isEarned ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: isEarned
                        ? [const Shadow(blurRadius: 4, color: Colors.black26)]
                        : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final colors = _gradients[badge.id];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Text(badge.title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEarned && colors != null)
              Container(
                width: 56,
                height: 6,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            Text(badge.description),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}
