import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _themeOptions = [
    (ThemeMode.system, 'System default', Icons.brightness_auto),
    (ThemeMode.light, 'Light', Icons.light_mode),
    (ThemeMode.dark, 'Dark', Icons.dark_mode),
  ];

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Experience Level ───────────────────────────────────────────
          const _SectionHeader('Experience Level'),
          SwitchListTile(
            secondary: const Icon(Icons.school_outlined),
            title: const Text('Beginner Mode'),
            subtitle: Text(settings.beginnerMode
                ? 'Showing simplified view — RPE, dropsets & failure hidden'
                : 'Showing all features'),
            value: settings.beginnerMode,
            onChanged: (v) => settings.setBeginnerMode(v),
          ),

          // ── Appearance ──────────────────────────────────────────────────
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (v) => settings.setThemeMode(v!),
            child: Column(
              children: _themeOptions
                  .map((opt) => RadioListTile<ThemeMode>(
                        value: opt.$1,
                        secondary: Icon(opt.$3),
                        title: Text(opt.$2),
                      ))
                  .toList(),
            ),
          ),

          // ── Units ──────────────────────────────────────────────────────
          const _SectionHeader('Units'),
          RadioGroup<WeightUnit>(
            groupValue: settings.weightUnit,
            onChanged: (v) => settings.setWeightUnit(v!),
            child: const Column(
              children: [
                RadioListTile<WeightUnit>(
                  value: WeightUnit.kg,
                  secondary: Icon(Icons.fitness_center),
                  title: Text('Kilograms (kg)'),
                ),
                RadioListTile<WeightUnit>(
                  value: WeightUnit.lbs,
                  secondary: Icon(Icons.fitness_center),
                  title: Text('Pounds (lbs)'),
                ),
              ],
            ),
          ),

          // ── Weekly Goal ────────────────────────────────────────────────
          const _SectionHeader('Weekly Goal'),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Workouts per week'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.weeklyGoal > 1
                      ? () => settings.setWeeklyGoal(settings.weeklyGoal - 1)
                      : null,
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${settings.weeklyGoal}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: settings.weeklyGoal < 7
                      ? () => settings.setWeeklyGoal(settings.weeklyGoal + 1)
                      : null,
                ),
              ],
            ),
          ),

          // ── Rest Days ──────────────────────────────────────────────────
          const _SectionHeader('Rest Days'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final day = i + 1; // 1=Mon, 7=Sun
                final isRest = settings.restDays.contains(day);
                return FilterChip(
                  label: Text(_dayNames[i]),
                  selected: isRest,
                  onSelected: (_) {
                    final updated = Set<int>.from(settings.restDays);
                    if (isRest) {
                      updated.remove(day);
                    } else {
                      updated.add(day);
                    }
                    settings.setRestDays(updated);
                  },
                );
              }),
            ),
          ),

          // ── Reminders ─────────────────────────────────────────────────
          const _SectionHeader('Reminders'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Daily workout reminder'),
            subtitle: Text(
                settings.notifEnabled ? _fmtTime(settings.notifTime) : 'Tap to enable'),
            value: settings.notifEnabled,
            onChanged: (v) => settings.setNotifEnabled(v),
          ),
          if (settings.notifEnabled)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Reminder time'),
              trailing: Text(
                _fmtTime(settings.notifTime),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: settings.notifTime,
                );
                if (t != null) settings.setNotifTime(t);
              },
            ),

          // ── Data ──────────────────────────────────────────────────────
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export history as CSV'),
            subtitle: const Text('Share a spreadsheet of all workouts'),
            onTap: () async {
              try {
                final csv = await provider.exportCsv();
                await Share.share(csv, subject: 'Forge Workout History');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup database'),
            subtitle: const Text('Share a copy of your workout database'),
            onTap: () async {
              try {
                final path = await provider.backupDb();
                await Share.shareXFiles([XFile(path)], subject: 'Forge Backup');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup failed: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replace database with a backup file'),
            onTap: () => _confirmRestore(context, provider),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _confirmRestore(BuildContext context, WorkoutProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'This will replace ALL current data with the selected backup. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      await provider.restoreDb(path);
      await provider.loadAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore complete! Restart the app to see changes.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
