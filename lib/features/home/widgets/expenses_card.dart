import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../subscriptions/widgets/subscription_widgets.dart';

/// Résumé des dépenses sur l'accueil : total mensuel et 3 prochains
/// prélèvements. Un appui ouvre l'onglet Dépenses.
class ExpensesCard extends StatelessWidget {
  const ExpensesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app.subscriptions,
      builder: (context, _) {
        final controller = app.subscriptions;
        if (!controller.isLoaded || controller.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final upcoming = controller.upcoming(days: 45).take(3).toList();

        return AppCard(
          onTap: () => app.tab.value = 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('DÉPENSES', style: theme.textTheme.labelSmall),
                  const Spacer(),
                  Text(
                    '${formatEuro(controller.monthlyTotal)} / mois',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (upcoming.isEmpty)
                Text(
                  'Ajoutez la date de prélèvement de vos abonnements pour voir les prochains ici.',
                  style: theme.textTheme.bodySmall,
                )
              else
                for (final (sub, date) in upcoming)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SubscriptionLogo(sub: sub, size: 32),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(formatDaysUntil(date), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(
                          formatEuro(sub.price),
                          style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
