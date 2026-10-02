import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'presentation/pages/dashboard_page.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const PanelApp());
}

class PanelApp extends StatelessWidget {
  const PanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'Panel App',
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF000000), // Pure Black OLED
            colorScheme: ColorScheme.dark(
              primary: Colors.white,
              secondary: themeNotifier.accentColor, // Accents only
            ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF151515),
          headerBackgroundColor: const Color(0xFF111111),
          headerForegroundColor: Colors.white,
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled)) return Colors.white24;
            return Colors.white70;
          }),
          todayForegroundColor: const WidgetStatePropertyAll(Color(0xFF4285F4)),
          todayBorder: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          cancelButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white54),
          confirmButtonStyle: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4285F4), 
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFF151515),
          dialBackgroundColor: const Color(0xFF111111),
          dialHandColor: const Color(0xFF4285F4),
          dialTextColor: Colors.white,
          entryModeIconColor: Colors.white54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          hourMinuteColor: const Color(0xFF111111),
          hourMinuteTextColor: Colors.white,
          cancelButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white54),
          confirmButtonStyle: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4285F4), 
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
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
      debugShowCheckedModeBanner: false,
    );
      },
    );
  }
}
