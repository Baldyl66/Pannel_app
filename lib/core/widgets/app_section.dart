import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../utils/haptics.dart';
import 'app_card.dart';

/// Groupe de lignes dans une carte, avec titre et note de bas optionnels
/// (style réglages iOS / Android 14).
class AppSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const AppSection({
    super.key,
    this.title,
    this.footer,
    this.trailing,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionTitle(title!, trailing: trailing),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, 0),
              child: Text(footer!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
            ),
        ],
      ),
    );
  }
}

/// Titre discret au-dessus d'un bloc de contenu.
class SectionTitle extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const SectionTitle(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Ligne d'un [AppSection].
class AppTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  const AppTile({
    super.key,
    this.icon,
    this.leading,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? AppColors.danger : (iconColor ?? theme.colorScheme.primary);
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              Haptics.selection();
              onTap!();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (icon != null)
                IconBadge(icon: Icon(icon), color: color),
              if (leading != null || icon != null) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15.5,
                        color: destructive ? AppColors.danger : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(value!, style: theme.textTheme.bodyMedium),
              ],
              if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
              if (chevron) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne avec interrupteur.
class AppSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitchTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: (v) {
        Haptics.selection();
        onChanged(v);
      }),
    );
  }
}
