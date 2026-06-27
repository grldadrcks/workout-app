import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout_session.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  final WorkoutSession session;
  const WorkoutCompleteScreen({super.key, required this.session});

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  late final ConfettiController _confetti;
  final _shareKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _shareCard(SettingsProvider settings) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/motagym_workout.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Workout logged with Forge 💪',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _saveAsRoutine(BuildContext context, WorkoutProvider provider) {
    final ctrl = TextEditingController(text: widget.session.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Routine'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Routine name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await provider.saveSessionAsRoutine(widget.session, name);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved "$name" as a routine')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<WorkoutProvider>();
    final session = widget.session;
    final duration = session.endTime?.difference(session.startTime);
    final prs = provider.lastSessionPRs;
    final totalSets = session.exercises
        .fold(0, (s, e) => s + e.sets.where((set) => set.isCompleted).length);

    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 60,
              gravity: 0.18,
              colors: const [
                Colors.deepOrange, Colors.orange, Colors.amber,
                Colors.green, Colors.blue, Colors.purple,
                Colors.pink, Colors.cyan, Colors.white,
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, v, _) => Transform.scale(
                      scale: v,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.amber, Colors.orange, Colors.deepOrange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Icon(Icons.emoji_events,
                            size: 88, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - v)),
                        child: child,
                      ),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                          Colors.amber,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'Workout Complete!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (context, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: Text(
                      session.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Shareable card
                  RepaintBoundary(
                    key: _shareKey,
                    child: _ShareCard(
                      session: session,
                      settings: settings,
                      prs: prs,
                      duration: duration,
                      totalSets: totalSets,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _saveAsRoutine(context, provider),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save as Routine'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _sharing ? null : () => _shareCard(settings),
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share),
                    label: const Text('Share Workout'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home),
                    label: const Text('Back to Home'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _confetti.play(),
                    icon: const Icon(Icons.celebration),
                    label: const Text('Celebrate Again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final WorkoutSession session;
  final SettingsProvider settings;
  final Map<String, double> prs;
  final Duration? duration;
  final int totalSets;

  const _ShareCard({
    required this.session,
    required this.settings,
    required this.prs,
    required this.duration,
    required this.totalSets,
  });

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final completedExercises =
        session.exercises.where((e) => e.sets.any((s) => s.isCompleted)).toList();
    final totalVolume = session.exercises.fold<double>(
      0,
      (sum, e) => sum +
          e.sets
              .where((s) => s.isCompleted)
              .fold<double>(0, (s2, set) => s2 + set.weight * set.reps),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center,
                    color: Colors.deepOrange, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatDate(session.startTime),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (prs.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${prs.length} PR${prs.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CardStat(
                  icon: Icons.timer_outlined,
                  value: duration != null ? _fmtDuration(duration!) : '--',
                  label: 'Duration',
                ),
                _vDivider(),
                _CardStat(
                  icon: Icons.fitness_center,
                  value: '${completedExercises.length}',
                  label: 'Exercises',
                ),
                _vDivider(),
                _CardStat(
                  icon: Icons.repeat,
                  value: '$totalSets',
                  label: 'Sets',
                ),
                _vDivider(),
                _CardStat(
                  icon: Icons.monitor_weight_outlined,
                  value: totalVolume >= 1000
                      ? '${(totalVolume / 1000).toStringAsFixed(1)}k'
                      : totalVolume.toStringAsFixed(0),
                  label: settings.unitLabel,
                ),
              ],
            ),
          ),
          // PR highlights
          if (prs.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Personal Records',
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            ...prs.entries.take(3).map((entry) {
              final ex = session.exercises
                  .firstWhere((e) => e.exerciseId == entry.key,
                      orElse: () => session.exercises.first);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ex.exerciseName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value.toStringAsFixed(entry.value % 1 == 0 ? 0 : 1)} ${settings.unitLabel}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
          // Exercise list (compact)
          if (completedExercises.isNotEmpty && prs.isEmpty) ...[
            const SizedBox(height: 14),
            ...completedExercises.take(4).map((e) {
              final doneSets = e.sets.where((s) => s.isCompleted).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(e.exerciseName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('$doneSets sets',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              );
            }),
            if (completedExercises.length > 4)
              Text(
                '+${completedExercises.length - 4} more',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
          const SizedBox(height: 14),
          // Footer
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.deepOrange, size: 14),
              SizedBox(width: 4),
              Text(
                'Forge',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 36, color: Colors.white.withOpacity(0.1));

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _CardStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _CardStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
