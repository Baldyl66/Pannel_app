import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'app/app.dart';
import 'app/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Sans .env l'app démarre quand même ; seules les connexions aux
    // services externes seront indisponibles.
    debugPrint('Fichier .env introuvable : $e');
  }
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');

  // Affichage bord à bord, barres système transparentes.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Les données sont chargées avant le premier affichage : pas de flash
  // de couleur ni d'écran vide au démarrage.
  final state = AppState();
  await state.load();
  runApp(PanelApp(state: state));
}
