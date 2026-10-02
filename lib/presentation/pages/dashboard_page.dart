import 'package:flutter/material.dart';
import '../widgets/spotify_player_widget.dart';
import '../widgets/discord_widget.dart';
import '../widgets/calendar_widget.dart';
import 'subscriptions_tab.dart';
import 'settings_page.dart';
import 'soundboard_tab.dart';
import 'links_tab.dart';
import '../../services/theme_service.dart';
import 'dart:io';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        final bgPath = themeNotifier.backgroundImagePath;

        // Les deux pages principales du BottomNavigationBar
        final List<Widget> pages = [
      // Page 1 : Panel (Spotify + Discord)
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Pour centrer le titre
                  const Text('Panel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white54),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SpotifyPlayerWidget(),
              SizedBox(height: 16),
              DiscordWidget(),
              SizedBox(height: 16),
              CalendarWidget(),
            ],
          ),
        ),
      ),
      // Page 2 : Abonnements
      const SubscriptionsTab(),
      // Page 3 : Soundboard
      const SoundboardTab(),
      // Page 4 : Liens
      const LinksTab(),
    ];

        return Scaffold(
          backgroundColor: bgPath != null ? Colors.transparent : const Color(0xFF000000),
          extendBody: true,
          body: Stack(
            children: [
              if (bgPath != null)
                Positioned.fill(
                  child: Image.file(
                    File(bgPath),
                    fit: BoxFit.cover,
                  ),
                ),
              if (bgPath != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ],
          ),
          bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white10, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: bgPath != null ? Colors.black.withValues(alpha: 0.6) : const Color(0xFF000000),
          selectedItemColor: Colors.white, // White instead of Green for Pro look
          unselectedItemColor: Colors.white30,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.grid_view_rounded),
              ),
              label: 'Panel',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.account_balance_wallet_rounded),
              ),
              label: 'Dépenses',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.grid_on_rounded),
              ),
              label: 'Sons',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.language_rounded),
              ),
              label: 'Liens',
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}



