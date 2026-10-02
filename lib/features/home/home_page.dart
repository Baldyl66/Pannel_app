import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_page.dart';
import '../calendar/calendar_card.dart';
import '../discord/discord_card.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../spotify/spotify_card.dart';
import '../weather/weather_card.dart';
import 'widgets/expenses_card.dart';

/// Accueil : horloge et cartes (météo, Spotify, agenda, dépenses, Discord).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.accountsRevision]),
      builder: (context, _) {
        final settings = app.settings;
        final revision = app.accountsRevision.value;
        final now = DateTime.now();

        Widget? cardFor(HomeCard card) {
          if (!settings.isVisible(card)) return null;
          return switch (card) {
            HomeCard.weather => WeatherCard(key: ValueKey('weather-$revision'), location: settings.weather),
            HomeCard.spotify => SpotifyCard(key: ValueKey('spotify-$revision'), onAccountChanged: app.notifyAccountsChanged),
            HomeCard.agenda => CalendarCard(key: ValueKey('agenda-$revision')),
            HomeCard.expenses => const ExpensesCard(key: ValueKey('expenses')),
            HomeCard.discord => DiscordCard(key: ValueKey('discord-$revision'), onAccountChanged: app.notifyAccountsChanged),
          };
        }

        final cards = HomeCard.values.map(cardFor).whereType<Widget>().toList();

        return AppPage(
          title: greetingFor(now),
          overline: formatLongDate(now),
          inShell: true,
          onRefresh: () async {
            app.notifyAccountsChanged();
            await Future<void>.delayed(const Duration(milliseconds: 700));
          },
          actions: [
            IconButton(
              tooltip: 'Paramètres',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
          ],
          slivers: [
            SliverToBoxAdapter(child: _Clock(use24h: settings.use24h)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList.separated(
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => cards[i],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Grande horloge mise à jour à chaque minute.
class _Clock extends StatefulWidget {
  final bool use24h;
  const _Clock({required this.use24h});

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = widget.use24h ? _now.hour : (_now.hour % 12 == 0 ? 12 : _now.hour % 12);
    final time = '${widget.use24h ? hour.toString().padLeft(2, '0') : hour}:${_now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            time,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 76,
              fontWeight: FontWeight.w300,
              letterSpacing: -4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!widget.use24h) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(_now.hour < 12 ? 'AM' : 'PM', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }
}
