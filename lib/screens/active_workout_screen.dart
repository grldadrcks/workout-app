import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../utils/muscle_colors.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final Timer _timer;
  int _elapsed = 0;
  int? _restSeconds;
  int _restTotal = 90;
  Timer? _restTimer;
  bool _restOverlay = false;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));
  }

  @override
  void dispose() {
    _timer.cancel();
    _restTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restSeconds = seconds;
      _restTotal = seconds;
      _restOverlay = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_restSeconds! > 0) {
          _restSeconds = _restSeconds! - 1;
        } else {
          _restTimer?.cancel();
          HapticFeedback.heavyImpact();
          _player.play(AssetSource('audio/beep.wav'));
          _restOverlay = false;
          _restSeconds = null;
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() { _restOverlay = false; _restSeconds = null; });
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final session = provider.activeSession;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmFinish(context, provider);
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.name, style: const TextStyle(fontSize: 16)),
                  Text(_fmt(_elapsed),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: () => context.push('/plate-calc'),
                  tooltip: 'Plate Calculator',
                ),
                TextButton(
                  onPressed: () => _confirmFinish(context, provider),
                  child: const Text('Finish'),
                ),
              ],
            ),
            body: ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: session.exercises.length,
              itemBuilder: (context, i) {
                final se = session.exercises[i];
                final isLastEx = i == session.exercises.length - 1;
                return _ExerciseCard(
                  key: ValueKey(se.id),
                  se: se,
                  provider: provider,
                  onRestStart: _startRest,
                  showSupersetToggle: !isLastEx,
                );
              },
              onReorder: (oldIndex, newIndex) =>
                  provider.reorderExercises(oldIndex, newIndex),
              footer: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddExercise(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Exercise'),
                ),
              ),
            ),
          ),
          if (_restOverlay && _restSeconds != null)
            _RestOverlay(
              seconds: _restSeconds!,
              total: _restTotal,
              onSkip: _skipRest,
              fmt: _fmt,
            ),
        ],
      ),
    );
  }

  void _showAddExercise(BuildContext context, WorkoutProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _AddExerciseSheet(
        exercises: provider.exercises,
        onPick: (e) {
          provider.addExerciseToSession(e);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  void _confirmFinish(BuildContext context, WorkoutProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text('This will save your session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final session = await provider.finishSession();
              if (context.mounted) context.go('/complete', extra: session);
            },
            child: const Text('Finish'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.cancelSession();
              context.go('/');
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Rest Overlay ───────────────────────────────────────────────────────────

class _RestOverlay extends StatelessWidget {
  final int seconds, total;
  final VoidCallback onSkip;
  final String Function(int) fmt;
  const _RestOverlay({required this.seconds, required this.total, required this.onSkip, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? seconds / total : 0.0;
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rest', style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 24),
            SizedBox(
              width: 180, height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.white12,
                    color: seconds <= 10 ? Colors.orange : Colors.teal,
                  ),
                  Center(
                    child: Text(fmt(seconds),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 16),
                FilledButton(onPressed: onSkip, child: const Text('Done')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise Card ──────────────────────────────────────────────────────────

class _ExerciseCard extends StatefulWidget {
  final SessionExercise se;
  final WorkoutProvider provider;
  final ValueChanged<int> onRestStart;
  final bool showSupersetToggle;

  const _ExerciseCard({
    super.key,
    required this.se,
    required this.provider,
    required this.onRestStart,
    required this.showSupersetToggle,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _showNotes = false;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.se.notes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showFormCues(BuildContext context, String exerciseId, String exerciseName, WorkoutProvider provider) {
    final ex = provider.exercises.where((e) => e.id == exerciseId).isNotEmpty
        ? provider.exercises.firstWhere((e) => e.id == exerciseId)
        : null;
    final instructions = ex?.instructions.join('\n\n') ?? '';
    final level = ex?.level ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(exerciseName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  if (level.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(level,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (instructions.isNotEmpty) ...[
                Text('Form Cues', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(instructions, style: Theme.of(context).textTheme.bodyMedium),
              ] else
                Text(
                  'No form cues available for this exercise.\n\nFocus on controlled movement and full range of motion.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _pickRestDuration(BuildContext context) {
    const options = [30, 60, 90, 120, 180, 240];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Rest Duration', style: Theme.of(context).textTheme.titleMedium),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: options.map((s) {
                final label = s < 60 ? '${s}s' : '${s ~/ 60}m${s % 60 > 0 ? ' ${s % 60}s' : ''}';
                final selected = widget.se.restSeconds == s;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    widget.provider.updateExerciseRestSeconds(widget.se.id, s);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final se = widget.se;
    final provider = widget.provider;
    final completed = se.sets.where((s) => s.isCompleted).length;
    final total = se.sets.length;
    final est1rm = provider.bestEstimated1RM(se.exerciseId);
    final settings = context.watch<SettingsProvider>();
    final restLabel = se.restSeconds < 60
        ? '${se.restSeconds}s'
        : '${se.restSeconds ~/ 60}m${se.restSeconds % 60 > 0 ? ' ${se.restSeconds % 60}s' : ''}';
    final ex = provider.exercises.where((e) => e.id == se.exerciseId).firstOrNull;
    final exColor = muscleColor(ex?.muscleGroup ?? 'Other');

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [exColor, exColor.withAlpha(140)],
                  ),
                ),
              ),
              Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _showFormCues(context, se.exerciseId, se.exerciseName, provider),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(se.exerciseName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 4),
                                Icon(Icons.info_outline, size: 14,
                                    color: Theme.of(context).colorScheme.primary.withAlpha(150)),
                              ],
                            ),
                          ),
                          if (settings.beginnerMode)
                            GestureDetector(
                              onTap: () => _showFormCues(context, se.exerciseId, se.exerciseName, provider),
                              child: Text(
                                'How to do this exercise →',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            )
                          else if (est1rm > 0)
                            Text(
                              '1RM est. ${settings.formatWeight(est1rm)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    // Rest timer chip
                    GestureDetector(
                      onTap: () => _pickRestDuration(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 13,
                                color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 3),
                            Text(restLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.note_alt_outlined, size: 18),
                      tooltip: 'Notes',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => setState(() => _showNotes = !_showNotes),
                      color: se.notes.isNotEmpty
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flash_on_outlined, size: 18),
                      tooltip: 'Add warm-up sets',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => provider.addWarmupSets(se.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => provider.removeSetFromExercise(se.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => provider.addSetToExercise(se.id),
                    ),
                  ],
                ),

                // Smart progression suggestion
                Builder(builder: (context) {
                  final targetReps = se.sets.isNotEmpty ? se.sets.first.reps : 8;
                  final suggestion = provider.getProgressionSuggestion(se.exerciseId, targetReps: targetReps);
                  if (suggestion == null) return const SizedBox.shrink();
                  final level = suggestion['level'] as String;
                  final Color bg;
                  final Color fg;
                  final IconData icon;
                  switch (level) {
                    case 'increase':
                      bg = Colors.green.withAlpha(30); fg = Colors.green; icon = Icons.trending_up;
                    case 'deload':
                      bg = Colors.red.withAlpha(30); fg = Colors.red; icon = Icons.trending_down;
                    default:
                      bg = Colors.orange.withAlpha(30); fg = Colors.orange; icon = Icons.remove;
                  }
                  return Container(
                    margin: const EdgeInsets.only(top: 6, bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: fg.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 14, color: fg),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            suggestion['note'] as String,
                            style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (level == 'increase')
                          Text(
                            settings.formatWeight(suggestion['weight'] as double),
                            style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  );
                }),

                // Notes field
                if (_showNotes) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Exercise notes...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (v) => provider.updateExerciseNotes(se.id, v),
                  ),
                ],

                // Progress bar
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: total > 0 ? completed / total : 0,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$completed/$total',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),

                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 32,
                          child: Text('Set', style: TextStyle(fontSize: 12, color: Colors.grey))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(settings.unitLabel,
                              style: const TextStyle(fontSize: 12, color: Colors.grey))),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Reps',
                              style: TextStyle(fontSize: 12, color: Colors.grey))),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Set rows
                ...se.sets.asMap().entries.map((entry) => _SetRow(
                      set: entry.value,
                      allSets: se.sets,
                      setIndex: entry.key,
                      provider: provider,
                      onComplete: () => widget.onRestStart(se.restSeconds),
                    )),
              ],
            ),
          ),
            ],
          ),
        ),

        // Superset connector
        if (widget.showSupersetToggle)
          _SupersetConnector(
            active: se.supersetWithNext,
            onToggle: () => provider.toggleSuperset(se.id),
          ),
      ],
    );
  }
}

