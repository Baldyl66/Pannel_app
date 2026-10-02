import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panel_app/app/app.dart';
import 'package:panel_app/app/app_scope.dart';
import 'package:panel_app/core/utils/formatters.dart';
import 'package:panel_app/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pumpApp(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(412, 915) * 2.625;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final state = AppState();
  await state.load();
  await tester.pumpWidget(PanelApp(state: state));
  await tester.pump(const Duration(milliseconds: 100));
  return state;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    dotenv.loadFromString(envString: 'TEST_VAR=test');
  });

  testWidgets('démarre sur l\'accueil avec la navigation et les cartes de connexion', (tester) async {
    await _pumpApp(tester);

    expect(find.text(greetingFor(DateTime.now())), findsWidgets);
    for (final label in ['Accueil', 'Dépenses', 'Sons', 'Liens']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Google Agenda'), findsOneWidget);
    expect(find.text('Météo'), findsOneWidget);
  });

  testWidgets('Dépenses : état vide puis validation du formulaire', (tester) async {
    final state = await _pumpApp(tester);
    addTearDown(() => expect(state.subscriptions.count, 1));
    await _openTab(tester, 'Dépenses');
    expect(find.text('Suivez vos abonnements'), findsOneWidget);

    await tester.tap(find.text('Ajouter un abonnement'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel abonnement'), findsOneWidget);

    final submit = find.text('Ajouter l\'abonnement');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Montant invalide'), findsOneWidget);

    // Une suggestion pré-remplit le nom.
    final chip = find.widgetWithText(ActionChip, 'Netflix');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.enterText(find.widgetWithText(TextFormField, 'Montant'), '13,49');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(formatEuro(13.49)), findsWidgets);
  });

  testWidgets('Dépenses : synthèse et répartition par catégorie', (tester) async {
    final state = await _pumpApp(tester, {
      'saved_subscriptions': '[{"id":"1","name":"Netflix","price":13.49,"category":"streaming"},'
          '{"id":"2","name":"Spotify","price":11.12,"category":"music"},'
          '{"id":"3","name":"Domaine","price":60,"cycle":"yearly","category":"cloud"}]',
    });
    await _openTab(tester, 'Dépenses');

    expect(find.text(formatEuro(29.61)), findsOneWidget);
    expect(find.text('${formatEuroRound(355.32)} / an'), findsOneWidget);
    final legend = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'CategoryLegend');
    expect(find.descendant(of: legend, matching: find.text('Streaming')), findsOneWidget);

    // Toucher une catégorie de la légende filtre la liste.
    await tester.tap(find.descendant(of: legend, matching: find.text('Musique')));
    await tester.pumpAndSettle();
    expect(state.subscriptions.visible.single.name, 'Spotify');
  });

  testWidgets('Liens : la recherche filtre la grille', (tester) async {
    await _pumpApp(tester, {
      'saved_links': '[{"id":"1","title":"YouTube","url":"https://youtube.com"},{"id":"2","title":"GitHub","url":"https://github.com"}]',
    });
    await _openTab(tester, 'Liens');
    expect(find.text('YouTube'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'git');
    await tester.pumpAndSettle();
    expect(find.text('YouTube'), findsNothing);
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('Paramètres : apparence et roue de couleurs', (tester) async {
    final state = await _pumpApp(tester);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Comptes connectés'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Apparence'));
    await tester.pumpAndSettle();
    expect(find.text('APERÇU'), findsOneWidget);

    await tester.tap(find.text('Choisir sur la roue des couleurs'));
    await tester.pumpAndSettle();
    expect(find.text('Utiliser cette couleur'), findsOneWidget);
    await tester.tap(find.text('Utiliser cette couleur'));
    await tester.pumpAndSettle();
    expect(state.settings.accent.toARGB32(), isNot(0));
  });

  testWidgets('Paramètres : masquer une carte de l\'accueil', (tester) async {
    final state = await _pumpApp(tester);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Écran d\'accueil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Météo'));
    await tester.pumpAndSettle();
    expect(state.settings.isVisible(HomeCard.weather), isFalse);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Météo'), findsNothing);
  });
}
