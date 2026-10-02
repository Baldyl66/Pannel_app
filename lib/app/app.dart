import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import 'app_scope.dart';
import 'shell.dart';

class PanelApp extends StatefulWidget {
  /// État déjà chargé (fourni par `main` ou par les tests).
  final AppState? state;
  const PanelApp({super.key, this.state});

  @override
  State<PanelApp> createState() => _PanelAppState();
}

class _PanelAppState extends State<PanelApp> {
  late final AppState _state = widget.state ?? (AppState()..load());

  @override
  void dispose() {
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state.settings,
        builder: (context, _) => MaterialApp(
          title: 'Panel',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(_state.settings.accent),
          themeMode: ThemeMode.dark,
          themeAnimationDuration: const Duration(milliseconds: 350),
          locale: const Locale('fr', 'FR'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
          home: const AppShell(),
        ),
      ),
    );
  }
}
