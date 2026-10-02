import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Export / import des données locales au format JSON. Les jetons de
/// connexion (Spotify, Google, Discord) ne sont jamais exportés.
class BackupService {
  static const format = 'panel-backup';
  static const version = 1;

  /// Clés sauvegardées : données et préférences, sans les jetons.
  static const keys = [
    'saved_subscriptions',
    'saved_links',
    'soundboard_items',
    'soundboard_volume',
    'theme_accent_color',
    'theme_bg_dim',
    'theme_bg_blur',
    'haptics',
    'clock_24h',
    'weather_location',
    'home_hidden_cards',
    'wifi_ssid',
    'wifi_password',
    'wifi_security',
  ];

  /// Clés effacées par la réinitialisation (préférences d'affichage incluses).
  static const resettableKeys = [...keys, 'theme_bg_image'];

  Future<String> export() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object>{};
    for (final key in keys) {
      final value = prefs.get(key);
      if (value != null) data[key] = value;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Restaure une sauvegarde. Renvoie le nombre d'éléments restaurés, ou
  /// lève une [FormatException] si le texte n'est pas une sauvegarde valide.
  Future<int> import(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw.trim());
    } catch (_) {
      throw const FormatException('Ce texte n\'est pas une sauvegarde Panel.');
    }
    if (decoded is! Map || decoded['format'] != format || decoded['data'] is! Map) {
      throw const FormatException('Ce texte n\'est pas une sauvegarde Panel.');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    final prefs = await SharedPreferences.getInstance();
    var count = 0;
    for (final entry in data.entries) {
      if (!keys.contains(entry.key)) continue;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(entry.key, value.map((e) => e.toString()).toList());
      } else {
        continue;
      }
      count++;
    }
    return count;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in resettableKeys) {
      await prefs.remove(key);
    }
  }
}
