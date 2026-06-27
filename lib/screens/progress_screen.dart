import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/body_measurement.dart';
import '../models/exercise.dart';
import '../models/nutrition_log.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
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
        title: const Text('Progress'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Volume'),
            Tab(icon: Icon(Icons.monitor_weight_outlined), text: 'Body Weight'),
            Tab(icon: Icon(Icons.straighten), text: 'Measurements'),
            Tab(icon: Icon(Icons.restaurant_outlined), text: 'Nutrition'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ExerciseTab(),
          _VolumeTab(),
          _BodyWeightTab(),
          _MeasurementsTab(),
          _NutritionTab(),
        ],
      ),
    );
  }
}

// ── Exercise Tab ───────────────────────────────────────────────────────────

class _ExerciseTab extends StatefulWidget {
  const _ExerciseTab();

  @override
  State<_ExerciseTab> createState() => _ExerciseTabState();
}

class _ExerciseTabState extends State<_ExerciseTab> {
  Exercise? _selected;
  List<Map<String, dynamic>> _data = [];
  bool _show1RM = false;

  Future<void> _load(WorkoutProvider provider) async {
    if (_selected == null) return;
    final data = await provider.getProgress(_selected!.id);
    setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<Exercise>(
            value: _selected,
            decoration: const InputDecoration(
              labelText: 'Select Exercise',
              border: OutlineInputBorder(),
            ),
            items: provider.exercises
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (e) {
              setState(() {
                _selected = e;
                _data = [];
              });
              _load(provider);
            },
          ),
        ),
        if (_selected != null && _data.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Show', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Max Weight'),
                  selected: !_show1RM,
                  onSelected: (_) => setState(() => _show1RM = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Est. 1RM'),
                  selected: _show1RM,
                  onSelected: (_) => setState(() => _show1RM = true),
                ),
              ],
            ),
          ),
          // Strength standards info
          if (_selected != null &&
              strengthStandards.containsKey(_selected!.name))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _StandardsRow(
                  exerciseName: _selected!.name, settings: settings),
            ),
        ],
        if (_selected == null)
          const Expanded(
              child: Center(child: Text('Select an exercise to see progress')))
        else if (_data.isEmpty)
          const Expanded(
              child: Center(child: Text('No data yet for this exercise')))
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ExerciseChart(
                data: _data,
                show1RM: _show1RM,
                exerciseName: _selected!.name,
              ),
            ),
          ),
      ],
    );
  }
}

class _StandardsRow extends StatelessWidget {
  final String exerciseName;
  final SettingsProvider settings;
  const _StandardsRow({required this.exerciseName, required this.settings});

