import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_tokens.dart';
import 'app_card.dart';

/// Affiche un message flottant cohérent dans toute l'application.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.danger : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}

/// Boîte de confirmation standard. Renvoie `true` si l'utilisateur confirme.
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
      icon: IconBadge(icon: Icon(icon), color: color, size: 56, circle: true),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () {
                  HapticFeedback.mediumImpact();
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

/// Feuille modale avec titre, gestion du clavier et défilement automatique.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? trailing,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                builder(context),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Une action dans une feuille d'actions (`showActionSheet`).
class SheetAction<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;

  const SheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });
}

/// Liste d'actions contextuelles (appui long sur un élément, menu « … »).
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<SheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 2, AppSpacing.md, 0),
                child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: AppSpacing.md),
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon, color: action.destructive ? AppColors.danger : null),
                title: Text(
                  action.label,
                  style: action.destructive ? const TextStyle(color: AppColors.danger) : null,
                ),
                onTap: () => Navigator.pop(context, action.value),
              ),
          ],
        ),
      ),
    ),
  );
}
