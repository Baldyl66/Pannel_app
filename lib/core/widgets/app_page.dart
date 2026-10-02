import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Indique aux pages qu'une image de fond est affichée derrière elles.
class BackdropScope extends InheritedWidget {
  final bool hasImage;
  const BackdropScope({super.key, required this.hasImage, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackdropScope>()?.hasImage ?? false;

  @override
  bool updateShouldNotify(BackdropScope oldWidget) => hasImage != oldWidget.hasImage;
}

/// Gabarit commun à toutes les pages : grand titre qui se replie en barre
/// compacte au défilement, actions à droite, retour automatique si la page a
/// été poussée, tirer-pour-rafraîchir optionnel.
class AppPage extends StatelessWidget {
  final String title;
  final String? overline;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;

  /// Vrai pour les onglets affichés au-dessus de la barre de navigation.
  final bool inShell;

  const AppPage({
    super.key,
    required this.title,
    this.overline,
    this.actions = const [],
    required this.slivers,
    this.floatingActionButton,
    this.onRefresh,
    this.inShell = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = BackdropScope.of(context);
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    Widget scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _CollapsingHeaderDelegate(
            title: title,
            overline: overline,
            actions: actions,
            showBack: canPop,
            topPadding: MediaQuery.paddingOf(context).top,
            translucent: hasImage,
          ),
        ),
        for (final sliver in slivers)
          SliverCrossAxisConstrained(maxWidth: AppSpacing.maxContentWidth, child: sliver),
        SliverToBoxAdapter(
          child: SizedBox(height: inShell ? AppSpacing.navBarClearance : AppSpacing.xxl + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );

    if (onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        child: scroll,
      );
    }

    return Scaffold(
      backgroundColor: hasImage || inShell ? Colors.transparent : null,
      body: scroll,
      floatingActionButton: floatingActionButton == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: inShell ? 84 : 0),
              child: floatingActionButton,
            ),
    );
  }
}

/// Centre un sliver et limite sa largeur sur les grands écrans.
class SliverCrossAxisConstrained extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const SliverCrossAxisConstrained({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final extra = math.max(0.0, constraints.crossAxisExtent - maxWidth) / 2;
        return SliverPadding(padding: EdgeInsets.symmetric(horizontal: extra), sliver: child);
      },
    );
  }
}

class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? overline;
  final List<Widget> actions;
  final bool showBack;
  final double topPadding;
  final bool translucent;

  _CollapsingHeaderDelegate({
    required this.title,
    required this.overline,
    required this.actions,
    required this.showBack,
    required this.topPadding,
    required this.translucent,
  });

  static const _toolbar = 56.0;
  static const _large = 64.0;

  @override
  double get minExtent => topPadding + _toolbar;

  @override
  double get maxExtent => topPadding + _toolbar + _large + (overline != null ? 18 : 0);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final range = maxExtent - minExtent;
    final t = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final compactOpacity = Curves.easeIn.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
    final largeOpacity = 1 - Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));

    final background = translucent ? Colors.black.withValues(alpha: 0.55 * t) : AppColors.background.withValues(alpha: t);

    Widget bar = Container(
      constraints: const BoxConstraints.expand(),
      color: background,
      padding: EdgeInsets.only(top: topPadding),
      child: Stack(
        children: [
          // Barre compacte (titre centré + actions)
          SizedBox(
            height: _toolbar,
            child: Row(
              children: [
                SizedBox(
                  width: showBack ? 56 : AppSpacing.page - 4,
                  child: showBack ? const BackButton() : null,
                ),
                Expanded(
                  child: Opacity(
                    opacity: compactOpacity,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: showBack ? 56 : AppSpacing.page - 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [...actions, const SizedBox(width: AppSpacing.xs)]),
                ),
              ],
            ),
          ),
          // Grand titre
          Positioned(
            left: AppSpacing.page,
            right: AppSpacing.page,
            bottom: AppSpacing.sm,
            child: IgnorePointer(
              child: Opacity(
                opacity: largeOpacity,
                child: Transform.translate(
                  offset: Offset(0, -12 * t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (overline != null)
                        Text(overline!.toUpperCase(), style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        title,
                        style: theme.textTheme.headlineLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(opacity: compactOpacity, child: const Divider()),
          ),
        ],
      ),
    );

    if (translucent && t > 0) {
      bar = ClipRect(
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20 * t, sigmaY: 20 * t), child: bar),
      );
    }
    return bar;
  }

  @override
  bool shouldRebuild(_CollapsingHeaderDelegate old) =>
      title != old.title ||
      overline != old.overline ||
      actions != old.actions ||
      showBack != old.showBack ||
      topPadding != old.topPadding ||
      translucent != old.translucent;
}
