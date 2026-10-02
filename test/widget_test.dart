import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panel_app/core/utils/formatters.dart';
import 'package:panel_app/data/models/models.dart';
import 'package:panel_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    dotenv.loadFromString(envString: 'TEST_VAR=test');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('L\'application démarre sur le Panel avec la navigation', (tester) async {
    await tester.pumpWidget(const PanelApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(greetingFor(DateTime.now())), findsOneWidget);
    for (final label in ['Panel', 'Dépenses', 'Sons', 'Liens']) {
      expect(find.text(label), findsOneWidget);
    }
    // Aucun compte connecté : les cartes de connexion sont proposées.
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Discord'), findsOneWidget);
  });

  testWidgets('L\'onglet Dépenses affiche un état vide puis le formulaire', (tester) async {
    await tester.pumpWidget(const PanelApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Dépenses'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun abonnement'), findsOneWidget);

    await tester.tap(find.text('Ajouter un abonnement'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel abonnement'), findsOneWidget);

    // Validation : nom et prix requis.
    await tester.tap(find.text('Ajouter l\'abonnement'));
    await tester.pumpAndSettle();
    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Prix invalide'), findsOneWidget);
  });

  testWidgets('Les abonnements enregistrés sont totalisés', (tester) async {
    SharedPreferences.setMockInitialValues({
      'saved_subscriptions':
          '[{"id":"1","name":"Netflix","price":13.49},{"id":"2","name":"Spotify","price":11}]',
    });
    await tester.pumpWidget(const PanelApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Dépenses'));
    await tester.pumpAndSettle();

    expect(find.text(formatEuro(24.49)), findsOneWidget);
    expect(find.text(formatEuro(24.49 * 12)), findsOneWidget);
    expect(find.text('2 ABONNEMENTS ACTIFS'), findsOneWidget);
  });

  group('Formatage', () {
    test('parsePrice accepte virgule, point et symbole €', () {
      expect(parsePrice('12,99'), 12.99);
      expect(parsePrice('12.99'), 12.99);
      expect(parsePrice(' 7,5 € '), 7.5);
      expect(parsePrice('abc'), isNull);
    });

    test('normalizeUrl et displayHost', () {
      expect(normalizeUrl('youtube.com'), 'https://youtube.com');
      expect(normalizeUrl('http://a.fr'), 'http://a.fr');
      expect(displayHost('https://www.youtube.com/watch?v=1'), 'youtube.com');
    });

    test('formatRelativeDay', () {
      final now = DateTime(2026, 10, 2, 9);
      expect(formatRelativeDay(now, now: now), "Aujourd'hui");
      expect(formatRelativeDay(DateTime(2026, 10, 3), now: now), 'Demain');
      expect(formatRelativeDay(DateTime(2026, 10, 1), now: now), 'Hier');
    });
  });

  group('Modèles', () {
    test('Subscription accepte un prix entier et ignore clearbit', () {
      final sub = Subscription.fromJson({
        'id': '1',
        'name': 'X',
        'price': 10,
        'imagePath': 'https://logo.clearbit.com/x.com',
      });
      expect(sub.price, 10.0);
      expect(sub.imagePath, isNull);
    });

    test('LinkItem conserve le format historique', () {
      const link = LinkItem(title: 'A', url: 'https://a.fr');
      expect(link.toJson(), {'title': 'A', 'url': 'https://a.fr', 'imageUrl': ''});
      expect(LinkItem.fromJson(link.toJson()).hasImage, isFalse);
    });

    test('SoundItem aller-retour JSON', () {
      const sound = SoundItem(id: '1', name: 'Clap', path: '/a.mp3', colorValue: 0xFFFF0000);
      final back = SoundItem.fromJson(sound.toJson());
      expect(back.name, 'Clap');
      expect(back.colorValue, 0xFFFF0000);
    });
  });

  testWidgets('Le thème suit la couleur d\'accent', (tester) async {
    await tester.pumpWidget(const PanelApp());
    await tester.pump(const Duration(milliseconds: 100));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, const Color(0xFF1DB954));
  });
}
