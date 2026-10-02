import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panel_app/core/utils/formatters.dart';
import 'package:panel_app/features/links/links_controller.dart';
import 'package:panel_app/features/settings/backup_service.dart';
import 'package:panel_app/features/settings/settings_controller.dart';
import 'package:panel_app/features/settings/wifi_page.dart';
import 'package:panel_app/features/soundboard/soundboard_controller.dart';
import 'package:panel_app/features/subscriptions/subscription.dart';
import 'package:panel_app/features/subscriptions/subscriptions_controller.dart';
import 'package:panel_app/features/weather/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Formatage', () {
    test('parsePrice accepte virgule, point et symbole €', () {
      expect(parsePrice('12,99'), 12.99);
      expect(parsePrice('12.99'), 12.99);
      expect(parsePrice(' 7,5 € '), 7.5);
      expect(parsePrice('abc'), isNull);
    });

    test('URL et domaine', () {
      expect(normalizeUrl('youtube.com'), 'https://youtube.com');
      expect(normalizeUrl('http://a.fr'), 'http://a.fr');
      expect(displayHost('https://www.youtube.com/watch?v=1'), 'youtube.com');
    });

    test('initiales', () {
      expect(initialsOf('Netflix'), 'N');
      expect(initialsOf('amazon prime video'), 'AP');
      expect(initialsOf('  '), '');
    });

    test('dates relatives', () {
      final now = DateTime(2026, 10, 2, 9);
      expect(formatRelativeDay(now, now: now), "Aujourd'hui");
      expect(formatRelativeDay(DateTime(2026, 10, 3), now: now), 'Demain');
      expect(formatDaysUntil(DateTime(2026, 10, 7), now: now), 'Dans 5 jours');
      expect(formatDaysUntil(DateTime(2026, 10, 30), now: now), 'Dans 4 sem.');
    });
  });

  group('Abonnements', () {
    test('équivalent mensuel selon la fréquence', () {
      expect(const Subscription(id: '1', name: 'A', price: 120, cycle: BillingCycle.yearly).monthlyPrice, 10);
      expect(const Subscription(id: '1', name: 'A', price: 30, cycle: BillingCycle.quarterly).monthlyPrice, 10);
      expect(const Subscription(id: '1', name: 'A', price: 12, cycle: BillingCycle.weekly).monthlyPrice, closeTo(52, 0.001));
    });

    test('prochain prélèvement mensuel, y compris en fin de mois', () {
      final sub = Subscription(id: '1', name: 'A', price: 10, billingDate: DateTime(2026, 1, 31));
      expect(sub.nextPayment(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
      expect(sub.nextPayment(DateTime(2026, 1, 31)), DateTime(2026, 1, 31));
    });

    test('prochain prélèvement annuel et sans date', () {
      final yearly = Subscription(id: '1', name: 'A', price: 10, cycle: BillingCycle.yearly, billingDate: DateTime(2024, 3, 15));
      expect(yearly.nextPayment(DateTime(2026, 10, 2)), DateTime(2027, 3, 15));
      expect(const Subscription(id: '2', name: 'B', price: 1).nextPayment(), isNull);
    });

    test('lecture des anciennes données (prix entier, sans fréquence, logo clearbit)', () {
      final sub = Subscription.fromJson({'id': '1', 'name': 'X', 'price': 10, 'imagePath': 'https://logo.clearbit.com/x.com'});
      expect(sub.price, 10.0);
      expect(sub.cycle, BillingCycle.monthly);
      expect(sub.category, SubscriptionCategory.other);
      expect(sub.imagePath, isNull);
    });

    test('contrôleur : totaux, catégories, tri, prochains prélèvements', () async {
      final c = SubscriptionsController();
      await c.load();
      final now = DateTime.now();
      await c.save(Subscription(id: 'a', name: 'Netflix', price: 13.49, category: SubscriptionCategory.streaming, billingDate: now.add(const Duration(days: 10))));
      await c.save(Subscription(id: 'b', name: 'Spotify', price: 11.12, category: SubscriptionCategory.music, billingDate: now.add(const Duration(days: 2))));
      await c.save(const Subscription(id: 'c', name: 'Domaine', price: 60, cycle: BillingCycle.yearly, category: SubscriptionCategory.cloud));

      expect(c.monthlyTotal, closeTo(29.61, 0.001));
      expect(c.yearlyTotal, closeTo(355.32, 0.001));
      expect(c.monthlyByCategory.keys, [SubscriptionCategory.streaming, SubscriptionCategory.music, SubscriptionCategory.cloud]);
      expect(c.visible.map((s) => s.id), ['a', 'b', 'c']);
      expect(c.upcoming().map((e) => e.$1.id), ['b', 'a']);

      c.setSort(SubscriptionSort.name);
      expect(c.visible.map((s) => s.name), ['Domaine', 'Netflix', 'Spotify']);
      c.setFilter(SubscriptionCategory.music);
      expect(c.visible.map((s) => s.id), ['b']);

      final index = await c.remove(c.all.firstWhere((s) => s.id == 'b'));
      expect(c.filter, isNull, reason: 'le filtre vide est retiré');
      final reloaded = SubscriptionsController();
      await reloaded.load();
      expect(reloaded.count, 2);
      await c.restore(const Subscription(id: 'b', name: 'Spotify', price: 11.12), index);
      expect(c.count, 3);
    });
  });

  group('Liens', () {
    test('recherche, groupes et réorganisation', () async {
      final c = LinksController();
      await c.load();
      await c.save(LinkItem(id: '1', title: 'YouTube', url: 'https://youtube.com', group: 'Vidéo'));
      await c.save(LinkItem(id: '2', title: 'GitHub', url: 'https://github.com', group: 'Travail'));
      await c.save(LinkItem(id: '3', title: 'Le Monde', url: 'https://lemonde.fr'));

      expect(c.groups, ['Travail', 'Vidéo']);
      c.setQuery('git');
      expect(c.visible.map((l) => l.id), ['2']);
      c.setQuery('');
      c.setGroup('Vidéo');
      expect(c.visible.map((l) => l.id), ['1']);
      c.setGroup('Vidéo');
      expect(c.group, isNull);

      await c.reorder(2, 0);
      expect(c.all.map((l) => l.id), ['3', '1', '2']);
    });

    test('format historique conservé', () {
      final link = LinkItem.fromJson({'title': 'A', 'url': 'https://a.fr', 'imageUrl': ''});
      expect(link.hasImage, isFalse);
      expect(link.group, isNull);
      expect(link.toJson()['url'], 'https://a.fr');
    });
  });

  group('Sons', () {
    test('valeurs par défaut des anciens sons', () {
      final sound = SoundItem.fromJson({'id': '1', 'name': 'Clap', 'path': '/a.mp3', 'colorValue': 0xFFFF0000});
      expect(sound.volume, 1);
      expect(sound.loop, isFalse);
      expect(sound.iconData, soundIcons['volume']);
      expect(SoundItem.fromJson(sound.toJson()).name, 'Clap');
    });
  });

  group('Sauvegarde', () {
    test('export puis import, sans les jetons de connexion', () async {
      SharedPreferences.setMockInitialValues({
        'saved_links': '[{"title":"A","url":"https://a.fr"}]',
        'theme_accent_color': 0xFF0A84FF,
        'home_hidden_cards': ['discord'],
        'spotify_token': 'secret',
      });
      final json = await BackupService().export();
      expect(json, isNot(contains('secret')));

      SharedPreferences.setMockInitialValues({});
      final count = await BackupService().import(json);
      expect(count, 3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_accent_color'), 0xFF0A84FF);
      expect(prefs.getStringList('home_hidden_cards'), ['discord']);
    });

    test('refuse un texte qui n\'est pas une sauvegarde', () async {
      expect(() => BackupService().import('bonjour'), throwsFormatException);
      expect(() => BackupService().import('{"a":1}'), throwsFormatException);
    });

    test('réinitialisation : les réglages reviennent aux valeurs par défaut', () async {
      SharedPreferences.setMockInitialValues({'theme_accent_color': 0xFF0A84FF, 'clock_24h': false});
      final settings = SettingsController();
      await settings.load();
      expect(settings.use24h, isFalse);
      await BackupService().reset();
      await settings.load();
      expect(settings.accent, SettingsController.defaultAccent);
      expect(settings.use24h, isTrue);
    });
  });

  test('QR code Wi-Fi : caractères spéciaux échappés', () {
    expect(
      wifiQrData(ssid: 'Box;1', password: 'a:b,c', security: 'WPA'),
      r'WIFI:T:WPA;S:Box\;1;P:a\:b\,c;;',
    );
    expect(wifiQrData(ssid: 'Libre', password: 'ignoré', security: 'nopass'), 'WIFI:T:nopass;S:Libre;P:;;');
  });

  group('Météo', () {
    test('lecture d\'une réponse Open-Meteo', () async {
      final now = DateTime.now();
      String hour(int h) => DateTime(now.year, now.month, now.day, now.hour + h).toIso8601String().substring(0, 16);
      final client = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        return http.Response(
          jsonEncode({
            'current': {'temperature_2m': 18.4, 'apparent_temperature': 17.1, 'weather_code': 61, 'is_day': 1, 'wind_speed_10m': 12.0},
            'hourly': {
              'time': [hour(-2), hour(0), hour(1), hour(2)],
              'temperature_2m': [15.0, 18.0, 19.0, 20.0],
              'weather_code': [0, 61, 3, 0],
            },
            'daily': {
              'temperature_2m_max': [21.0, 22.0],
              'temperature_2m_min': [11.0, 12.0],
              'precipitation_probability_max': [70, 10],
            },
          }),
          200,
        );
      });
      final data = await WeatherService(client).fetch(const WeatherLocation(name: 'Lyon', latitude: 45.75, longitude: 4.85));
      expect(data.temperature, 18.4);
      expect(data.condition.label, 'Pluie');
      expect(data.max, 21);
      expect(data.precipitationChance, 70);
      expect(data.hours.map((h) => h.temperature), [18, 19, 20]);
    });

    test('recherche de ville', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'results': [
                {'name': 'Lyon', 'admin1': 'Auvergne-Rhône-Alpes', 'country': 'France', 'latitude': 45.75, 'longitude': 4.85},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final results = await WeatherService(client).searchCity('Lyon');
      expect(results.single.label, 'Lyon, Auvergne-Rhône-Alpes, France');
      expect(await WeatherService(client).searchCity('L'), isEmpty);
    });
  });
}
