import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/theme_service.dart';
import 'home_tab.dart';
import 'links_tab.dart';
import 'soundboard_tab.dart';
import 'subscriptions_tab.dart';

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}

const _destinations = [
  _Destination('Panel', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Destination('Dépenses', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
  _Destination('Sons', Icons.graphic_eq_outlined, Icons.graphic_eq_rounded),
  _Destination('Liens', Icons.bookmarks_outlined, Icons.bookmarks_rounded),
];

/// Coquille principale : navigation en bas sur mobile, rail latéral sur les
/// écrans larges (tablette, desktop).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    HomeTab(),
    SubscriptionsTab(),
    SoundboardTab(),
    LinksTab(),
  ];

  void _select(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final bgPath = themeNotifier.backgroundImagePath;
        final hasBackground = bgPath != null && File(bgPath).existsSync();

        final body = IndexedStack(index: _currentIndex, children: _pages);

        return Scaffold(
          body: Stack(
            children: [
              if (hasBackground) ...[
                Positioned.fill(child: Image.file(File(bgPath), fit: BoxFit.cover)),
                // Voile dégradé pour garder le texte lisible sur n'importe quelle image.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (isWide)
                Row(
                  children: [
                    _SideRail(
                      selectedIndex: _currentIndex,
                      onSelected: _select,
                      translucent: hasBackground,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              else
                body,
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: NavigationBar(
                    backgroundColor: hasBackground ? Colors.black.withValues(alpha: 0.85) : null,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _select,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _SideRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool translucent;

  const _SideRail({required this.selectedIndex, required this.onSelected, required this.translucent});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return NavigationRail(
      backgroundColor: translucent ? Colors.black.withValues(alpha: 0.6) : null,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.9,
      leading: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xl),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.dashboard_customize_rounded, color: accent),
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}
