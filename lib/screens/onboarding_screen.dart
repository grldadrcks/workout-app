import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  String _goal = 'Build Muscle';
  WeightUnit _unit = WeightUnit.kg;

  static const _totalPages = 5;

  static const _goals = [
    ('Build Muscle', Icons.fitness_center),
    ('Lose Weight', Icons.monitor_weight_outlined),
    ('Get Stronger', Icons.trending_up),
    ('Stay Active', Icons.directions_run),
  ];

  Future<void> _finish({String destination = '/'}) async {
    final settings = context.read<SettingsProvider>();
    await settings.setWeightUnit(_unit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go(destination);
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPathPage = _page == _totalPages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: List.generate(
                  _totalPages,
                  (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                          right: i < _totalPages - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i <= _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(),
                  _GoalPage(
                    selected: _goal,
                    goals: _goals,
                    onSelect: (g) => setState(() => _goal = g),
                  ),
                  _UnitPage(
                    selected: _unit,
                    onSelect: (u) => setState(() => _unit = u),
                  ),
                  const _PrivacyPage(),
                  _TrainingPathPage(
                    onProgram: () => _finish(destination: '/programs'),
                    onDiy: () => _finish(destination: '/routines'),
                  ),
                ],
              ),
            ),

            // Bottom button — hidden on path page (cards are the CTAs)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: isPathPage
                  ? TextButton(
                      onPressed: () => _finish(),
                      child: const Text('Skip for now'),
                    )
                  : FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      child: Text(_page < _totalPages - 2
                          ? 'Continue'
                          : 'Continue'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fitness_center, size: 60,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text('Welcome to Forge',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'Track your workouts, crush your goals, and watch your progress grow.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final String selected;
  final List<(String, IconData)> goals;
  final ValueChanged<String> onSelect;
  const _GoalPage({required this.selected, required this.goals, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text("What's your goal?",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('We\'ll tailor your experience.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 32),
          ...goals.map((g) {
            final isSelected = selected == g.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onSelect(g.$1),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(g.$2,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey),
                      const SizedBox(width: 16),
                      Text(g.$1,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          )),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _UnitPage extends StatelessWidget {
  final WeightUnit selected;
  final ValueChanged<WeightUnit> onSelect;
  const _UnitPage({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('Choose your units',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('You can change this later in Settings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 32),
          _UnitOption(
            label: 'Kilograms (kg)',
            sublabel: 'Used in most countries',
            icon: Icons.fitness_center,
            selected: selected == WeightUnit.kg,
            onTap: () => onSelect(WeightUnit.kg),
          ),
          const SizedBox(height: 12),
          _UnitOption(
            label: 'Pounds (lbs)',
            sublabel: 'Used in the US',
            icon: Icons.fitness_center,
            selected: selected == WeightUnit.lbs,
            onTap: () => onSelect(WeightUnit.lbs),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline,
                size: 36, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text('Your data stays with you',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Forge is fully offline and private by design.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 28),
          ...[
            (Icons.storage_outlined, 'Stored only on your device',
                'No cloud, no servers — your workout history never leaves your phone.'),
            (Icons.visibility_off_outlined, 'No tracking',
                'We collect zero analytics, no ads, no third-party SDKs.'),
            (Icons.share_outlined, 'You control sharing',
                'Export or share only when you choose to, nothing is uploaded automatically.'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.$1,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(item.$3,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
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

// ── Training Path Page ─────────────────────────────────────────────────────

class _TrainingPathPage extends StatelessWidget {
  final VoidCallback onProgram;
  final VoidCallback onDiy;
  const _TrainingPathPage({required this.onProgram, required this.onDiy});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('One last thing',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('How do you want to get started?',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 28),

          // Program path
          _PathChoiceCard(
            icon: Icons.auto_graph,
            iconBg: Colors.green.withAlpha(25),
            iconColor: Colors.green,
            badge: 'Recommended',
            badgeColor: Colors.green,
            title: 'Follow a Program',
            description:
                'A guided plan that tells you exactly what to lift '
                'each session. Weights increase automatically.',
            bullets: const [
              'Perfect if you\'re just starting out',
              'No guesswork — the app handles it',
              'Progress tracked every session',
            ],
            onTap: onProgram,
          ),

          const SizedBox(height: 16),

          // DIY path
          _PathChoiceCard(
            icon: Icons.edit_note,
            iconBg: Theme.of(context).colorScheme.primaryContainer,
            iconColor: Theme.of(context).colorScheme.primary,
            badge: null,
            badgeColor: null,
            title: 'Build My Own',
            description:
                'Create your own routines with the exercises you want, '
                'or jump in with a free workout.',
            bullets: const [],
            onTap: onDiy,
          ),
        ],
      ),
    );
  }
}

class _PathChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? badge;
  final Color? badgeColor;
  final String title;
  final String description;
  final List<String> bullets;
  final VoidCallback onTap;

  const _PathChoiceCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.description,
    required this.bullets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor!.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: badgeColor!.withAlpha(100)),
                      ),
                      child: Text(badge!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey.shade600)),
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...bullets.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 14, color: iconColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(b,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700)),
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Get started',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: iconColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: iconColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _UnitOption({required this.label, required this.sublabel, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                Text(sublabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
