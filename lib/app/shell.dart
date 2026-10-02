import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/haptics.dart';
import '../core/widgets/app_page.dart';
import '../features/home/home_page.dart';
import '../features/links/links_page.dart';
import '../features/soundboard/soundboard_page.dart';
import '../features/subscriptions/subscriptions_page.dart';
import 'app_scope.dart';

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}

const _destinations = [
  _Destination('Accueil', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Destination('Dépenses', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
  _Destination('Sons', Icons.graphic_eq_outlined, Icons.graphic_eq_rounded),
  _Destination('Liens', Icons.bookmarks_outlined, Icons.bookmarks_rounded),
];

/// Structure principale : fond, onglets et barre de navigation flottante.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _pages = <Widget>[HomePage(), SubscriptionsPage(), SoundboardPage(), LinksPage()];

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.tab, app.settings]),
      builder: (context, _) {
        final index = app.tab.value;
        final settings = app.settings;
        final bgPath = settings.backgroundImage;
        final hasBackground = bgPath != null && File(bgPath).existsSync();

        return PopScope(
          // Le bouton retour ramène d'abord à l'accueil avant de quitter.
          canPop: index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) app.tab.value = 0;
          },
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                if (hasBackground) ...[
                  Positioned.fill(
                    child: ImageFiltered(
                      enabled: settings.backgroundBlur > 0.5,
                      imageFilter: ImageFilter.blur(
                        sigmaX: settings.backgroundBlur,
                        sigmaY: settings.backgroundBlur,
                        tileMode: TileMode.clamp,
                      ),
                      child: Image.file(File(bgPath), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: settings.backgroundDim))),
                ],
                BackdropScope(
                  hasImage: hasBackground,
                  child: IndexedStack(index: index, children: _pages),
                ),
              ],
            ),
            bottomNavigationBar: _FloatingNavBar(
              selectedIndex: index,
              onSelected: (i) {
                if (i == index) return;
                Haptics.selection();
                app.tab.value = i;
              },
            ),
          ),
        );
      },
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FloatingNavBar({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, bottom + AppSpacing.md),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 68,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      Expanded(
                        child: _NavItem(
                          destination: _destinations[i],
                          selected: i == selectedIndex,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.destination, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: AppCurves.standard,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: AppDurations.medium,
                curve: AppCurves.emphasized,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: selected ? accent : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0,
                  fontSize: 11,
                  color: selected ? AppColors.textPrimary : AppColors.textTertiary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
