import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/workout_provider.dart';
import 'router.dart';
import 'services/notification_service.dart';

// Sea green & cream palette
const _seaGreen = Color(0xFF2A7D4F);
const _seaGreenLight = Color(0xFF5ABF8A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()..loadAll()),
      ],
      child: const WorkoutApp(),
    ),
  );
}

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;
    return MaterialApp.router(
      title: 'Forge',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
    );
  }
}

final _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seaGreen,
    brightness: Brightness.light,
    primary: _seaGreen,
    secondary: _seaGreenLight,
    surface: const Color(0xFFF4FDF7),
    surfaceContainerHighest: const Color(0xFFDFF5EB),
  ),
  scaffoldBackgroundColor: const Color(0xFFF4FDF7),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF4FDF7),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 1,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
    titleTextStyle: TextStyle(
      color: Color(0xFF0A2118),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Color(0xFF2A7D4F)),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: Color(0xFFB8E8CC), width: 1),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFB8E8CC),
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _seaGreen,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFDFF5EB),
    selectedColor: _seaGreen,
    labelStyle: const TextStyle(fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    side: BorderSide.none,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFDFF5EB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _seaGreen, width: 2),
    ),
  ),
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seaGreen,
    brightness: Brightness.dark,
    primary: _seaGreenLight,
    secondary: const Color(0xFF3DAA6E),
    surface: const Color(0xFF091A10),
    surfaceContainerHighest: const Color(0xFF112A1C),
  ),
  scaffoldBackgroundColor: const Color(0xFF091A10),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF091A10),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 1,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
    titleTextStyle: TextStyle(
      color: Color(0xFFCEF0DC),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Color(0xFF5ABF8A)),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF112A1C),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: Color(0xFF1F4A30), width: 1),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF0D2318),
    indicatorColor: const Color(0xFF1F4A30),
    surfaceTintColor: Colors.transparent,
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _seaGreenLight,
      foregroundColor: const Color(0xFF091A10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF1A3D28),
    selectedColor: _seaGreenLight,
    labelStyle: const TextStyle(fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    side: BorderSide.none,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A3D28),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _seaGreenLight, width: 2),
    ),
  ),
);