  @override
  Widget build(BuildContext context) {
    final standards = strengthStandards[exerciseName]!;
    return Row(
      children: [
        Text('Standards: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        ...standards.entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _stdColor(e.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${e.key} ${settings.formatWeight(e.value)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Color _stdColor(String level) {
    switch (level) {
      case 'Beginner':
        return Colors.green;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _ExerciseChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool show1RM;
  final String exerciseName;
  const _ExerciseChart(
      {required this.data, required this.show1RM, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final standards = strengthStandards[exerciseName];

    final spots = data.asMap().entries.map((e) {
      final weight = (e.value['maxWeight'] as num).toDouble();
      final reps = (e.value['maxReps'] as num).toInt();
      final y = show1RM
          ? settings.toDisplay(WorkoutProvider.epley1RM(weight, reps))
          : settings.toDisplay(weight);
      return FlSpot(e.key.toDouble(), y);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final label = show1RM ? 'Estimated 1RM' : 'Max Weight';

    final extraLines = standards != null
        ? ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: settings.toDisplay(standards['Beginner']!),
              color: Colors.green.withAlpha(180),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Beg',
                style: const TextStyle(fontSize: 9, color: Colors.green),
              ),
            ),
            HorizontalLine(
              y: settings.toDisplay(standards['Intermediate']!),
              color: Colors.orange.withAlpha(180),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Int',
                style: const TextStyle(fontSize: 9, color: Colors.orange),
              ),
            ),
            HorizontalLine(
              y: settings.toDisplay(standards['Advanced']!),
              color: Colors.red.withAlpha(180),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Adv',
                style: const TextStyle(fontSize: 9, color: Colors.red),
              ),
            ),
          ])
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (${settings.unitLabel})',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: (minY - 5).clamp(0, double.infinity),
              maxY: maxY + 5,
              extraLinesData: extraLines,
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = DateTime.parse(data[i]['startTime']);
                      return Text('${dt.day}/${dt.month}',
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color:
                        Theme.of(context).colorScheme.primary.withAlpha(40),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _PRRow(data: data),
      ],
    );
  }
}

class _PRRow extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PRRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final maxWeight = settings.toDisplay(
        data
            .map((d) => (d['maxWeight'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b));
    final maxReps = data
        .map((d) => (d['maxReps'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);
    final topWeight = data
        .map((d) => (d['maxWeight'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    final topReps = data
        .map((d) => (d['maxReps'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);
    final est1rm = settings.toDisplay(WorkoutProvider.epley1RM(topWeight, topReps));

    return Row(
      children: [
        Expanded(
            child: _PRCard(
                label: 'Max Weight',
                value: '$maxWeight ${settings.unitLabel}',
                icon: Icons.fitness_center)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _PRCard(label: 'Max Reps', value: '$maxReps', icon: Icons.repeat)),
        const SizedBox(width: 8),
        Expanded(
            child: _PRCard(
                label: 'Est. 1RM',
                value: '${est1rm.toStringAsFixed(1)} ${settings.unitLabel}',
                icon: Icons.emoji_events)),
      ],
    );
  }
}

class _PRCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _PRCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context).textTheme.labelLarge,
                textAlign: TextAlign.center),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Volume Tab ─────────────────────────────────────────────────────────────

class _VolumeTab extends StatelessWidget {
  const _VolumeTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final history = provider.weeklyVolumeHistory(weeks: 8);

    final allZero = history.every((w) => w['volume'] == 0);
    if (allZero) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Complete workouts to see volume history',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final maxVol = history
        .map((w) => (w['volume'] as int).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Volume (${settings.unitLabel})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxVol * 1.2,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      settings.toDisplay(v).toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  )),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= history.length) {
                          return const SizedBox.shrink();
                        }
                        final dt = history[i]['weekEnd'] as DateTime;
                        return Text('${dt.day}/${dt.month}',
                            style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: history.asMap().entries.map((e) {
                  final vol = settings
                      .toDisplay((e.value['volume'] as int).toDouble());
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: vol,
                        color: Theme.of(context).colorScheme.primary,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _VolStat(
                label: 'This Week',
                value: settings
                    .formatWeight(provider.thisWeekVolume.toDouble()),
              ),
              _VolStat(
                label: 'Last Week',
                value: settings
                    .formatWeight(provider.lastWeekVolume.toDouble()),
              ),
              _VolStat(
                label: 'All Time',
                value: settings
                    .formatWeight(provider.allTimeVolume.toDouble()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolStat extends StatelessWidget {
  final String label, value;
  const _VolStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ── Body Weight Tab ────────────────────────────────────────────────────────

class _BodyWeightTab extends StatefulWidget {
  const _BodyWeightTab();

  @override
  State<_BodyWeightTab> createState() => _BodyWeightTabState();
}

class _BodyWeightTabState extends State<_BodyWeightTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final entries = provider.bodyWeights;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Log body weight (${settings.unitLabel})',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final val = double.tryParse(_ctrl.text);
                  if (val != null && val > 0) {
                    provider.addBodyWeight(settings.toKg(val));
                    _ctrl.clear();
                  }
                },
                child: const Text('Log'),
              ),
            ],
          ),
        ),
        if (entries.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_weight_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No body weight entries yet',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else ...[
          if (entries.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 180,
                child: _BodyWeightChart(entries: entries, settings: settings),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final e = entries[entries.length - 1 - i];
                return ListTile(
                  dense: true,
                  title: Text(settings.formatWeight(e.weightKg),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_fmtDate(e.date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => provider.deleteBodyWeight(e.id),
                    color: Colors.red,
                  ),
                  leading: Icon(Icons.circle,
                      size: 10,
                      color: Theme.of(context).colorScheme.primary),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _BodyWeightChart extends StatelessWidget {
  final entries;
  final SettingsProvider settings;
  const _BodyWeightChart({required this.entries, required this.settings});

  @override
  Widget build(BuildContext context) {
    final spots = entries.asMap().entries.map<FlSpot>((e) {
      return FlSpot(e.key.toDouble(), settings.toDisplay(e.value.weightKg));
    }).toList();

    final weights = spots.map((s) => s.y).toList();
    final minY = weights.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        minY: minY.clamp(0, double.infinity),
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Measurements Tab ───────────────────────────────────────────────────────

class _MeasurementsTab extends StatefulWidget {
  const _MeasurementsTab();

  @override
  State<_MeasurementsTab> createState() => _MeasurementsTabState();
}

class _MeasurementsTabState extends State<_MeasurementsTab> {
  final _ctrls = <String, TextEditingController>{
    'Chest': TextEditingController(),
    'Waist': TextEditingController(),
    'Hips': TextEditingController(),
    'Bicep L': TextEditingController(),
    'Bicep R': TextEditingController(),
    'Thigh L': TextEditingController(),
    'Thigh R': TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  double? _val(String key) => double.tryParse(_ctrls[key]!.text);

  void _log(WorkoutProvider provider) {
    final m = BodyMeasurement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      chest: _val('Chest'),
      waist: _val('Waist'),
      hips: _val('Hips'),
      bicepL: _val('Bicep L'),
      bicepR: _val('Bicep R'),
      thighL: _val('Thigh L'),
      thighR: _val('Thigh R'),
    );
    final hasAny = [m.chest, m.waist, m.hips, m.bicepL, m.bicepR, m.thighL, m.thighR]
        .any((v) => v != null);
    if (!hasAny) return;
    provider.addBodyMeasurement(m);
    for (final c in _ctrls.values) c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final entries = provider.bodyMeasurements;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log Measurements (cm)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: _ctrls.entries.map((e) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 56) / 2,
                  child: TextField(
                    controller: e.value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: e.key,
                      suffixText: 'cm',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                )).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _log(provider),
              child: const Text('Log Measurements'),
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...entries.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(_fmtDate(m.date),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_formatMeasurement(m)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red,
                      onPressed: () => provider.deleteBodyMeasurement(m.id),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _formatMeasurement(BodyMeasurement m) {
    final parts = <String>[];
    if (m.chest != null) parts.add('Chest: ${m.chest}cm');
    if (m.waist != null) parts.add('Waist: ${m.waist}cm');
    if (m.hips != null) parts.add('Hips: ${m.hips}cm');
    if (m.bicepL != null) parts.add('Bicep L: ${m.bicepL}cm');
    if (m.bicepR != null) parts.add('Bicep R: ${m.bicepR}cm');
    if (m.thighL != null) parts.add('Thigh L: ${m.thighL}cm');
    if (m.thighR != null) parts.add('Thigh R: ${m.thighR}cm');
    return parts.join('  ·  ');
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Nutrition Tab ──────────────────────────────────────────────────────────

class _NutritionTab extends StatefulWidget {
  const _NutritionTab();

  @override
  State<_NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<_NutritionTab> {
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _calCtrl.dispose();
    _protCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _log(WorkoutProvider provider) {
    final cal = int.tryParse(_calCtrl.text);
    final prot = double.tryParse(_protCtrl.text);
    final note = _noteCtrl.text.trim();
    if (cal == null && prot == null && note.isEmpty) return;

    provider.addNutritionLog(NutritionLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      calories: cal,
      proteinG: prot,
      note: note,
    ));
    _calCtrl.clear();
    _protCtrl.clear();
    _noteCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final logs = provider.nutritionLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log Nutrition', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calories',
                    suffixText: 'kcal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _protCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Protein',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Chicken & rice, post-workout shake...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _log(provider),
              child: const Text('Log'),
            ),
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Recent Logs', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...logs.take(20).map((l) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Row(
                      children: [
                        if (l.calories != null)
                          Text('${l.calories} kcal',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (l.calories != null && l.proteinG != null)
                          const Text('  ·  '),
                        if (l.proteinG != null)
                          Text('${l.proteinG}g protein',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (l.note.isNotEmpty) Text(l.note),
                        Text(_fmtDate(l.date),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red,
                      onPressed: () => provider.deleteNutritionLog(l.id),
                    ),
                    isThreeLine: l.note.isNotEmpty,
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
