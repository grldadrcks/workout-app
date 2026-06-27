import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/training_program.dart';
import '../models/workout_session.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final hasActive = provider.activeSession != null;
    final isNewUser = provider.sessions.isEmpty &&
        provider.routines.isEmpty &&
        provider.activeProgram == null;
    final isReadyForFirst =
        provider.sessions.isEmpty && !isNewUser && !hasActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forge'),
        actions: [
          if (!isNewUser) ...[
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              onPressed: () => context.push('/badges'),
              tooltip: 'Badges',
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events),
              onPressed: () => context.push('/prs'),
              tooltip: 'PRs',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push('/plate-calc'),
            tooltip: 'Plate Calculator',
          ),
        ],
      ),
      body: isNewUser
          ? _StartHereView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // First-workout ready banner
                if (isReadyForFirst)
                  _ReadyForFirstBanner(provider: provider),

                // Stats + goal ring row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _StatsColumn(
                            provider: provider, settings: settings)),
                    const SizedBox(width: 12),
                    _WeeklyGoalRing(
                        done: provider.thisWeekCount,
                        goal: settings.weeklyGoal),
                  ],
                ),
                const SizedBox(height: 16),

                // Muscle heatmap
                _MuscleHeatmap(hits: provider.weeklyMuscleHits),
                const SizedBox(height: 16),

                // Workout frequency calendar
                _WorkoutCalendar(workoutDays: provider.workoutDays),
                const SizedBox(height: 16),

                // Muscle balance tip
                if (provider.muscleBalanceTip != null)
                  _BalanceTipCard(tip: provider.muscleBalanceTip!),

                // Today's program card
                if (provider.activeProgram != null && !hasActive) ...[
                  const SizedBox(height: 8),
                  _TodaysProgramCard(
                      program: provider.activeProgram!, provider: provider),
                ],

                // Active session banner
                if (hasActive) _ActiveBanner(name: provider.activeSession!.name),

                // Suggested routine
                if (!hasActive && provider.suggestedRoutine != null) ...[
                  const SizedBox(height: 8),
                  _SuggestedRoutine(
                      routine: provider.suggestedRoutine!, provider: provider),
                ],

                // Quick start chips
                if (!hasActive && provider.routines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Quick Start',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.routines.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final r = provider.routines[i];
                        return ActionChip(
                          avatar: const Icon(Icons.play_arrow, size: 18),
                          label: Text(r.name),
                          onPressed: () {
                            provider.startSession(r.name,
                                routineId: r.id, fromRoutine: r.exercises);
                            context.go('/active');
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Text('Recent Workouts',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (provider.sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No workouts yet. Start one!')),
                  )
                else
                  ...provider.sessions
                      .take(5)
                      .map((s) => _SessionTile(session: s, settings: settings)),
              ],
            ),
      floatingActionButton: hasActive
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/active'),
              icon: const Icon(Icons.fitness_center),
              label: const Text('Resume'),
            )
          : isNewUser
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.go('/routines'),
                  icon: const Icon(Icons.add),
                  label: const Text('Start Workout'),
                ),
    );
  }
}

// ── Start Here View ───────────────────────────────────────────────────────

