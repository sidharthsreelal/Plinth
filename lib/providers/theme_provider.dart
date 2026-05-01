import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plinth/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AccentColor _accentColor = AccentColor.red;
  String _sortOrderKey = 'trackNumber';

  AccentColor get accentColor => _accentColor;

  /// The persisted sort order key. FolderBrowserScreen reads this string
  /// and converts it to its private _SortOrder enum in _sortOrderFromKey().
  String get defaultSortOrderKey => _sortOrderKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final savedAccent = prefs.getString('accent_color');
    if (savedAccent != null) {
      _accentColor = AccentColor.values.firstWhere(
        (c) => c.name == savedAccent,
        orElse: () => AccentColor.red,
      );
    }

    _sortOrderKey = prefs.getString('default_sort_order') ?? 'trackNumber';
    notifyListeners();
  }

  Future<void> setAccentColor(AccentColor color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', color.name);
    notifyListeners();
  }

  /// Called by FolderBrowserScreen when the user changes sort order.
  /// [sortOrderName] is the .name string of the _SortOrder enum value.
  Future<void> setDefaultSortOrder(dynamic sortOrder) async {
    _sortOrderKey = (sortOrder as Enum).name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_sort_order', _sortOrderKey);
    notifyListeners();
  }
}
