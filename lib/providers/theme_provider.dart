import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AccentColor _accentColor = AccentColor.red;

  AccentColor get accentColor => _accentColor;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccent = prefs.getString('accent_color');
    if (savedAccent != null) {
      _accentColor = AccentColor.values.firstWhere(
        (c) => c.name == savedAccent,
        orElse: () => AccentColor.red,
      );
    }
    notifyListeners();
  }

  Future<void> setAccentColor(AccentColor color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', color.name);
    notifyListeners();
  }
}
