import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/thumbnail.dart';
import '../subscription.dart';
import 'category_donut.dart';

/// Logo d'un abonnement (image ou initiales sur la couleur de sa catégorie).
class SubscriptionLogo extends StatelessWidget {
  final Subscription sub;
  final double size;
  const SubscriptionLogo({super.key, required this.sub, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Thumbnail(
      path: sub.imagePath,
      fallbackText: sub.name,
      fallbackColor: sub.category.color,
      size: size,
      fit: BoxFit.contain,
      background: Colors.white.withValues(alpha: 0.04),
    );
  }
}

/// Carte de synthèse : totaux + répartition par catégorie.
class SpendingSummaryCard extends StatelessWidget {
  final double monthly;
  final double yearly;
  final int count;
  final Map<SubscriptionCategory, double> byCategory;
  final SubscriptionCategory? selected;
  final ValueChanged<SubscriptionCategory?> onSelect;

  const SpendingSummaryCard({
    super.key,
    required this.monthly,
    required this.yearly,
    required this.count,
    required this.byCategory,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent.withValues(alpha: 0.22), AppColors.surface, AppColors.surface],
        stops: const [0, 0.6, 1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dépenses mensuelles', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          TweenAnimationBuilder<double>(
            tween: Tween(end: monthly),
            duration: AppDurations.slow,
            curve: AppCurves.standard,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatEuro(value), style: theme.textTheme.displayMedium),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Pill(icon: Icons.calendar_month_rounded, label: '${formatEuroRound(yearly)} / an'),
              _Pill(icon: Icons.layers_rounded, label: '$count abonnement${count > 1 ? 's' : ''}'),
            ],
          ),
          if (byCategory.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CategoryDonut(values: byCategory, selected: selected, onSelect: onSelect),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: CategoryLegend(values: byCategory, selected: selected, onSelect: onSelect)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Bandeau horizontal des prochains prélèvements.
class UpcomingPaymentsStrip extends StatelessWidget {
  final List<(Subscription, DateTime)> items;
  final ValueChanged<Subscription> onTap;

  const UpcomingPaymentsStrip({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final (sub, date) = items[i];
          final days = dateOnly(date).difference(dateOnly(DateTime.now())).inDays;
          final soon = days <= 3;
          return SizedBox(
            width: 148,
            child: AppCard(
              onTap: () => onTap(sub),
              padding: const EdgeInsets.all(AppSpacing.md),
              borderColor: soon ? AppColors.warning.withValues(alpha: 0.4) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SubscriptionLogo(sub: sub, size: 32),
                      const Spacer(),
                      if (soon) const Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.warning),
                    ],
                  ),
                  const Spacer(),
                  Text(sub.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    formatEuro(sub.price),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDaysUntil(date),
                    style: theme.textTheme.labelMedium?.copyWith(color: soon ? AppColors.warning : AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ligne d'abonnement dans la liste.
class SubscriptionTile extends StatelessWidget {
  final Subscription sub;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SubscriptionTile({super.key, required this.sub, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = sub.nextPayment();
    final details = [
      sub.category.label,
      if (next != null) formatDaysUntil(next),
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SubscriptionLogo(sub: sub),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(details, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatEuro(sub.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('/ ${sub.cycle.unit}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
