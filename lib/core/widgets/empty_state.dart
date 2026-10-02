import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// État vide illustré avec un appel à l'action.
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
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl * 1.5, AppSpacing.xxl, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [accent.withValues(alpha: 0.28), accent.withValues(alpha: 0.04)]),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: accent, size: 38),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
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
    );
  }
}

/// Carte proposée quand un service n'est pas encore connecté.
class ConnectServiceCard extends StatelessWidget {
  final Widget icon;
  final Color brandColor;
  final String service;
  final String description;
  final VoidCallback onConnect;
  final String? error;
  final String actionLabel;

  const ConnectServiceCard({
    super.key,
    required this.icon,
    required this.brandColor,
    required this.service,
    required this.description,
    required this.onConnect,
    this.error,
    this.actionLabel = 'Connecter',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onConnect,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandColor.withValues(alpha: 0.14), AppColors.surface],
      ),
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
                  style: theme.textTheme.bodySmall?.copyWith(color: error != null ? AppColors.danger : null),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              backgroundColor: brandColor,
              foregroundColor: ThemeData.estimateBrightnessForColor(brandColor) == Brightness.dark ? Colors.white : Colors.black,
            ),
            child: Text(error != null ? 'Réessayer' : actionLabel),
          ),
        ],
      ),
    );
  }
}
