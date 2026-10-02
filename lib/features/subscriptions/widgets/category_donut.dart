import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../subscription.dart';

/// Anneau de répartition mensuelle par catégorie. Un appui sur un segment ou
/// une ligne de la légende met la catégorie en avant et affiche son montant.
class CategoryDonut extends StatelessWidget {
  final Map<SubscriptionCategory, double> values;
  final SubscriptionCategory? selected;
  final ValueChanged<SubscriptionCategory?> onSelect;
  final double size;

  const CategoryDonut({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelect,
    this.size = 132,
  });

  double get _total => values.values.fold(0.0, (a, b) => a + b);

  SubscriptionCategory? _hit(Offset local) {
    final center = Offset(size / 2, size / 2);
    final delta = local - center;
    final r = delta.distance;
    if (r < size / 2 - 30 || r > size / 2 + 4) return null;
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    var start = 0.0;
    for (final entry in values.entries) {
      final sweep = entry.value / _total * 2 * math.pi;
      if (angle >= start && angle < start + sweep) return entry.key;
      start += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = selected != null && values.containsKey(selected) ? selected : null;
    final centerValue = focus == null ? _total : values[focus]!;
    final share = focus == null ? null : (values[focus]! / _total * 100).round();

    return Semantics(
      label: 'Répartition par catégorie',
      child: GestureDetector(
        onTapUp: (d) {
          final hit = _hit(d.localPosition);
          Haptics.selection();
          onSelect(hit == focus ? null : hit);
        },
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppDurations.slow * 2,
                curve: AppCurves.standard,
                builder: (context, progress, _) => CustomPaint(
                  size: Size.square(size),
                  painter: _DonutPainter(values: values, focus: focus, progress: progress),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatEuroRound(centerValue),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    share == null ? '/ mois' : '$share %',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<SubscriptionCategory, double> values;
  final SubscriptionCategory? focus;
  final double progress;

  _DonutPainter({required this.values, required this.focus, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;
    const stroke = 16.0;
    final radius = size.width / 2 - stroke / 2 - 4;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    // Écart de 2 px entre les segments.
    final gap = values.length > 1 ? 2 / radius : 0.0;

    var start = -math.pi / 2;
    for (final entry in values.entries) {
      final sweep = entry.value / total * 2 * math.pi * progress;
      final isFocus = focus == entry.key;
      final dimmed = focus != null && !isFocus;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFocus ? stroke + 6 : stroke
        ..color = entry.key.color.withValues(alpha: dimmed ? 0.3 : 1);
      final drawSweep = math.max(0.0, sweep - gap);
      if (drawSweep > 0) canvas.drawArc(rect, start + gap / 2, drawSweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values || old.focus != focus || old.progress != progress;
}

/// Légende de l'anneau : nom, montant et part de chaque catégorie.
class CategoryLegend extends StatelessWidget {
  final Map<SubscriptionCategory, double> values;
  final SubscriptionCategory? selected;
  final ValueChanged<SubscriptionCategory?> onSelect;

  const CategoryLegend({super.key, required this.values, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = values.values.fold(0.0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in values.entries)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            onTap: () {
              Haptics.selection();
              onSelect(selected == entry.key ? null : entry.key);
            },
            child: AnimatedOpacity(
              duration: AppDurations.fast,
              opacity: selected == null || selected == entry.key ? 1 : 0.45,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: entry.key.color, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        entry.key.label,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(entry.value / total * 100).round()} %',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
