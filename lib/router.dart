import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/workout_session.dart';
import 'providers/workout_provider.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/active_workout_screen.dart';
import 'screens/history_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/workout_complete_screen.dart';
import 'screens/plate_calculator_screen.dart';
import 'screens/badges_screen.dart';
import 'screens/prs_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/cardio_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    if (state.matchedLocation == '/onboarding') return null;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (!done) return '/onboarding';
    return null;
  },
  routes: [
    GoRoute(path: '/onboarding', builder: (ctx, _) => const OnboardingScreen()),
    GoRoute(
      path: '/complete',
      builder: (ctx, state) =>
          WorkoutCompleteScreen(session: state.extra as WorkoutSession),
    ),
    GoRoute(path: '/active', builder: (ctx, _) => const ActiveWorkoutScreen()),
    GoRoute(path: '/plate-calc', builder: (ctx, _) => const PlateCalculatorScreen()),
    GoRoute(path: '/badges', builder: (ctx, _) => const BadgesScreen()),
    GoRoute(path: '/prs', builder: (ctx, _) => const PrsScreen()),
    GoRoute(path: '/programs', builder: (ctx, _) => const ProgramsScreen()),
    GoRoute(path: '/cardio', builder: (ctx, _) => const CardioScreen()),
    ShellRoute(
      builder: (context, _, child) => _Shell(child: child),
      routes: [
        GoRoute(path: '/', builder: (ctx, _) => const HomeScreen()),
        GoRoute(path: '/routines', builder: (ctx, _) => const RoutinesScreen()),
        GoRoute(path: '/library', builder: (ctx, _) => const LibraryScreen()),
        GoRoute(path: '/history', builder: (ctx, _) => const HistoryScreen()),
        GoRoute(path: '/progress', builder: (ctx, _) => const ProgressScreen()),
        GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
      ],
    ),
  ],
);

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  static const _tabs = [
    ('/', Icons.home_outlined, Icons.home, 'Home'),
    ('/routines', Icons.list_outlined, Icons.list, 'Routines'),
    ('/library', Icons.search_outlined, Icons.search, 'Library'),
    ('/history', Icons.history_outlined, Icons.history, 'History'),
    ('/progress', Icons.bar_chart_outlined, Icons.bar_chart, 'Progress'),
    ('/settings', Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  static const _tabColors = [
    Color(0xFF2979FF), // Home      — Electric Blue
    Color(0xFFFF6D00), // Routines  — Deep Orange
    Color(0xFF7C4DFF), // Library   — Deep Purple
    Color(0xFF00ACC1), // History   — Cyan
    Color(0xFF43A047), // Progress  — Green
    Color(0xFF78909C), // Settings  — Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex =
        _tabs.indexWhere((t) => t.$1 == location).clamp(0, _tabs.length - 1);
    final hasActive = context.watch<WorkoutProvider>().activeSession != null;

    final tabColor = _tabColors[currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context);
    final onTab =
        tabColor.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: tabColor,
          onPrimary: onTab,
          primaryContainer: tabColor.withAlpha(isDark ? 50 : 40),
          onPrimaryContainer: tabColor,
          secondary: tabColor,
          onSecondary: onTab,
          secondaryContainer: tabColor.withAlpha(isDark ? 50 : 40),
          onSecondaryContainer: tabColor,
        ),
        scaffoldBackgroundColor: isDark
            ? Color.lerp(const Color(0xFF0D1117), tabColor, 0.05)!
            : Color.lerp(const Color(0xFFF0F2F5), tabColor, 0.04)!,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: isDark
              ? Color.lerp(const Color(0xFF0D1117), tabColor, 0.05)
              : Color.lerp(const Color(0xFFF0F2F5), tabColor, 0.04),
          iconTheme: IconThemeData(color: tabColor),
          actionsIconTheme: IconThemeData(color: tabColor),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: tabColor,
            foregroundColor: onTab,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        navigationBarTheme: base.navigationBarTheme.copyWith(
          indicatorColor: tabColor.withAlpha(isDark ? 60 : 50),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: tabColor);
            }
            return null;
          }),
        ),
      ),
      child: Scaffold(
        body: Column(
          children: [
            Expanded(child: child),
            if (hasActive) _MiniWorkoutBar(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) => context.go(_tabs[i].$1),
          destinations: _tabs
              .map((t) => NavigationDestination(
                    icon: Icon(t.$2),
                    selectedIcon: Icon(t.$3),
                    label: t.$4,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _MiniWorkoutBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<WorkoutProvider>().activeSession!;
    final completedSets = session.exercises
        .fold(0, (s, e) => s + e.sets.where((set) => set.isCompleted).length);
    final totalSets = session.exercises.fold(0, (s, e) => s + e.sets.length);

    return GestureDetector(
      onTap: () => context.go('/active'),
      child: Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.fitness_center, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(session.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: totalSets > 0 ? completedSets / totalSets : 0,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$completedSets/$totalSets sets',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
