import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/workout_session.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _filterIndex = 0; // 0=All, 1=Week, 2=Month

  static const _filters = ['All', 'This Week', 'This Month'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<WorkoutSession> _filtered(List<WorkoutSession> sessions) {
    final now = DateTime.now();
    List<WorkoutSession> result = sessions;

    if (_filterIndex == 1) {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      result = result.where((s) => s.startTime.isAfter(weekStart)).toList();
    } else if (_filterIndex == 2) {
      final monthStart = DateTime(now.year, now.month, 1);
      result = result.where((s) => s.startTime.isAfter(monthStart)).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((s) {
        if (s.name.toLowerCase().contains(q)) return true;
        return s.exercises.any((e) => e.exerciseName.toLowerCase().contains(q));
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final filtered = _filtered(provider.sessions);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search workouts or exercises...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => FilterChip(
                label: Text(_filters[i]),
                selected: _filterIndex == i,
                onSelected: (_) => setState(() => _filterIndex = i),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isNotEmpty || _filterIndex > 0
                          ? 'No workouts match your filter.'
                          : 'No workouts yet.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                                  title: const Text('Delete Session?'),
                                  content: Text('Delete "${s.name}"?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => provider.deleteSession(s.id),
                        child: _SessionCard(session: s, hasPR: provider.sessionHasPR(s)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;
  final bool hasPR;
  const _SessionCard({required this.session, required this.hasPR});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final duration = session.endTime?.difference(session.startTime);
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final totalDisplay = settings.toDisplay(session.totalVolume.toDouble());

    final accentColor = hasPR ? const Color(0xFFFFB300) : Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasPR
                      ? [const Color(0xFFFFB300), const Color(0xFFF57F17)]
                      : [accentColor, accentColor.withAlpha(160)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Expanded(
              child: ExpansionTile(
        title: Row(
          children: [
            Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hasPR) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFF57F17)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text('PR',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(fmt.format(session.startTime)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${totalDisplay.toInt()} ${settings.unitLabel}',
                style: Theme.of(context).textTheme.labelLarge),
            if (duration != null)
              Text('${duration.inMinutes}m', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        children: session.exercises.map((se) {
          final completedSets = se.sets.where((s) => s.isCompleted).toList();
          return ListTile(
            dense: true,
            title: Text(se.exerciseName),
            subtitle: Text(
              completedSets.isEmpty
                  ? 'No sets logged'
                  : completedSets
                      .map((s) {
                        final tags = [
                          if (s.rpe > 0) 'RPE ${s.rpe}',
                          if (s.isDropset) 'DS',
                          if (s.toFailure) 'F',
                        ].join(' ');
                        final base =
                            '${settings.toDisplay(s.weight)} ${settings.unitLabel} × ${s.reps}';
                        return tags.isNotEmpty ? '$base ($tags)' : base;
                      })
                      .join(', '),
            ),
          );
        }).toList(),
      ),
            ),
          ],
        ),
      ),
    );
  }
}
