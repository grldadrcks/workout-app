import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/training_program.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final active = provider.activeProgram;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Programs'),
        leading: context.canPop()
            ? null
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Home',
                onPressed: () => context.go('/'),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active != null) ...[
            _ActiveProgramCard(program: active, provider: provider),
            const SizedBox(height: 20),
            Text('Available Programs',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
          ] else ...[
            _IntroCard(),
            const SizedBox(height: 20),
          ],
          ...programDefinitions.map((def) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active == null && def.difficulty == 'Beginner')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withAlpha(100)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.recommend,
                                      color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text('Recommended for beginners',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    _ProgramCard(
                      def: def,
                      isActive: active?.type == def.type,
                      onStart: active == null
                          ? () => _showSetupDialog(context, provider, def)
                          : null,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showSetupDialog(
      BuildContext context, WorkoutProvider provider, ProgramDefinition def) {
    showDialog(
      context: context,
      builder: (_) => _SetupDialog(def: def, provider: provider),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_graph,
              size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Structured Programs',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Pick a proven program and let Forge calculate your weights automatically every session.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveProgramCard extends StatelessWidget {
  final ActiveProgram program;
  final WorkoutProvider provider;
  const _ActiveProgramCard({required this.program, required this.provider});

  @override
  Widget build(BuildContext context) {
    final def = program.definition;
    final dayIdx = program.currentDayIndex % def.dayNames.length;
    final dayName = def.dayNames[dayIdx];

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('ACTIVE',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(def.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Week ${program.currentWeek} · $dayName',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)),
            Text('${program.sessionsCompleted} sessions completed',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      provider.startProgramSession();
                      context.go('/active');
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Start $dayName'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _confirmCancel(context, provider),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WorkoutProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Program?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.cancelProgram();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Program'),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final ProgramDefinition def;
  final bool isActive;
  final VoidCallback? onStart;
  const _ProgramCard({required this.def, required this.isActive, this.onStart});

  Color _difficultyColor(BuildContext context) => switch (def.difficulty) {
        'Beginner' => Colors.green,
        'Intermediate' => Colors.orange,
        _ => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(def.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: diffColor.withAlpha(100)),
                  ),
                  child: Text(def.difficulty,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: diffColor,
                          fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(def.shortName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(def.description,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(def.details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: def.dayNames
                  .map((d) => Chip(
                        label: Text(d, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            if (onStart != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onStart,
                  child: Text(def.difficulty == 'Beginner'
                      ? 'Start Here — It\'s Free'
                      : 'Start Program'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Setup Dialog ───────────────────────────────────────────────────────────

class _SetupDialog extends StatefulWidget {
  final ProgramDefinition def;
  final WorkoutProvider provider;
  const _SetupDialog({required this.def, required this.provider});

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {for (final k in widget.def.liftKeys) k: TextEditingController()};
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _start() {
    final maxes = <String, double>{};
    for (final k in widget.def.liftKeys) {
      final val = double.tryParse(_ctrls[k]!.text);
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter all weights')),
        );
        return;
      }
      maxes[k] = val;
    }
    widget.provider.startProgram(widget.def.type, maxes);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.def.name} started!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    return AlertDialog(
      title: Text('Set Up ${widget.def.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.def.difficulty == 'Beginner'
                  ? 'Enter a weight you can lift for 8 comfortable reps (${settings.unitLabel}). Start light — you can always increase later:'
                  : widget.def.type == ProgramType.fiveThreeOne
                      ? 'Enter your training maxes (≈90% of your 1RM) in ${settings.unitLabel}:'
                      : 'Enter your current working weights (${settings.unitLabel}):',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            ...widget.def.liftKeys.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _ctrls[e.value],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: widget.def.liftLabels[e.key],
                      suffixText: settings.unitLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _start, child: const Text('Start')),
      ],
    );
  }
}
