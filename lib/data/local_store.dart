import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lecture / écriture d'une liste d'objets JSON dans SharedPreferences.
class JsonListStore<T> {
  final String key;
  final T Function(Map<String, dynamic>) fromJson;
  final Object? Function(T) toJson;

  const JsonListStore({required this.key, required this.fromJson, required this.toJson});

  Future<List<T>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      // Données corrompues : on repart d'une liste vide plutôt que de planter.
      debugPrint('Lecture impossible de "$key" : $e');
      return [];
    }
  }

  Future<void> save(List<T> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items.map(toJson).toList()));
  }
}
