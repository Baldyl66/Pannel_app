import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

final NumberFormat _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);
final NumberFormat _euroRound = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

/// 12.5 → « 12,50 € »
String formatEuro(double amount) => _euro.format(amount);

/// 1250.4 → « 1 250 € »
String formatEuroRound(double amount) => _euroRound.format(amount);

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

/// Favicon haute définition d'un site.
String faviconUrl(String url) =>
    'https://www.google.com/s2/favicons?sz=128&domain=${Uri.encodeComponent(displayHost(url))}';

/// « Netflix » → « N », « Amazon Prime » → « AP »
String initialsOf(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return (words[0].characters.first + words[1].characters.first).toUpperCase();
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

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// « Jeudi 2 octobre »
String formatLongDate(DateTime date) => capitalize(DateFormat('EEEE d MMMM', 'fr_FR').format(date));

/// « 12 oct. »
String formatShortDate(DateTime date) => DateFormat('d MMM', 'fr_FR').format(date);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// « Aujourd'hui », « Demain », « Hier » ou « Lun. 6 oct. »
String formatRelativeDay(DateTime date, {DateTime? now}) {
  final diff = dateOnly(date).difference(dateOnly(now ?? DateTime.now())).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  return capitalize(DateFormat('EEE d MMM', 'fr_FR').format(date));
}

/// « Aujourd'hui », « Demain », « Dans 5 jours », « Dans 3 sem. »
String formatDaysUntil(DateTime date, {DateTime? now}) {
  final diff = dateOnly(date).difference(dateOnly(now ?? DateTime.now())).inDays;
  if (diff <= 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff < 14) return 'Dans $diff jours';
  if (diff < 60) return 'Dans ${(diff / 7).round()} sem.';
  return 'Le ${formatShortDate(date)}';
}
