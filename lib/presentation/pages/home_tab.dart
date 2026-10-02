import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../services/theme_service.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/common/page_header.dart';
import '../widgets/discord_widget.dart';
import '../widgets/spotify_player_widget.dart';

/// Onglet d'accueil : Spotify, Discord et Agenda.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _refresh() async {
    notifyAccountsChanged();
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<int>(
        valueListenable: accountsRevision,
        builder: (context, revision, _) {
          // La clé change à chaque (dé)connexion → les widgets se rechargent.
          final spotify = SpotifyPlayerWidget(key: ValueKey('spotify-$revision'));
          final discord = DiscordWidget(key: ValueKey('discord-$revision'));
          final calendar = CalendarWidget(key: ValueKey('calendar-$revision'));

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 900;
                return ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    ContentWidth(
                      maxWidth: twoColumns ? 1200 : AppSpacing.maxContentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PageHeader(title: greetingFor(now), subtitle: formatLongDate(now)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: twoColumns
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [spotify, const SizedBox(height: AppSpacing.lg), discord],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.lg),
                                      Expanded(child: calendar),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      spotify,
                                      const SizedBox(height: AppSpacing.lg),
                                      calendar,
                                      const SizedBox(height: AppSpacing.lg),
                                      discord,
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
