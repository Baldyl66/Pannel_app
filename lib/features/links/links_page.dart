import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/thumbnail.dart';
import 'links_controller.dart';
import 'widgets/link_form.dart';

class LinksPage extends StatefulWidget {
  const LinksPage({super.key});

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  bool _reordering = false;

  LinksController get _controller => context.app.links;

  Future<void> _open(LinkItem link) async {
    Haptics.light();
    final uri = Uri.tryParse(normalizeUrl(link.url));
    var opened = false;
    try {
      opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) showAppSnackBar(context, 'Impossible d\'ouvrir ce lien', isError: true);
  }

  Future<void> _openForm([LinkItem? existing]) async {
    final result = await showAppSheet<LinkItem>(
      context,
      title: existing == null ? 'Nouveau lien' : 'Modifier le lien',
      builder: (_) => LinkForm(initial: existing, groups: _controller.groups),
    );
    if (result != null) await _controller.save(result);
  }

  Future<void> _delete(LinkItem link) async {
    final index = await _controller.remove(link);
    if (!mounted || index < 0) return;
    showAppSnackBar(
      context,
      '« ${link.title} » supprimé',
      actionLabel: 'Annuler',
      onAction: () => _controller.restore(link, index),
    );
  }

  Future<void> _showActions(LinkItem link) async {
    final action = await showActionSheet<String>(
      context,
      title: link.title,
      subtitle: link.host,
      leading: Thumbnail(path: faviconUrl(link.url), fallbackText: link.title, size: 40, background: Colors.white),
      actions: const [
        SheetAction(value: 'open', label: 'Ouvrir', icon: Icons.open_in_new_rounded),
        SheetAction(value: 'copy', label: 'Copier le lien', icon: Icons.copy_rounded),
        SheetAction(value: 'edit', label: 'Modifier', icon: Icons.edit_outlined),
        SheetAction(value: 'delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        _open(link);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: link.url));
        if (mounted) showAppSnackBar(context, 'Lien copié');
      case 'edit':
        _openForm(link);
      case 'delete':
        _delete(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        if (_reordering && c.count < 2) _reordering = false;
        return AppPage(
          title: _reordering ? 'Réorganiser' : 'Liens',
          overline: c.isEmpty ? 'Accès rapide' : '${c.count} favori${c.count > 1 ? 's' : ''}',
          inShell: true,
          actions: [
            if (c.count > 1)
              _reordering
                  ? TextButton(
                      onPressed: () => setState(() => _reordering = false),
                      child: const Text('Terminé'),
                    )
                  : IconButton(
                      tooltip: 'Réorganiser',
                      icon: const Icon(Icons.swap_vert_rounded),
                      onPressed: () {
                        Haptics.selection();
                        FocusScope.of(context).unfocus();
                        c.setQuery('');
                        setState(() => _reordering = true);
                      },
                    ),
          ],
          floatingActionButton: c.isEmpty || _reordering
              ? null
              : FloatingActionButton(
                  heroTag: null,
                  tooltip: 'Ajouter un lien',
                  onPressed: () => _openForm(),
                  child: const Icon(Icons.add_rounded),
                ),
          slivers: _buildSlivers(c),
        );
      },
    );
  }

  List<Widget> _buildSlivers(LinksController c) {
    if (!c.isLoaded) return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    if (c.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.bookmarks_outlined,
            title: 'Vos sites favoris',
            message: 'Ajoutez les sites que vous ouvrez tous les jours pour y accéder en un geste. Classez-les par groupe.',
            actionLabel: 'Ajouter un lien',
            onAction: () => _openForm(),
          ),
        ),
      ];
    }

    if (_reordering) {
      final items = c.all;
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorderStart: (_) => Haptics.medium(),
            onReorderItem: c.reorder,
            itemBuilder: (context, i) {
              final link = items[i];
              return Padding(
                key: ValueKey(link.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Thumbnail(path: faviconUrl(link.url), fallbackText: link.title, size: 36, background: Colors.white),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(link.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(link.host, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ];
    }

    final visible = c.visible;
    final groups = c.groups;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
          child: AppSearchField(hint: 'Rechercher un lien', initialValue: c.query, onChanged: c.setQuery),
        ),
      ),
      if (groups.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FilterChipsRow(
              options: groups,
              selected: c.group,
              onSelected: (g) {
                Haptics.selection();
                g == null ? c.setGroup(c.group) : c.setGroup(g);
              },
            ),
          ),
        ),
      if (visible.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textTertiary),
                const SizedBox(height: AppSpacing.md),
                Text('Aucun résultat', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.1,
            ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _LinkCard(
              link: visible[i],
              onTap: () => _open(visible[i]),
              onMore: () => _showActions(visible[i]),
            ),
          ),
        ),
    ];
  }
}

class _LinkCard extends StatelessWidget {
  final LinkItem link;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _LinkCard({required this.link, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = link.hasImage;

    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          link.title,
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          link.group == null ? link.host : '${link.host} · ${link.group}',
          style: theme.textTheme.bodySmall?.copyWith(color: hasImage ? Colors.white70 : null),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return AppCard(
      onTap: onTap,
      onLongPress: onMore,
      padding: EdgeInsets.zero,
      image: hasImage
          ? DecorationImage(image: imageProviderFor(link.imageUrl!), fit: BoxFit.cover, onError: (_, _) {})
          : null,
      child: Container(
        decoration: hasImage
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.85)],
                ),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: Thumbnail(
                      path: faviconUrl(link.url),
                      fallbackText: link.title,
                      fallbackColor: theme.colorScheme.primary,
                      size: 44,
                      radius: AppRadius.sm,
                      fit: BoxFit.contain,
                      background: Colors.white,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Options',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert_rounded, color: hasImage ? Colors.white : AppColors.textTertiary, size: 20),
                  onPressed: onMore,
                ),
              ],
            ),
            const Spacer(),
            Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: labels),
          ],
        ),
      ),
    );
  }
}
