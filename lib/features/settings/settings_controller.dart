import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/haptics.dart';

/// Ville choisie pour la météo.
class WeatherLocation {
  final String name;
  final String? region;
  final double latitude;
  final double longitude;

  const WeatherLocation({required this.name, this.region, required this.latitude, required this.longitude});

  String get label => region == null || region!.isEmpty ? name : '$name, $region';

  Map<String, dynamic> toJson() => {'name': name, 'region': region, 'lat': latitude, 'lon': longitude};

  static WeatherLocation? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return WeatherLocation(
      name: json['name'] as String? ?? '',
      region: json['region'] as String?,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
    );
  }
}

/// Cartes de l'écran d'accueil, dans leur ordre d'affichage.
enum HomeCard {
  weather('Météo', Icons.wb_sunny_rounded),
  spotify('Spotify', Icons.music_note_rounded),
  agenda('Agenda', Icons.event_rounded),
  expenses('Prochains prélèvements', Icons.account_balance_wallet_rounded),
  discord('Discord', Icons.person_rounded);

  const HomeCard(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Préférences de l'utilisateur, persistées localement.
class SettingsController extends ChangeNotifier {
  static const defaultAccent = Color(0xFF1DB954);

  Color _accent = defaultAccent;
  String? _backgroundImage;
  double _backgroundDim = 0.45;
  double _backgroundBlur = 0;
  bool _haptics = true;
  bool _use24h = true;
  WeatherLocation? _weather;
  Set<HomeCard> _hiddenCards = {};

  Color get accent => _accent;
  String? get backgroundImage => _backgroundImage;
  double get backgroundDim => _backgroundDim;
  double get backgroundBlur => _backgroundBlur;
  bool get haptics => _haptics;
  bool get use24h => _use24h;
  WeatherLocation? get weather => _weather;
  bool isVisible(HomeCard card) => !_hiddenCards.contains(card);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final color = prefs.getInt('theme_accent_color');
    _accent = color != null ? Color(color) : defaultAccent;
    _backgroundImage = prefs.getString('theme_bg_image');
    _backgroundDim = prefs.getDouble('theme_bg_dim') ?? 0.45;
    _backgroundBlur = prefs.getDouble('theme_bg_blur') ?? 0;
    _haptics = prefs.getBool('haptics') ?? true;
    _use24h = prefs.getBool('clock_24h') ?? true;
    Haptics.enabled = _haptics;
    final weather = prefs.getString('weather_location');
    _weather = null;
    if (weather != null) {
      try {
        _weather = WeatherLocation.fromJson(jsonDecode(weather) as Map<String, dynamic>);
      } catch (_) {}
    }
    _hiddenCards = (prefs.getStringList('home_hidden_cards') ?? [])
        .map((n) => HomeCard.values.where((c) => c.name == n).firstOrNull)
        .whereType<HomeCard>()
        .toSet();
    notifyListeners();
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> setAccent(Color color) async {
    _accent = color;
    notifyListeners();
    await (await _prefs).setInt('theme_accent_color', color.toARGB32());
  }

  Future<void> setBackgroundImage(String? path) async {
    _backgroundImage = path;
    notifyListeners();
    final prefs = await _prefs;
    if (path == null) {
      await prefs.remove('theme_bg_image');
    } else {
      await prefs.setString('theme_bg_image', path);
    }
  }

  void setBackgroundDim(double value) {
    _backgroundDim = value;
    notifyListeners();
  }

  void setBackgroundBlur(double value) {
    _backgroundBlur = value;
    notifyListeners();
  }

  /// Enregistre l'assombrissement et le flou une fois le curseur relâché.
  Future<void> persistBackgroundEffects() async {
    final prefs = await _prefs;
    await prefs.setDouble('theme_bg_dim', _backgroundDim);
    await prefs.setDouble('theme_bg_blur', _backgroundBlur);
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    Haptics.enabled = value;
    notifyListeners();
    await (await _prefs).setBool('haptics', value);
  }

  Future<void> setUse24h(bool value) async {
    _use24h = value;
    notifyListeners();
    await (await _prefs).setBool('clock_24h', value);
  }

  Future<void> setWeather(WeatherLocation? location) async {
    _weather = location;
    notifyListeners();
    final prefs = await _prefs;
    if (location == null) {
      await prefs.remove('weather_location');
    } else {
      await prefs.setString('weather_location', jsonEncode(location.toJson()));
    }
  }

  Future<void> setCardVisible(HomeCard card, bool visible) async {
    visible ? _hiddenCards.remove(card) : _hiddenCards.add(card);
    notifyListeners();
    await (await _prefs).setStringList('home_hidden_cards', _hiddenCards.map((c) => c.name).toList());
  }
}
