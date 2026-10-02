import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  Color _accentColor = const Color(0xFF1DB954); // Vert par défaut
  String? _backgroundImagePath;

  Color get accentColor => _accentColor;
  String? get backgroundImagePath => _backgroundImagePath;

  ThemeNotifier() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    int? colorValue = prefs.getInt('theme_accent_color');
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }

    _backgroundImagePath = prefs.getString('theme_bg_image');
    
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_accent_color', color.toARGB32());
  }

  Future<void> setBackgroundImage(String? path) async {
    _backgroundImagePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('theme_bg_image');
    } else {
      await prefs.setString('theme_bg_image', path);
    }
  }
}

// Instance globale du thème
final ThemeNotifier themeNotifier = ThemeNotifier();
