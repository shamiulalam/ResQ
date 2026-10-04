import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_mode.dart';

/// Key used to store the user's chosen theme in SharedPreferences.
const _kThemeKey = 'resq_theme_mode';

/// A [ChangeNotifier] that owns the current [AppThemeMode] and persists it
/// across app launches via [SharedPreferences].
///
/// Usage:
/// ```dart
/// // Read current mode
/// final mode = context.watch<ThemeNotifier>().mode;
///
/// // Toggle from anywhere
/// context.read<ThemeNotifier>().toggle();
///
/// // Set directly
/// context.read<ThemeNotifier>().setMode(AppThemeMode.light);
/// ```
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._internal(this._mode);

  AppThemeMode _mode;

  /// The currently active theme mode.
  AppThemeMode get mode => _mode;

  /// Whether the current mode is [AppThemeMode.dark].
  bool get isDark => _mode == AppThemeMode.dark;

  /// Temporary compatibility alias for screens that have not yet renamed
  /// their local `isSpecial` variables. New code should use [isDark].
  @Deprecated('Use isDark instead.')
  bool get isSpecial => isDark;

  /// Factory that loads the persisted preference before returning.
  static Future<ThemeNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeKey);
    final mode = saved == 'dark' || saved == 'special'
        ? AppThemeMode.dark
        : AppThemeMode.light;
    return ThemeNotifier._internal(mode);
  }

  /// Toggles between [AppThemeMode.light] and [AppThemeMode.dark].
  Future<void> toggle() async {
    await setMode(
      _mode == AppThemeMode.light ? AppThemeMode.dark : AppThemeMode.light,
    );
  }

  /// Explicitly sets the theme mode and persists the choice.
  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, mode.name);
  }
}
