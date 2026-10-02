import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/dashboard_page.dart';
import 'services/theme_service.dart';

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
  runApp(const PanelApp());
}

class PanelApp extends StatelessWidget {
  const PanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) => MaterialApp(
        title: 'Panel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(themeNotifier.accentColor),
        themeMode: ThemeMode.dark,
        locale: const Locale('fr', 'FR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('en', 'US'),
        ],
        home: const DashboardPage(),
      ),
    );
  }
}