// ── Superset Connector ─────────────────────────────────────────────────────

class _SupersetConnector extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;
  const _SupersetConnector({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary.withAlpha(20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: active
                ? Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(80))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link,
                  size: 14,
                  color: active ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(width: 4),
              Text(
                active ? 'SUPERSET' : 'Link as superset',
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Theme.of(context).colorScheme.primary : Colors.grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Set Row ────────────────────────────────────────────────────────────────

class _SetRow extends StatefulWidget {
  final SetLog set;
  final List<SetLog> allSets;
  final int setIndex;
  final WorkoutProvider provider;
  final VoidCallback onComplete;

  const _SetRow({
    required this.set,
    required this.allSets,
    required this.setIndex,
    required this.provider,
    required this.onComplete,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> with SingleTickerProviderStateMixin {
  late double _weight;
  late int _reps;
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _weight = settings.toDisplay(widget.set.weight);
    _reps = widget.set.reps;
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.97), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_SetRow old) {
    super.didUpdateWidget(old);
    if (widget.set.isCompleted && !old.set.isCompleted) {
      _bounceCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _setWeight(double w) {
    setState(() => _weight = w);
    widget.provider.updateSet(widget.set.id, weight: context.read<SettingsProvider>().toKg(w));
  }

  void _setReps(int r) {
    setState(() => _reps = r);
    widget.provider.updateSet(widget.set.id, reps: r);
  }

  void _copyFromPrev() {
    if (widget.setIndex == 0) return;
    final prev = widget.allSets[widget.setIndex - 1];
    final settings = context.read<SettingsProvider>();
    setState(() {
      _weight = settings.toDisplay(prev.weight);
      _reps = prev.reps;
    });
    widget.provider.updateSet(widget.set.id, weight: prev.weight, reps: prev.reps);
    HapticFeedback.selectionClick();
  }

  void _pickRpe(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Rate of Perceived Exertion',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      widget.provider.updateSet(widget.set.id, rpe: 0);
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      children: List.generate(10, (i) {
                        final val = i + 1;
                        final selected = widget.set.rpe == val;
                        return GestureDetector(
                          onTap: () {
                            widget.provider.updateSet(widget.set.id, rpe: val);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('$val',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selected ? Colors.white : null)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.set.isCompleted;
    final weightStep =
        context.read<SettingsProvider>().weightUnit == WeightUnit.lbs ? 2.5 : 1.25;
    final set = widget.set;

    return ScaleTransition(
      scale: _bounceAnim,
      child: GestureDetector(
      onLongPress: widget.setIndex > 0 && !completed ? _copyFromPrev : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: completed
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
            : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: completed
                            ? LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        border: completed
                            ? null
                            : Border.all(
                                color: Colors.grey.withAlpha(100),
                                width: 1.5,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          '${set.setNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: completed ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stepper(
                      value: _weight,
                      step: weightStep,
                      min: 0,
                      enabled: !completed,
                      onChanged: _setWeight,
                      format: (v) =>
                          v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stepper(
                      value: _reps.toDouble(),
                      step: 1,
                      min: 1,
                      enabled: !completed,
                      onChanged: (v) => _setReps(v.toInt()),
                      format: (v) => v.toInt().toString(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: completed,
                      onChanged: (v) {
                        HapticFeedback.mediumImpact();
                        widget.provider.updateSet(set.id, isCompleted: v ?? false);
                        if (v == true) widget.onComplete();
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Tags row for completed sets (hidden in beginner mode)
            if (completed && !context.watch<SettingsProvider>().beginnerMode)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 8),
                child: Row(
                  children: [
                    _TagChip(
                      label: set.rpe > 0 ? 'RPE ${set.rpe}' : 'RPE',
                      active: set.rpe > 0,
                      onTap: () => _pickRpe(context),
                    ),
                    const SizedBox(width: 6),
                    _TagChip(
                      label: 'Dropset',
                      active: set.isDropset,
                      onTap: () => widget.provider
                          .updateSet(set.id, isDropset: !set.isDropset),
                    ),
                    const SizedBox(width: 6),
                    _TagChip(
                      label: 'To Failure',
                      active: set.toFailure,
                      onTap: () => widget.provider
                          .updateSet(set.id, toFailure: !set.toFailure),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TagChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? primary.withAlpha(120) : Colors.grey.withAlpha(80)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 10,
              color: active ? primary : Colors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}

// ── Stepper widget ─────────────────────────────────────────────────────────

class _Stepper extends StatefulWidget {
  final double value, step, min;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final String Function(double) format;

  const _Stepper({
    super.key,
    required this.value,
    required this.step,
    required this.min,
    required this.enabled,
    required this.onChanged,
    required this.format,
  });

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.format(widget.value));
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) {
      _ctrl.text = widget.format(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = double.tryParse(_ctrl.text);
    if (parsed != null && parsed >= widget.min) {
      widget.onChanged(parsed);
    } else {
      _ctrl.text = widget.format(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _StepBtn(
            icon: Icons.remove,
            enabled: widget.enabled && widget.value > widget.min,
            onTap: () => widget.onChanged((widget.value - widget.step).clamp(widget.min, double.infinity)),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: widget.enabled ? null : Colors.grey,
              ),
              onTap: () => _ctrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _ctrl.text.length,
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: widget.enabled,
            onTap: () => widget.onChanged(widget.value + widget.step),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 16,
            color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
      ),
    );
  }
}

// ── Add Exercise Sheet ─────────────────────────────────────────────────────

class _AddExerciseSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onPick;

  const _AddExerciseSheet({required this.exercises, required this.onPick});

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.exercises
        : widget.exercises
            .where((e) => e.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final e = filtered[i];
                final color = muscleColor(e.muscleGroup);
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fitness_center, size: 16, color: color),
                  ),
                  title: Text(e.name),
                  subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
                  onTap: () => widget.onPick(e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
