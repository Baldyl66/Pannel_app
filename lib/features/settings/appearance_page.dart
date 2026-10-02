import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/color_picker.dart';

/// Couleur d'accent et fond d'écran, avec aperçu en direct.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  Future<void> _pickBackground(BuildContext context) async {
    const typeGroup = XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file != null && context.mounted) await context.app.settings.setBackgroundImage(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.app.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final accent = settings.accent;
        final bg = settings.backgroundImage;
        return AppPage(
          title: 'Apparence',
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                child: _Preview(accent: accent, backgroundImage: bg, dim: settings.backgroundDim),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Couleur d\'accent'),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ColorSwatchPicker(selected: accent, onChanged: settings.setAccent, size: 40),
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final color = await showColorPickerSheet(context, initial: accent);
                              if (color != null) settings.setAccent(color);
                            },
                            icon: const Icon(Icons.palette_outlined),
                            label: const Text('Choisir sur la roue des couleurs'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, 0),
                      child: Text(
                        'La couleur s\'applique aux boutons, onglets, graphiques et interrupteurs.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AppSection(
                title: 'Fond d\'écran',
                footer: bg == null ? 'Par défaut : noir profond, idéal pour les écrans OLED.' : null,
                children: [
                  AppTile(
                    icon: Icons.wallpaper_rounded,
                    title: bg == null ? 'Choisir une image' : 'Changer d\'image',
                    subtitle: bg == null ? 'Depuis vos photos' : bg.split(RegExp(r'[\\/]')).last,
                    chevron: true,
                    onTap: () => _pickBackground(context),
                  ),
                  if (bg != null) ...[
                    _SliderTile(
                      icon: Icons.brightness_6_rounded,
                      title: 'Assombrissement',
                      value: settings.backgroundDim,
                      max: 0.9,
                      label: '${(settings.backgroundDim * 100).round()} %',
                      onChanged: settings.setBackgroundDim,
                      onChangeEnd: (_) => settings.persistBackgroundEffects(),
                    ),
                    _SliderTile(
                      icon: Icons.blur_on_rounded,
                      title: 'Flou',
                      value: settings.backgroundBlur,
                      max: 30,
                      label: settings.backgroundBlur < 0.5 ? 'Aucun' : '${settings.backgroundBlur.round()}',
                      onChanged: settings.setBackgroundBlur,
                      onChangeEnd: (_) => settings.persistBackgroundEffects(),
                    ),
                    AppTile(
                      icon: Icons.hide_image_outlined,
                      title: 'Retirer l\'image',
                      destructive: true,
                      onTap: () => settings.setBackgroundImage(null),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.max,
    required this.label,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTile(icon: icon, title: title, value: label),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
          child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
        ),
      ],
    );
  }
}

/// Mini maquette de l'application pour visualiser les réglages.
class _Preview extends StatelessWidget {
  final Color accent;
  final String? backgroundImage;
  final double dim;

  const _Preview({required this.accent, required this.backgroundImage, required this.dim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onAccent = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark ? Colors.white : Colors.black;
    final hasImage = backgroundImage != null && File(backgroundImage!).existsSync();

    Widget bar(double width, {Color? color}) => Container(
          height: 8,
          width: width,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderStrong),
        image: hasImage
            ? DecorationImage(
                image: FileImage(File(backgroundImage!)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: dim), BlendMode.darken),
              )
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APERÇU', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('Bonjour', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: hasImage ? 0.8 : 1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.bolt_rounded, size: 16, color: accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(90), const SizedBox(height: 6), bar(140, color: accent.withValues(alpha: 0.7))],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('Action', style: theme.textTheme.labelMedium?.copyWith(color: onAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 44,
                  height: 22,
                  decoration: BoxDecoration(
                    color: i == 0 ? accent.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(
                    const [Icons.space_dashboard_rounded, Icons.account_balance_wallet_outlined, Icons.graphic_eq_rounded, Icons.bookmarks_outlined][i],
                    size: 14,
                    color: i == 0 ? accent : AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
