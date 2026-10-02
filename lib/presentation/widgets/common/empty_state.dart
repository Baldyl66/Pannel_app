import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'app_card.dart';

/// État vide illustré, avec un appel à l'action optionnel.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: Icon(icon), color: theme.colorScheme.primary, size: 72, circle: true),
            const SizedBox(height: AppSpacing.xl),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte affichée quand un service (Spotify, Discord, Agenda) n'est pas
/// encore connecté.
class ConnectServiceCard extends StatelessWidget {
  final Widget icon;
  final Color brandColor;
  final String service;
  final String description;
  final VoidCallback onConnect;
  final String? error;

  const ConnectServiceCard({
    super.key,
    required this.icon,
    required this.brandColor,
    required this.service,
    required this.description,
    required this.onConnect,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onConnect,
      child: Row(
        children: [
          IconBadge(icon: icon, color: brandColor, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  error ?? description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: error != null ? AppColors.danger : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              backgroundColor: brandColor.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
            ),
            child: Text(error != null ? 'Réessayer' : 'Connecter'),
          ),
        ],
      ),
    );
  }
}
