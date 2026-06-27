import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  final _ctrl = TextEditingController();
  double _barWeight = 20.0; // kg
  double _targetWeight = 0;

  static const _barOptions = [
    (20.0, 'Olympic Bar (20 kg)'),
    (15.0, "Women's Bar (15 kg)"),
    (10.0, 'EZ Bar (10 kg)'),
    (0.0, 'No Bar'),
  ];

  // Available plate sizes in kg
  static const _plateSizes = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

  List<double> _calcPlatesPerSide(double totalKg) {
    double remaining = (totalKg - _barWeight) / 2;
    if (remaining <= 0) return [];
    final plates = <double>[];
    for (final p in _plateSizes) {
      while (remaining >= p - 0.001) {
        plates.add(p);
        remaining -= p;
        remaining = double.parse(remaining.toStringAsFixed(4));
      }
    }
    return plates;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final plates = _targetWeight > 0 ? _calcPlatesPerSide(_targetWeight) : <double>[];
    final isLbs = settings.weightUnit == WeightUnit.lbs;
    final kgToLbs = 2.20462;

    String fmtKg(double kg) {
      if (isLbs) {
        final v = kg * kgToLbs;
        return '${v == v.truncateToDouble() ? v.toInt() : v.toStringAsFixed(1)} lb';
      }
      return '${kg == kg.truncateToDouble() ? kg.toInt() : kg} kg';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Plate Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Target weight input
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target weight (${settings.unitLabel})',
              prefixIcon: const Icon(Icons.fitness_center),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              final entered = double.tryParse(v) ?? 0;
              setState(() => _targetWeight = isLbs ? entered / kgToLbs : entered);
            },
          ),
          const SizedBox(height: 20),

          // Bar selector
          Text('Bar', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _barOptions.map((opt) => ChoiceChip(
              label: Text(opt.$2),
              selected: _barWeight == opt.$1,
              onSelected: (_) => setState(() => _barWeight = opt.$1),
            )).toList(),
          ),
          const SizedBox(height: 24),

          if (_targetWeight > 0) ...[
            // Summary row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoTile(label: 'Target', value: fmtKg(_targetWeight)),
                  _InfoTile(label: 'Bar', value: fmtKg(_barWeight)),
                  _InfoTile(label: 'Each Side', value: fmtKg((_targetWeight - _barWeight) / 2)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Plates per side', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),

            if (plates.isEmpty)
              Center(
                child: Text(
                  _targetWeight <= _barWeight
                      ? 'Just the bar!'
                      : 'Cannot load — check target weight',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: plates.map((p) => _PlateChip(kg: p, label: fmtKg(p))).toList(),
              ),
            const SizedBox(height: 24),

            // Visual bar diagram
            if (plates.isNotEmpty) _BarDiagram(plates: plates, barWeight: _barWeight, fmtKg: fmtKg),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Enter your target weight above', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _PlateChip extends StatelessWidget {
  final double kg;
  final String label;
  const _PlateChip({required this.kg, required this.label});

  Color get _plateColor {
    if (kg >= 25) return const Color(0xFFE53935);
    if (kg >= 20) return const Color(0xFF1E88E5);
    if (kg >= 15) return const Color(0xFFFFEB3B);
    if (kg >= 10) return const Color(0xFF43A047);
    if (kg >= 5) return const Color(0xFFFF7043);
    if (kg >= 2.5) return const Color(0xFF8E24AA);
    return const Color(0xFF78909C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _plateColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: _plateColor.withAlpha(80), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _BarDiagram extends StatelessWidget {
  final List<double> plates;
  final double barWeight;
  final String Function(double) fmtKg;
  const _BarDiagram({required this.plates, required this.barWeight, required this.fmtKg});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Load order (inside → outside)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left collar
              Container(width: 12, height: 40, color: Colors.grey[400]),
              // Bar centre
              Container(
                width: 40, height: 16,
                color: Colors.grey[600],
                alignment: Alignment.center,
                child: Text(fmtKg(barWeight), style: const TextStyle(color: Colors.white, fontSize: 8)),
              ),
              // Plates left side (reversed — outer plate first)
              ...plates.reversed.map((p) => _plateTile(p)),
              // Centre indicator
              Container(width: 8, height: 50, color: Colors.grey[700]),
              // Plates right side
              ...plates.map((p) => _plateTile(p)),
              Container(width: 40, height: 16, color: Colors.grey[600]),
              Container(width: 12, height: 40, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plateTile(double kg) {
    final h = (20 + kg * 2.5).clamp(24.0, 100.0);
    return Container(
      width: 18, height: h,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _colorFor(kg),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _colorFor(double kg) {
    if (kg >= 25) return const Color(0xFFE53935);
    if (kg >= 20) return const Color(0xFF1E88E5);
    if (kg >= 15) return const Color(0xFFFFEB3B);
    if (kg >= 10) return const Color(0xFF43A047);
    if (kg >= 5) return const Color(0xFFFF7043);
    if (kg >= 2.5) return const Color(0xFF8E24AA);
    return const Color(0xFF78909C);
  }
}
