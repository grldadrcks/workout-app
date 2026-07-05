import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../services/exercise_api.dart';
import '../services/wger_api.dart';
import '../utils/muscle_colors.dart';
import '../widgets/body_map.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.storage_outlined), text: 'Local'),
            Tab(icon: Icon(Icons.cloud_outlined), text: 'Online'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _LocalTab(),
          _OnlineTab(),
        ],
      ),
    );
  }
}

// ── Local Tab ──────────────────────────────────────────────────────────────

class _LocalTab extends StatefulWidget {
  const _LocalTab();

  @override
  State<_LocalTab> createState() => _LocalTabState();
}

class _LocalTabState extends State<_LocalTab> {
  String _search = '';
  String _filterGroup = 'All';

  static const _groups = ['All', 'Chest', 'Back', 'Shoulders', 'Legs', 'Arms', 'Core', 'Other'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final filtered = provider.exercises.where((e) {
      final matchGroup = _filterGroup == 'All' || e.muscleGroup == _filterGroup;
      final matchSearch = _search.isEmpty || e.name.toLowerCase().contains(_search.toLowerCase());
      return matchGroup && matchSearch;
    }).toList();

    final grouped = <String, List<Exercise>>{};
    for (final e in filtered) {
      grouped.putIfAbsent(e.muscleGroup, () => []).add(e);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _groups.map((g) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(g),
                  selected: _filterGroup == g,
                  onSelected: (_) => setState(() => _filterGroup = g),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              ...grouped.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: muscleColor(entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(entry.key,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: muscleColor(entry.key),
                                    )),
                          ],
                        ),
                      ),
                      ...entry.value.map((e) => ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: muscleColor(e.muscleGroup).withAlpha(35),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.fitness_center,
                                  size: 16, color: muscleColor(e.muscleGroup)),
                            ),
                            title: Text(e.name),
                            subtitle: Text(
                              '${e.equipment}${e.level.isNotEmpty ? ' · ${e.level}' : ''}',
                            ),
                            trailing: e.isCustom
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => provider.deleteExercise(e.id),
                                  )
                                : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                            onTap: () => _showDetail(context, e),
                          )),
                    ],
                  )),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Exercise e) => _showExerciseDetail(context, e);
}

// ── Online Tab ─────────────────────────────────────────────────────────────

class _OnlineTab extends StatefulWidget {
  const _OnlineTab();

  @override
  State<_OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends State<_OnlineTab> {
  final _ctrl = TextEditingController();
  String _source = 'ninja';
  String _filterMuscle = 'Any';
  List<Exercise> _results = [];
  bool _loading = false;
  String? _error;

  static const _muscles = [
    'Any', 'abdominals', 'abductors', 'adductors', 'biceps', 'calves',
    'chest', 'forearms', 'glutes', 'hamstrings', 'lats', 'lower_back',
    'middle_back', 'neck', 'quadriceps', 'shoulders', 'traps', 'triceps',
  ];

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final term = _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim();
      final List<Exercise> results;
      if (_source == 'wger') {
        results = await WgerApi.search(name: term);
      } else {
        results = await ExerciseApi.search(
          name: term,
          muscle: _filterMuscle == 'Any' ? null : _filterMuscle,
        );
      }
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Source toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('API Ninjas'),
                selected: _source == 'ninja',
                onSelected: (_) => setState(() {
                  _source = 'ninja';
                  _results = [];
                  _error = null;
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('wger'),
                selected: _source == 'wger',
                onSelected: (_) => setState(() {
                  _source = 'wger';
                  _results = [];
                  _error = null;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('Go')),
            ],
          ),
        ),
        // Muscle filter chips — only shown for API Ninjas (wger doesn't support server-side muscle filter)
        if (_source == 'ninja') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _muscles.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(m == 'Any' ? 'Any Muscle' : m.replaceAll('_', ' ')),
                    selected: _filterMuscle == m,
                    onSelected: (_) => setState(() => _filterMuscle = m),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Search online for exercises\nand add them to your library',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final e = _results[i];
        return ListTile(
          title: Text(e.name),
          subtitle: Text('${e.muscleGroup} · ${e.equipment}${e.level.isNotEmpty ? ' · ${e.level}' : ''}'),
          trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          onTap: () => _showOnlineDetail(context, e),
        );
      },
    );
  }

  void _showOnlineDetail(BuildContext context, Exercise e) {
    final provider = context.read<WorkoutProvider>();
    final alreadySaved = provider.exercises.any((ex) => ex.id == e.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(child: Text(e.name, style: Theme.of(context).textTheme.titleLarge)),
                if (!alreadySaved)
                  FilledButton.icon(
                    onPressed: () {
                      provider.saveApiExercise(e);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${e.name} added to library')),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Save'),
                  )
                else
                  const Chip(label: Text('Saved')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(e.muscleGroup)),
                Chip(label: Text(e.equipment)),
                if (e.level.isNotEmpty) Chip(label: Text(e.level)),
              ],
            ),
            if (e.instructions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Instructions', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...e.instructions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 12, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared detail sheet (local) ────────────────────────────────────────────

void _showExerciseDetail(BuildContext context, Exercise e) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(e.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(e.muscleGroup)),
              Chip(label: Text(e.equipment)),
              if (e.level.isNotEmpty) Chip(label: Text(e.level)),
            ],
          ),
          const SizedBox(height: 16),
          BodyMap(muscleGroup: e.muscleGroup),
          if (e.instructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Instructions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...e.instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 12, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value)),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    ),
  );
}
