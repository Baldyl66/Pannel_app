import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

final NumberFormat _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

/// 12.5 → « 12,50 € »
String formatEuro(double amount) => _euro.format(amount);

/// Accepte « 12,99 », « 12.99 » ou « 12,99 € ».
double? parsePrice(String input) {
  final cleaned = input.replaceAll('€', '').replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

/// Ajoute https:// si l'utilisateur l'a omis.
String normalizeUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  return 'https://$trimmed';
}

/// « https://www.youtube.com/watch?v=… » → « youtube.com »
String displayHost(String url) {
  final host = Uri.tryParse(normalizeUrl(url))?.host ?? url;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Image distante (http) ou locale (chemin de fichier).
ImageProvider imageProviderFor(String path) {
  return path.startsWith('http') ? NetworkImage(path) : FileImage(File(path)) as ImageProvider;
}

/// « Bonjour », « Bon après-midi » ou « Bonsoir » selon l'heure.
String greetingFor(DateTime now) {
  if (now.hour >= 5 && now.hour < 12) return 'Bonjour';
  if (now.hour >= 12 && now.hour < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// « Jeudi 2 octobre »
String formatLongDate(DateTime date) => _capitalize(DateFormat('EEEE d MMMM', 'fr_FR').format(date));

/// « Aujourd'hui », « Demain », « Hier » ou « Lun. 6 oct. »
String formatRelativeDay(DateTime date, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  return _capitalize(DateFormat('EEE d MMM', 'fr_FR').format(date));
}
