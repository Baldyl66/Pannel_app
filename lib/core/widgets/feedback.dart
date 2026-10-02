import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../utils/haptics.dart';
import 'app_card.dart';

/// Message flottant cohérent dans toute l'application.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (isError) Haptics.medium();
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: isError ? AppColors.danger : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel != null && onAction != null ? SnackBarAction(label: actionLabel, onPressed: onAction) : null,
    ),
  );
}

/// Boîte de confirmation. Renvoie `true` si l'utilisateur confirme.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final color = destructive ? AppColors.danger : Theme.of(context).colorScheme.primary;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: IconBadge(icon: Icon(icon), color: color, size: 52, circle: true),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white)
                    : null,
                onPressed: () {
                  Haptics.medium();
                  Navigator.pop(context, true);
                },
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Feuille modale avec titre, gestion du clavier et défilement.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  Widget? trailing,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl + (bottomInset > 0 ? 0 : MediaQuery.paddingOf(context).bottom),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.headlineSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              builder(context),
            ],
          ),
        ),
      );
    },
  );
}

/// Une action d'une feuille d'actions.
class SheetAction<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;

  const SheetAction({required this.value, required this.label, required this.icon, this.destructive = false});
}

/// Menu contextuel en bas d'écran (appui long, bouton « … »).
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? leading,
  required List<SheetAction<T>> actions,
}) {
  Haptics.medium();
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    if (leading != null) ...[leading, const SizedBox(width: AppSpacing.md)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (subtitle != null)
                            Text(subtitle, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: EdgeInsets.zero,
                color: AppColors.surfaceHighest.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const Divider(indent: 52),
                      InkWell(
                        onTap: () {
                          Haptics.selection();
                          Navigator.pop(context, actions[i].value);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 15),
                          child: Row(
                            children: [
                              Icon(
                                actions[i].icon,
                                size: 22,
                                color: actions[i].destructive ? AppColors.danger : AppColors.textPrimary,
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Text(
                                actions[i].label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: actions[i].destructive ? AppColors.danger : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
