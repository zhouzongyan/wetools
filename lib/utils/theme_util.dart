import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class ThemeUtil extends ChangeNotifier {
  static const String _key = 'theme_mode';
  static const String _autoStartKey = 'auto_start';
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoStart = false;

  bool get autoStart => _autoStart;

  ThemeUtil() {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _loadThemeMode();
    _loadAutoStart();
  }

  void _loadThemeMode() {
    final value = _prefs.getString(_key);
    if (value != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == value,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  void _loadAutoStart() {
    _autoStart = _prefs.getBool(_autoStartKey) ?? false;
    notifyListeners();
  }

  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    await _prefs.setBool(_autoStartKey, value);
    if (value) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_key, mode.toString());
    notifyListeners();
  }
} 