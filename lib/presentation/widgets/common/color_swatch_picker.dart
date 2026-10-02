import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_tokens.dart';

/// Rangée de pastilles de couleur sélectionnables.
class ColorSwatchPicker extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final double size;

  const ColorSwatchPicker({
    super.key,
    this.colors = AppColors.swatches,
    required this.selected,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final color in colors)
          _Swatch(
            color: color,
            size: size,
            isSelected: color.toARGB32() == selected.toARGB32(),
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(color);
            },
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final double size;
  final bool isSelected;
  final VoidCallback onTap;

  const _Swatch({required this.color, required this.size, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 12, spreadRadius: 1)]
                : null,
          ),
          child: AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: isSelected ? 1 : 0,
            child: Icon(Icons.check_rounded, size: size * 0.5, color: onColor),
          ),
        ),
      ),
    );
  }
}
