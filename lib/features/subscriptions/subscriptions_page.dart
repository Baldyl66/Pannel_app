import 'package:flutter/material.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import 'subscription.dart';
import 'subscriptions_controller.dart';
import 'widgets/subscription_form.dart';
import 'widgets/subscription_widgets.dart';

/// Ouvre le formulaire et enregistre le résultat.
Future<void> openSubscriptionForm(BuildContext context, [Subscription? existing]) async {
  final controller = context.app.subscriptions;
  final result = await showAppSheet<Subscription>(
    context,
    title: existing == null ? 'Nouvel abonnement' : 'Modifier',
    subtitle: existing == null ? 'Choisissez une suggestion ou saisissez le vôtre' : existing.name,
    builder: (_) => SubscriptionForm(initial: existing),
  );
  if (result != null) await controller.save(result);
}

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  Future<void> _delete(BuildContext context, Subscription sub) async {
    final controller = context.app.subscriptions;
    final index = await controller.remove(sub);
    if (!context.mounted || index < 0) return;
    showAppSnackBar(
      context,
      '« ${sub.name} » supprimé',
      actionLabel: 'Annuler',
      onAction: () => controller.restore(sub, index),
    );
  }

  Future<void> _showActions(BuildContext context, Subscription sub) async {
    final next = sub.nextPayment();
    final action = await showActionSheet<String>(
      context,
      title: sub.name,
      subtitle: '${formatEuro(sub.price)} / ${sub.cycle.unit}${next == null ? '' : ' · ${formatDaysUntil(next)}'}',
      leading: SubscriptionLogo(sub: sub, size: 40),
      actions: const [
        SheetAction(value: 'edit', label: 'Modifier', icon: Icons.edit_outlined),
        SheetAction(value: 'delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!context.mounted) return;
    if (action == 'edit') openSubscriptionForm(context, sub);
    if (action == 'delete') _delete(context, sub);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.app.subscriptions;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.count;
        return AppPage(
          title: 'Dépenses',
          overline: count == 0 ? 'Abonnements' : '$count abonnement${count > 1 ? 's' : ''}',
          inShell: true,
          actions: [
            if (count > 1)
              PopupMenuButton<SubscriptionSort>(
                tooltip: 'Trier',
                icon: const Icon(Icons.sort_rounded),
                initialValue: controller.sort,
                onSelected: (s) {
                  Haptics.selection();
                  controller.setSort(s);
                },
                itemBuilder: (_) => [
                  for (final s in SubscriptionSort.values)
                    CheckedPopupMenuItem(value: s, checked: controller.sort == s, child: Text(s.label)),
                ],
              ),
          ],
          floatingActionButton: count == 0
              ? null
              : FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () => openSubscriptionForm(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter'),
                ),
          slivers: _buildSlivers(context, controller),
        );
      },
    );
  }

  List<Widget> _buildSlivers(BuildContext context, SubscriptionsController controller) {
    if (!controller.isLoaded) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(child: SkeletonBox(height: 220)),
        ),
      ];
    }
    if (controller.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Suivez vos abonnements',
            message: 'Ajoutez Netflix, Spotify, votre forfait… et voyez combien ils vous coûtent par mois et par an, avec un rappel avant chaque prélèvement.',
            actionLabel: 'Ajouter un abonnement',
            onAction: () => openSubscriptionForm(context),
          ),
        ),
      ];
    }

    final upcoming = controller.upcoming();
    final visible = controller.visible;
    final filter = controller.filter;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        sliver: SliverToBoxAdapter(
          child: SpendingSummaryCard(
            monthly: controller.monthlyTotal,
            yearly: controller.yearlyTotal,
            count: controller.count,
            byCategory: controller.monthlyByCategory,
            selected: filter,
            onSelect: controller.setFilter,
          ),
        ),
      ),
      if (upcoming.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle('À venir · 30 jours', padding: EdgeInsets.fromLTRB(AppSpacing.lg + 4, 0, AppSpacing.lg, AppSpacing.sm)),
        ),
        SliverToBoxAdapter(
          child: UpcomingPaymentsStrip(items: upcoming, onTap: (s) => openSubscriptionForm(context, s)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
      SliverToBoxAdapter(
        child: SectionTitle(
          filter == null ? 'Tous les abonnements' : filter.label,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg + 4, 0, AppSpacing.lg, AppSpacing.sm),
          trailing: filter == null
              ? Text('Glisser pour supprimer', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary))
              : InkWell(
                  onTap: () => controller.setFilter(null),
                  child: Text(
                    'Tout afficher',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            final sub = visible[i];
            return Dismissible(
              key: ValueKey(sub.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
              onDismissed: (_) {
                Haptics.medium();
                _delete(context, sub);
              },
              child: SubscriptionTile(
                sub: sub,
                onTap: () => openSubscriptionForm(context, sub),
                onLongPress: () => _showActions(context, sub),
              ),
            );
          },
        ),
      ),
    ];
  }
}