class _StartHereView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fitness_center,
                    size: 26,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Let's get you started",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Pick how you want to train',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Recommended path
          _SectionLabel(
            label: 'Recommended',
            color: Colors.green,
            icon: Icons.recommend,
          ),
          const SizedBox(height: 10),
          _PathCard(
            icon: Icons.auto_graph,
            iconColor: Colors.green,
            title: 'Follow a Program',
            description:
                'Get a step-by-step plan that tells you exactly what to lift each session. '
                'Weights increase automatically — no guesswork.',
            bullets: const [
              'Perfect for beginners',
              'Weights calculated for you',
              'Progress tracked automatically',
            ],
            buttonLabel: 'Browse Programs',
            buttonFilled: true,
            onTap: () => context.push('/programs'),
          ),

          const SizedBox(height: 20),
          _OrDivider(),
          const SizedBox(height: 20),

          // DIY path
          _SectionLabel(label: 'Do it yourself', color: Colors.grey),
          const SizedBox(height: 10),
          _PathCard(
            icon: Icons.edit_note,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Start Your Own Way',
            description:
                'Build a custom routine with the exercises you want, '
                'or jump straight in and log a free workout.',
            bullets: const [],
            buttonLabel: '',
            buttonFilled: false,
            onTap: null,
            customBottom: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/routines'),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Create Routine'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      provider.startSession('Free Workout');
                      context.go('/active');
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Free Workout'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // What to expect footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New to lifting?',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 6),
                Text(
                  'Start with "Full Body Starter" in Programs. '
                  'It\'s 3 sessions a week, uses just a barbell, '
                  'and tells you exactly what to do.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/programs'),
                  child: Text('Go to Programs →',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _SectionLabel({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.8)),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<String> bullets;
  final String buttonLabel;
  final bool buttonFilled;
  final VoidCallback? onTap;
  final Widget? customBottom;

  const _PathCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.bullets,
    required this.buttonLabel,
    required this.buttonFilled,
    required this.onTap,
    this.customBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600)),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: iconColor),
                      const SizedBox(width: 8),
                      Text(b,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                )),
          ],
          if (customBottom != null) ...[
            const SizedBox(height: 14),
            customBottom!,
          ] else if (onTap != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: buttonFilled
                  ? FilledButton(
                      onPressed: onTap,
                      child: Text(buttonLabel))
                  : OutlinedButton(
                      onPressed: onTap,
                      child: Text(buttonLabel)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ready For First Workout Banner ─────────────────────────────────────────

class _ReadyForFirstBanner extends StatelessWidget {
  final WorkoutProvider provider;
  const _ReadyForFirstBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasProgram = provider.activeProgram != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withAlpha(30),
            Theme.of(context).colorScheme.primary.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("You're all set!",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  hasProgram
                      ? 'Your program is loaded. Start your first session.'
                      : 'Your routine is ready. Time for your first workout.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              if (hasProgram) {
                provider.startProgramSession();
              }
              context.go(hasProgram ? '/active' : '/routines');
            },
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10)),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Goal Ring ───────────────────────────────────────────────────────

