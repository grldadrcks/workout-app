import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

enum WeightUnit { kg, lbs }

class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'themeMode';
  static const _unitKey = 'weightUnit';
  static const _goalKey = 'weeklyGoal';
  static const _restDaysKey = 'restDays';
  static const _notifEnabledKey = 'notifEnabled';
  static const _notifHourKey = 'notifHour';
  static const _notifMinuteKey = 'notifMinute';
  static const _beginnerModeKey = 'beginnerMode';
  static const _kgToLbs = 2.20462;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  WeightUnit _weightUnit = WeightUnit.kg;
  WeightUnit get weightUnit => _weightUnit;
  String get unitLabel => _weightUnit == WeightUnit.kg ? 'kg' : 'lbs';

  int _weeklyGoal = 3;
  int get weeklyGoal => _weeklyGoal;

  Set<int> _restDays = {}; // 1=Mon … 7=Sun
  Set<int> get restDays => _restDays;

  bool _notifEnabled = false;
  bool get notifEnabled => _notifEnabled;

  bool _beginnerMode = true;
  bool get beginnerMode => _beginnerMode;

  TimeOfDay _notifTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay get notifTime => _notifTime;

  double toDisplay(double kg) =>
      _weightUnit == WeightUnit.lbs ? double.parse((kg * _kgToLbs).toStringAsFixed(2)) : kg;

  double toKg(double display) =>
      _weightUnit == WeightUnit.lbs ? double.parse((display / _kgToLbs).toStringAsFixed(4)) : display;

  String formatWeight(double kg) {
    final v = toDisplay(kg);
    return v == v.truncate() ? '${v.toInt()} $unitLabel' : '$v $unitLabel';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _weightUnit = prefs.getString(_unitKey) == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;
    _weeklyGoal = prefs.getInt(_goalKey) ?? 3;
    _restDays = (prefs.getString(_restDaysKey) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .map(int.parse)
        .toSet();
    _notifEnabled = prefs.getBool(_notifEnabledKey) ?? false;
    _notifTime = TimeOfDay(
      hour: prefs.getInt(_notifHourKey) ?? 8,
      minute: prefs.getInt(_notifMinuteKey) ?? 0,
    );
    _beginnerMode = prefs.getBool(_beginnerModeKey) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    _weightUnit = unit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unitKey, unit == WeightUnit.lbs ? 'lbs' : 'kg');
  }

  Future<void> setWeeklyGoal(int goal) async {
    _weeklyGoal = goal.clamp(1, 7);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, _weeklyGoal);
  }

  Future<void> setRestDays(Set<int> days) async {
    _restDays = days;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_restDaysKey, days.join(','));
  }

  Future<void> setNotifEnabled(bool enabled) async {
    _notifEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifEnabledKey, enabled);
    if (enabled) {
      await NotificationService.scheduleDaily(_notifTime);
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> setBeginnerMode(bool value) async {
    _beginnerMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_beginnerModeKey, value);
  }

  Future<void> setNotifTime(TimeOfDay time) async {
    _notifTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notifHourKey, time.hour);
    await prefs.setInt(_notifMinuteKey, time.minute);
    if (_notifEnabled) {
      await NotificationService.scheduleDaily(time);
    }
  }
}
