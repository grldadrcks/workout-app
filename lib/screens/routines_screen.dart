import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../providers/workout_provider.dart';
import '../utils/muscle_colors.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: ListView(
        children: [
          // Training Programs banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: InkWell(
              onTap: () => context.push('/programs'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_graph,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Training Programs',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text('5/3/1 · Starting Strength · PPL',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Templates section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('Templates', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: WorkoutProvider.templateNames.map((name) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(name),
                  onPressed: () async {
                    await provider.seedTemplate(name);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name routine created')),
                      );
                    }
                  },
                ),
              )).toList(),
            ),
          ),
          const Divider(height: 24),
          if (provider.routines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No routines yet. Create one or use a template!')),
            )
          else
            ...List.generate(provider.routines.length, (i) {
                final r = provider.routines[i];
                return Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Routine?'),
                        content: Text('Delete "${r.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    ) ?? false;
                  },
                  onDismissed: (_) => provider.deleteRoutine(r.id),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(r.name),
                      subtitle: Text('${r.exercises.length} exercises'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditor(context, routine: r),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              provider.startSession(r.name,
                                  routineId: r.id, fromRoutine: r.exercises);
                              context.go('/active');
                            },
                            child: const Text('Start'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openEditor(BuildContext context, {Routine? routine}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(existing: routine)),
    );
  }
}

class RoutineEditorScreen extends StatefulWidget {
  final Routine? existing;
  const RoutineEditorScreen({super.key, this.existing});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final TextEditingController _nameCtrl;
  late List<RoutineExercise> _exercises;
  late String _routineId;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _routineId = widget.existing?.id ?? _uuid.v4();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _exercises = List.from(widget.existing?.exercises ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Routine' : 'Edit Routine'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Routine Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _exercises.removeAt(oldIndex);
                  _exercises.insert(newIndex, item);
                });
              },
              itemCount: _exercises.length,
              itemBuilder: (context, i) {
                final re = _exercises[i];
                return _RoutineExerciseTile(
                  key: ValueKey(re.id),
                  re: re,
                  onChanged: (updated) => setState(() => _exercises[i] = updated),
                  onDelete: () => setState(() => _exercises.removeAt(i)),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPickExercise(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showPickExercise(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    showModalBottomSheet(
      context: context,
      builder: (_) => _ExercisePicker(
        exercises: provider.exercises,
        onPick: (e) {
          setState(() {
            _exercises.add(RoutineExercise(
              id: _uuid.v4(),
              routineId: _routineId,
              exerciseId: e.id,
              exerciseName: e.name,
              targetSets: 3,
              targetReps: 10,
              orderIndex: _exercises.length,
            ));
          });
        },
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final routine = Routine(
      id: _routineId,
      name: _nameCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      exercises: _exercises.asMap().entries.map((e) {
        return RoutineExercise(
          id: e.value.id,
          routineId: _routineId,
          exerciseId: e.value.exerciseId,
          exerciseName: e.value.exerciseName,
          targetSets: e.value.targetSets,
          targetReps: e.value.targetReps,
          targetWeight: e.value.targetWeight,
          orderIndex: e.key,
        );
      }).toList(),
    );
    context.read<WorkoutProvider>().saveRoutine(routine);
    Navigator.pop(context);
  }
}

class _RoutineExerciseTile extends StatelessWidget {
  final RoutineExercise re;
  final ValueChanged<RoutineExercise> onChanged;
  final VoidCallback onDelete;

  const _RoutineExerciseTile({
    super.key,
    required this.re,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = context.read<WorkoutProvider>().exercises;
    final group = muscleGroupForId(re.exerciseId, exercises);
    final color = muscleColor(group);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(re.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete),
                const Icon(Icons.drag_handle),
              ],
            ),
            Row(
              children: [
                _NumField(
                  label: 'Sets',
                  value: re.targetSets,
                  onChanged: (v) => onChanged(re.copyWith(targetSets: v)),
                ),
                const SizedBox(width: 12),
                _NumField(
                  label: 'Reps',
                  value: re.targetReps,
                  onChanged: (v) => onChanged(re.copyWith(targetReps: v)),
                ),
                const SizedBox(width: 12),
                _WeightField(
                  value: re.targetWeight,
                  onChanged: (v) => onChanged(re.copyWith(targetWeight: v)),
                ),
              ],
            ),
          ],
        ),
      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: '),
        IconButton(
          icon: const Icon(Icons.remove, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value'),
        IconButton(
          icon: const Icon(Icons.add, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _WeightField extends StatelessWidget {
  final double? value;
  final ValueChanged<double> onChanged;

  const _WeightField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: value != null && value! > 0 ? value.toString() : '',
        decoration: const InputDecoration(
          labelText: 'kg',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final d = double.tryParse(v);
          if (d != null) onChanged(d);
        },
      ),
    );
  }
}

class _ExercisePicker extends StatefulWidget {
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onPick;

  const _ExercisePicker({required this.exercises, required this.onPick});

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises
        .where((e) => _search.isEmpty || e.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(filtered[i].name),
              subtitle: Text('${filtered[i].muscleGroup} · ${filtered[i].equipment}'),
              onTap: () {
                widget.onPick(filtered[i]);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ],
    );
  }
}