class _WeeklyGoalRing extends StatelessWidget {
  final int done, goal;
  const _WeeklyGoalRing({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0.0;
    final primary = Theme.of(context).colorScheme.primary;
    final ringColor = progress >= 1.0
        ? const Color(0xFF66BB6A)
        : progress >= 0.5
            ? const Color(0xFFFFA726)
            : primary;

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _RingPainter(progress: progress, color: ringColor)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$done/$goal',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('week', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final radius = (size.width / 2) - 6;
    const strokeW = 8.0;
    final bgPaint = Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Stats Column ───────────────────────────────────────────────────────────

class _StatsColumn extends StatelessWidget {
  final WorkoutProvider provider;
  final SettingsProvider settings;
  const _StatsColumn({required this.provider, required this.settings});

  @override
  Widget build(BuildContext context) {
    final streak = provider.currentStreak;
    final thisWeek = provider.thisWeekVolume;
    final lastWeek = provider.lastWeekVolume;
    final diff = lastWeek > 0 ? ((thisWeek - lastWeek) / lastWeek * 100).round() : null;

    return Column(
      children: [
        _StatCard(
          icon: Icons.local_fire_department,
          iconColor: Colors.orange,
          label: 'Streak',
          value: '$streak day${streak == 1 ? '' : 's'}',
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.bar_chart,
          iconColor: Theme.of(context).colorScheme.primary,
          label: 'This Week',
          value: settings.formatWeight(thisWeek.toDouble()),
          badge: diff != null ? '${diff >= 0 ? '+' : ''}$diff%' : null,
          badgeColor: diff != null && diff >= 0 ? Colors.green : Colors.red,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final String? badge;
  final Color? badgeColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [iconColor.withAlpha(50), iconColor.withAlpha(15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Row(
                    children: [
                      Text(value,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (badge != null) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: badgeColor?.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge!,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Muscle Heatmap ─────────────────────────────────────────────────────────

class _MuscleHeatmap extends StatelessWidget {
  final Map<String, int> hits;
  const _MuscleHeatmap({required this.hits});

  static const _groups = ['Chest', 'Back', 'Shoulders', 'Legs', 'Arms', 'Core', 'Other'];

  static const _muscleColors = {
    'Chest':     Color(0xFFEF5350),
    'Back':      Color(0xFF42A5F5),
    'Shoulders': Color(0xFFAB47BC),
    'Legs':      Color(0xFF66BB6A),
    'Arms':      Color(0xFFFFA726),
    'Core':      Color(0xFF26C6DA),
    'Other':     Color(0xFF78909C),
  };

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Week\'s Coverage',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _groups.map((g) {
            final count = hits[g] ?? 0;
            final color = _muscleColors[g] ?? Colors.grey;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: count == 0
                    ? Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(100)
                    : color.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: count > 0 ? color.withAlpha(180) : Colors.transparent,
                ),
              ),
              child: Text(
                '$g${count > 0 ? ' ×$count' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: count > 0 ? color : Colors.grey,
                  fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Workout Calendar ───────────────────────────────────────────────────────

class _WorkoutCalendar extends StatelessWidget {
  final Set<DateTime> workoutDays;
  const _WorkoutCalendar({required this.workoutDays});

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weeks = 14;
  static const _cellSize = 16.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    if (workoutDays.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOfWeek = today.weekday;
    final latestMonday = today.subtract(Duration(days: dayOfWeek - 1));
    final primary = Theme.of(context).colorScheme.primary;
    final surface =
        Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day-of-week labels
            Column(
              children: _dayLabels
                  .map((label) => SizedBox(
                        width: 12,
                        height: _cellSize + _gap,
                        child: Center(
                          child: Text(label,
                              style: const TextStyle(
                                  fontSize: 8, color: Colors.grey)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(width: 4),
            // Grid of weeks
            Wrap(
              spacing: _gap,
              children: List.generate(_weeks, (wi) {
                final weekStart = latestMonday
                    .subtract(Duration(days: 7 * (_weeks - 1 - wi)));
                return Column(
                  children: List.generate(7, (di) {
                    final date = weekStart.add(Duration(days: di));
                    final hasWorkout = workoutDays.contains(date);
                    final isFuture = date.isAfter(today);
                    return Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(bottom: _gap),
                      decoration: BoxDecoration(
                        color: isFuture
                            ? Colors.transparent
                            : hasWorkout
                                ? primary.withAlpha(200)
                                : surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Balance Tip Card ───────────────────────────────────────────────────────

class _BalanceTipCard extends StatelessWidget {
  final ({String message, Color color}) tip;
  const _BalanceTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tip.color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tip.color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.balance, size: 18, color: tip.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip.message,
              style: TextStyle(
                  fontSize: 13, color: tip.color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today's Program Card ───────────────────────────────────────────────────

class _TodaysProgramCard extends StatelessWidget {
  final ActiveProgram program;
  final WorkoutProvider provider;
  const _TodaysProgramCard({required this.program, required this.provider});

  @override
  Widget build(BuildContext context) {
    final def = program.definition;
    final dayIdx = program.currentDayIndex % def.dayNames.length;
    final dayName = def.dayNames[dayIdx];

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.auto_graph),
        title: Text('${def.shortName}: $dayName',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Week ${program.currentWeek} · ${program.sessionsCompleted} sessions done'),
        trailing: FilledButton.tonal(
          onPressed: () {
            provider.startProgramSession();
            context.go('/active');
          },
          child: const Text('Start'),
        ),
      ),
    );
  }
}

// ── Active Banner ──────────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  final String name;
  const _ActiveBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text('Active: $name'),
        subtitle: const Text('Tap Resume to continue'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.go('/active'),
      ),
    );
  }
}

class _SuggestedRoutine extends StatelessWidget {
  final dynamic routine;
  final WorkoutProvider provider;
  const _SuggestedRoutine({required this.routine, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.lightbulb_outline),
        title: Text('Suggested: ${routine.name}'),
        subtitle: Text('${routine.exercises.length} exercises'),
        trailing: FilledButton.tonal(
          onPressed: () {
            provider.startSession(routine.name,
                routineId: routine.id, fromRoutine: routine.exercises);
            context.go('/active');
          },
          child: const Text('Start'),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final WorkoutSession session;
  final SettingsProvider settings;
  const _SessionTile({required this.session, required this.settings});

  @override
  Widget build(BuildContext context) {
    final duration = session.endTime?.difference(session.startTime);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(session.name),
      subtitle: Text(
        '${_formatDate(session.startTime)}'
        '${duration != null ? ' · ${duration.inMinutes}m' : ''}',
      ),
      trailing: Text(settings.formatWeight(session.totalVolume.toDouble()),
          style: Theme.of(context).textTheme.bodySmall),
      onTap: () => context.go('/history'),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
