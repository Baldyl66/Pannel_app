import 'package:flutter/widgets.dart';
import '../features/links/links_controller.dart';
import '../features/settings/settings_controller.dart';
import '../features/soundboard/soundboard_controller.dart';
import '../features/subscriptions/subscriptions_controller.dart';

/// Regroupe les contrôleurs partagés par toute l'application.
class AppState {
  final settings = SettingsController();
  final subscriptions = SubscriptionsController();
  final links = LinksController();
  final soundboard = SoundboardController();

  /// Incrémenté à chaque connexion / déconnexion d'un compte : les cartes de
  /// l'accueil s'en servent comme clé pour se recharger sans redémarrage.
  final accountsRevision = ValueNotifier<int>(0);

  /// Onglet affiché par la barre de navigation.
  final tab = ValueNotifier<int>(0);

  void notifyAccountsChanged() => accountsRevision.value++;

  Future<void> load() => Future.wait([
        settings.load(),
        subscriptions.load(),
        links.load(),
        soundboard.load(),
      ]);

  void dispose() {
    settings.dispose();
    subscriptions.dispose();
    links.dispose();
    soundboard.dispose();
    accountsRevision.dispose();
    tab.dispose();
  }
}

/// Rend [AppState] accessible partout via `context.app`.
class AppScope extends InheritedWidget {
  final AppState state;
  const AppScope({super.key, required this.state, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope introuvable');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
}
